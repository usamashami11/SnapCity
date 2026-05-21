import os
from pydantic import BaseModel, Field
from dotenv import load_dotenv

# Load local environment variables from .env
load_dotenv()

from google import genai
from google.genai import types
from utils.logger import get_agent_logger

logger = get_agent_logger("DispatchAgent")

# Google GenAI client (safely initialized at import-time)
client = None
try:
    client = genai.Client()
except Exception as e:
    logger.warning(f"Failed to initialize Google GenAI Client: {str(e)}. Agent will operate in fallback mode.")

class DispatchResult(BaseModel):
    case_id: str = Field(
        description="A unique case ID for municipal tracking in the format SC-XXX (e.g., 'SC-204')."
    )
    assigned_responder: str = Field(
        description="The assigned response unit. Assign 'NGO FixIt' for High severity issues, or 'City Maintenance Dept' for Medium/Low issues."
    )
    authority_name: str = Field(
        description="The formal name of the responsible authority (e.g., 'KMC', 'Sindh Solid Waste Management', 'K-Electric', 'Water & Sewerage Board')."
    )
    authority_email: str = Field(
        description="A mock or real email address for the authority (e.g., 'complaints@kmc.gov.pk')."
    )
    authority_whatsapp: str = Field(
        description="A mock or real WhatsApp number for the authority (e.g., '+923001234567')."
    )
    municipal_notice_drafted: str = Field(
        description="A concise, professional, high-quality municipal alert notice. (E.g., 'URGENT: High impact open_manhole detected at 24.9180, 67.0971. Expected rain exacerbating risk. Assigned to NGO FixIt.')."
    )
    estimated_resolution_time: str = Field(
        description="A simulated estimated resolution or normalization metric. E.g. '2 hours' or '24 hours'."
    )
    whatsapp_template: str = Field(
        description="A copy-pasteable, formatted WhatsApp message for quick team alert dispatch (utilizing bold markdown)."
    )
    email_template: str = Field(
        description="A professional, formal municipal escalation email template including subject line and placeholders."
    )
    civic_points_earned: int = Field(
        description="Number of civic reward points earned by the user. Assign 40 for High severity issues, 20 for Medium, and 10 for Low."
    )
    reward_message: str = Field(
        description="Encouraging reward message incorporating a calculated percentage boost from duplication checks. E.g., 'Your report strengthened this case by +12%!'"
    )
    internal_thought: str = Field(
        description="Detailed internal reasoning process for selecting responder, templates, and metrics."
    )

class DispatchAgent:
    """Action Simulator & Dispatch Agent using Gemini-2.5-Flash to draft municipal notice and alerts."""

    def process(
        self,
        payload: dict,
        ingestion_data: dict,
        context_data: dict,
        reasoning_data: dict,
        authority_data: dict | None = None,
    ) -> dict:
        report_id = payload.get("report_id", "unknown")
        gps = payload.get("gps", {})
        lat, lng = gps.get("lat"), gps.get("lng")
        
        classification = ingestion_data.get("classification", "Unknown")
        weather = context_data.get("weather_condition", context_data.get("weather", "Unknown"))
        traffic = context_data.get("traffic_impact", context_data.get("traffic", "Unknown"))
        area = context_data.get("area", "Unknown Area")
        similar_reports = context_data.get("similar_reports_nearby", 0)
        
        severity = reasoning_data.get("severity_level", reasoning_data.get("impact_level", "Medium"))
        justification = reasoning_data.get("justification", "Civic issue evaluated.")
        authority = authority_data or {}
        authority_name = authority.get("name", "Municipal Authority")
        authority_email = authority.get("email", "info@municipal.gov.pk")
        authority_whatsapp = authority.get("whatsapp", "+923000000000")
        authority_source = authority.get("source", "Geo-semantic routing")

        logger.info(f"[{report_id}] Dispatch Agent process started. Constructing dispatch notice for '{classification}'...")

        # Generative Dispatch Prompt
        raw_prompt = (
            f"--- CASE SUMMARY ---\n"
            f"Report ID: {report_id}\n"
            f"Civic Issue: '{classification}'\n"
            f"Location: Area='{area}', GPS=({lat}, {lng})\n"
            f"Weather Condition: '{weather}'\n"
            f"Traffic Impact: '{traffic}'\n"
            f"Similar Reports Triangulated: {similar_reports}\n"
            f"Severity Assessment: '{severity}'\n"
            f"Danger Justification: '{justification}'\n"
            f"Authority Routing: '{authority_name}' via email '{authority_email}' and WhatsApp '{authority_whatsapp}' ({authority_source}).\n\n"
            f"--- TASK ---\n"
            "You are the Action Simulator & Dispatch Agent for SnapCity.\n"
            "Generate a professional, structured dispatch packet containing:\n"
            "1. A case ID (format: SC-XXX where XXX is a random 3 digit number, e.g. SC-204).\n"
            "2. Assigned responder department ('NGO FixIt' for High severity, 'City Maintenance Dept' for Medium/Low severity).\n"
            "3. A concise and formal municipal notice drafted using coordinates and weather. E.g. 'URGENT: High impact open_manhole detected at 24.9180, 67.0971. Expected rain exacerbating risk. Assigned to NGO FixIt.'\n"
            "   CRITICAL: Use the actual GPS coordinates provided above in all notices and case files.\n"
            "4. Estimated resolution time (e.g., '2 hours' for High severity, '24 hours' for Medium, '48 hours' for Low).\n"
            "5. A beautiful, copy-pasteable WhatsApp message alert for the response team, referencing the selected authority contact above.\n"
            "6. A formal, detailed escalation email template for city engineers, including the authority's contact details in the subject line and body.\n"
            "7. User rewards: earn 40 points for High severity, 20 for Medium, 10 for Low. Formulate a nice encouragement message mentioning how their duplicate report strengthened this case (e.g. 'Your report strengthened this case by +12%!').\n"
            "Provide your detailed internal reasoning steps."
        )

        logger.info(f"[{report_id}] Preparing Google GenAI model 'gemini-2.5-flash' Dispatch Simulation payload...")
        logger.debug(f"[{report_id}] RAW PROMPT SENT TO GEMINI:\n{raw_prompt}")

        try:
            if not client:
                raise ValueError("Gemini client not initialized (missing API key).")
            
            # API Call with Dual Model Fallback (gemini-3.1-flash-lite -> gemini-2.5-flash)
            response = None
            try:
                logger.info(f"[{report_id}] Attempting call via primary model 'gemini-3.1-flash-lite'...")
                response = client.models.generate_content(
                    model='gemini-3.1-flash-lite',
                    contents=raw_prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_schema=DispatchResult,
                        temperature=0.2
                    )
                )
                logger.info(f"[{report_id}] Dispatch Simulation completed via primary 'gemini-3.1-flash-lite'.")
            except Exception as model_err:
                logger.warning(f"[{report_id}] Primary model 'gemini-3.1-flash-lite' failed: {str(model_err)}. Falling back to 'gemini-2.5-flash'...")
                response = client.models.generate_content(
                    model='gemini-2.5-flash',
                    contents=raw_prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_schema=DispatchResult,
                        temperature=0.2
                    )
                )
                logger.info(f"[{report_id}] Dispatch Simulation completed via secondary fallback 'gemini-2.5-flash'.")

            result: DispatchResult = response.parsed

            logger.info(f"[{report_id}] Dispatch Simulation complete via LLM.")
            logger.info(f"[{report_id}] Model Thought Process:\n{result.internal_thought}")
            logger.info(f"[{report_id}] Assigned Responder: '{result.assigned_responder}'")
            logger.info(f"[{report_id}] Case ID: '{result.case_id}'")
            logger.info(f"[{report_id}] Est Resolution: '{result.estimated_resolution_time}'")

            # Formulate reduction string for legacy compatibility
            reduction = "48 hours to 2 hours" if severity == "High" else "72 hours to 24 hours"
            normalization = "18:00" if severity == "High" else "the following day"

            return {
                # Legacy keys for main.py backwards compatibility
                "assigned_responder": result.assigned_responder,
                "municipal_notification": result.municipal_notice_drafted,
                "simulation_outcome": f"Duration reduced: {reduction}. Flow normalizes: {normalization}.",
                "status": "Dispatched",

                # New sample-matching keys
                "case_id": result.case_id,
                "municipal_notice_drafted": result.municipal_notice_drafted,
                "estimated_resolution_time": result.estimated_resolution_time,
                "notice_draft": result.municipal_notice_drafted, # Added for Task 5
                "authority": {
                    "name": result.authority_name,
                    "email": result.authority_email,
                    "whatsapp": result.authority_whatsapp
                },
                "user_reward": {
                    "civic_points_earned": result.civic_points_earned,
                    "message": result.reward_message
                },

                # Communication templates
                "whatsapp_template": result.whatsapp_template,
                "email_template": result.email_template,
                "internal_thought": result.internal_thought
            }

        except Exception as e:
            logger.error(f"[{report_id}] LLM Dispatch Simulation failed: {str(e)}. Falling back to deterministic simulation.")

            # Fallback formulation
            fallback_case = "SC-204"
            fallback_responder = "NGO FixIt" if severity == "High" else "City Maintenance Dept"
            fallback_duration = "2 hours" if severity == "High" else "24 hours"
            fallback_points = 40 if severity == "High" else 20
            
            # Use discovered authority data if available, otherwise fallback map
            authority_map = {
                "Accumulated Garbage": {"name": "Sindh Solid Waste Management", "email": "waste@sswmb.gov.pk", "whatsapp": "+923001112223"},
                "Open Manhole": {"name": "Water & Sewerage Board", "email": "sewerage@kwsb.gov.pk", "whatsapp": "+923004445556"},
                "Pothole": {"name": "KMC Roads Dept", "email": "roads@kmc.gov.pk", "whatsapp": "+923007778889"},
                "Sewage Overflow": {"name": "Water & Sewerage Board", "email": "sewerage@kwsb.gov.pk", "whatsapp": "+923004445556"},
                "Broken Streetlight": {"name": "K-Electric", "email": "lights@ke.com.pk", "whatsapp": "+923009990001"}
            }
            auth = authority or authority_map.get(classification, {"name": "Municipal Dept", "email": "info@municipal.gov.pk", "whatsapp": "+923000000000"})

            fallback_notice = f"URGENT: {severity} impact {classification} detected at {lat}, {lng}. Weather: {weather}. Assigned to {fallback_responder}."
            
            reduction = "48 hours to 2 hours" if severity == "High" else "72 hours to 24 hours"
            normalization = "18:00" if severity == "High" else "the following day"
            
            fallback_whatsapp = (
                f"*SnapCity Alert!*\n*Case:* {fallback_case}\n*Issue:* {classification}\n*Severity:* {severity}\n*Responder:* {fallback_responder}"
                f"\n*Authority:* {auth['name']}\n*Contact:* {auth['whatsapp']}"
            )
            fallback_email = (
                f"Subject: Urgent Escalation {fallback_case}\n\n"
                f"Dear {auth['name']} Team,\n\n"
                f"A {severity} civic incident has been reported at {lat}, {lng}. Weather: {weather}. This report is routed through SnapCity and should be handled by your team immediately.\n\n"
                f"Contact: {auth['email']} / {auth['whatsapp']}\n\n"
                f"Regards,\nSnapCity Civic Intelligence"
            )

            fallback_thought = "LLM pipeline call failed. Deterministic Dispatch Simulation is running as high-reliability fallback."

            logger.info(f"[{report_id}] FALLBACK Responder: '{fallback_responder}', Case: '{fallback_case}'")

            return {
                # Legacy keys
                "assigned_responder": fallback_responder,
                "municipal_notification": fallback_notice,
                "simulation_outcome": f"Duration reduced: {reduction}. Flow normalizes: {normalization}.",
                "status": "Dispatched",

                # New keys
                "case_id": fallback_case,
                "municipal_notice_drafted": fallback_notice,
                "estimated_resolution_time": fallback_duration,
                "authority": auth,
                "user_reward": {
                    "civic_points_earned": fallback_points,
                    "message": f"Your report strengthened this case by +12%!"
                },

                # templates
                "whatsapp_template": fallback_whatsapp,
                "email_template": fallback_email,
                "internal_thought": fallback_thought
            }
