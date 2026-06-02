import os
from pydantic import BaseModel, Field
from typing import Literal
from dotenv import load_dotenv

# Load local environment variables from .env
load_dotenv()

from google import genai
from google.genai import types
from utils.logger import get_agent_logger

logger = get_agent_logger("Reasoning Agent")

# Google GenAI client (safely initialized at import-time)
client = None
try:
    client = genai.Client()
except Exception as e:
    logger.warning(f"Failed to initialize Google GenAI Client: {str(e)}. Agent will operate in fallback mode.")

class ReasoningResult(BaseModel):
    severity_level: Literal["High", "Medium", "Low"] = Field(
        description="The calculated danger severity level, assessing physical risk to citizens and infrastructure."
    )
    escalation_reason: str = Field(
        description="A concise reason detailing why this threat level was assigned, focusing on cumulative risk combinations (e.g. 'Near school route + public health/road hazard. Weather condition increases risk.')."
    )
    confidence_score: int = Field(
        description="The adjusted confidence score (0-100) reflecting the classification certainty and contextual weight."
    )
    justification: str = Field(
        description="A detailed expanded justification paragraph synthesizing the ingestion classification, context signals, and risk fusion."
    )
    internal_thought: str = Field(
        description="Step-by-step risk assessment reasoning pattern and logical danger matrix traversal."
    )

class ReasoningAgent:
    """Reasoning & Severity Agent using Gemini-2.5-Flash to dynamically assess threats."""

    def process(self, ingestion_data: dict, context_data: dict) -> dict:
        classification = ingestion_data.get("classification", "Unknown")
        base_confidence = ingestion_data.get("confidence", 80)
        visual_evidence = ingestion_data.get("visual_evidence", "")
        
        weather = context_data.get("weather_condition", context_data.get("weather", "Unknown"))
        traffic = context_data.get("traffic_impact", context_data.get("traffic", "Unknown"))
        area = context_data.get("area", "Unknown Area")
        similar_reports = context_data.get("similar_reports_nearby", 0)
        semantic_tags = context_data.get("semantic_tags", [])
        chronic_issue = "Chronic Failure Zone" in semantic_tags

        logger.info(f"Reasoning Agent process started. Assessing risk for '{classification}' in '{area}'...")

        # Formulate rich reasoning prompt
        raw_prompt = (
            f"--- INPUTS ---\n"
            f"Civic Issue: '{classification}'\n"
            f"Visual Evidence: '{visual_evidence}'\n"
            f"Baseline Confidence: {base_confidence}%\n"
            f"Location Area: '{area}'\n"
            f"Weather: '{weather}'\n"
            f"Traffic: '{traffic}'\n"
            f"Triangulated Duplicates: {similar_reports} similar reports nearby\n"
            f"Vulnerability Tags: {semantic_tags}\n\n"
            f"--- TASK ---\n"
            "You are the Reasoning & Severity Agent for SnapCity.\n"
            "Analyze these variables to reason dynamically through complex situational danger scenarios.\n"
            "Apply safety heuristics. For example:\n"
            "- If issue is 'Sewage Overflow' or 'Open Manhole' and Weather is 'Rainy' or 'Thunderstorm', force Severity: High/Critical immediately due to drowning and biohazard risk.\n"
            "- If issue is 'Pothole' or 'Road Damage' and Traffic is 'Severe Congestion' (Slowdown > 30%), force Severity: High due to extreme collision and gridlock risks.\n"
            "- Issues flagged with 'Chronic Failure Zone' represent repeated infrastructure neglect, which warrants elevated urgency.\n\n"
            "CRITICAL: Be highly analytical. Do not hallucinate severity. Assess strictly based on the provided inputs.\n"
            "Assign a final reasoned severity level (High, Medium, Low), adjust the confidence score (0-100) reflecting classification certainty and contextual weight, "
            "provide a clear escalation reason, write a formal justification paragraph, and elaborate on your step-by-step internal thoughts."
        )

        logger.info("Preparing danger analysis payload for primary model 'gemini-3.1-flash-lite' (fallback: 'gemini-2.5-flash')...")
        logger.debug(f"RAW PROMPT SENT TO GEMINI:\n{raw_prompt}")

        try:
            if not client:
                raise ValueError("Gemini client not initialized (missing API key).")
            
            # API Call with Dual Model Fallback (gemini-3.1-flash-lite -> gemini-2.5-flash)
            response = None
            try:
                logger.info("Attempting call via primary model 'gemini-3.1-flash-lite'...")
                response = client.models.generate_content(
                    model='gemini-3.1-flash-lite',
                    contents=raw_prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_schema=ReasoningResult,
                        temperature=0.1
                    )
                )
                logger.info("Reasoning analysis completed via primary 'gemini-3.1-flash-lite'.")
            except Exception as model_err:
                logger.warning(f"Primary model 'gemini-3.1-flash-lite' failed: {str(model_err)}. Falling back to 'gemini-2.5-flash'...")
                response = client.models.generate_content(
                    model='gemini-2.5-flash',
                    contents=raw_prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_schema=ReasoningResult,
                        temperature=0.1
                    )
                )
                logger.info("Reasoning analysis completed via secondary fallback 'gemini-2.5-flash'.")

            result: ReasoningResult = response.parsed

            logger.info("Reasoning analysis complete via LLM.")
            logger.info(f"Model Thought Process:\n{result.internal_thought}")
            logger.info(f"Severity: '{result.severity_level}' (Adjusted Confidence: {result.confidence_score}%)")
            logger.info(f"Escalation Reason: '{result.escalation_reason}'")

            # Return a compatible dictionary combining old keys (for main.py) and new keys (matching sample output)
            return {
                # Old/existing keys
                "confidence_score": result.confidence_score,
                "impact_level": result.severity_level, # Map severity to impact_level for backwards compatibility
                
                # New sample-matching keys
                "severity_level": result.severity_level,
                "escalation_reason": result.escalation_reason,
                
                # Enhanced keys
                "justification": result.justification,
                "internal_thought": result.internal_thought
            }

        except Exception as e:
            logger.error(f"LLM Dynamic Danger Reasoning failed: {str(e)}. Falling back to deterministic matrices.")

            # Fallback logic
            fallback_severity = "Low"
            fallback_reason = "Standard baseline risk assessment applied."
            
            # Simple fallback rules
            if classification in ["Pothole", "Open Manhole"] and ("heavy" in traffic.lower() or "slowdown" in traffic.lower()):
                fallback_severity = "High"
                fallback_reason = "Escalated: Critical road hazard in congested heavy-traffic zone."
            elif classification == "Open Manhole" or (classification == "Sewage Overflow" and "rain" in weather.lower()):
                fallback_severity = "High"
                fallback_reason = "Escalated: Sewage leak or open pit coupled with severe weather increases flood/biohazard risk."
            elif similar_reports >= 3:
                fallback_severity = "High"
                fallback_reason = "Escalated: Multiple similar reports nearby indicate a shared infrastructure failure cluster."
            elif classification in ["Sewage Overflow", "Pothole"] or chronic_issue:
                fallback_severity = "Medium"
                fallback_reason = "Standard priority warning: Repeated local infrastructure failure."

            fallback_justification = f"Reasoning fallback activated. Categorization: '{classification}' located at a traffic level: '{traffic}' and weather state: '{weather}' evaluated at severity: {fallback_severity}."
            fallback_thought = "LLM pipeline call failed. Deterministic threat matrix routing was activated as high-reliability fallback."

            logger.info(f"FALLBACK Severity: '{fallback_severity}', Reason: '{fallback_reason}'")

            return {
                # Old/existing keys
                "confidence_score": min(base_confidence + 2, 99),
                "impact_level": fallback_severity,

                # New keys
                "severity_level": fallback_severity,
                "escalation_reason": fallback_reason,

                # Enhanced keys
                "justification": fallback_justification,
                "internal_thought": fallback_thought
            }
