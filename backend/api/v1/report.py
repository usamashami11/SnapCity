from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import os
import json
from utils.logger import JSON_FILE_PATH

from google import genai
from google.genai import types

from agents.ingestion import IngestionAgent
from agents.context import ContextAgent
from agents.reasoning import ReasoningAgent
from agents.dispatch import DispatchAgent
from services.authority_finder import AuthorityFinderService
from utils.logger import get_agent_logger
from services.database import save_case, get_all_cases
from services.database import supabase

router = APIRouter()
logger = get_agent_logger("Supervisor Agent")

def get_logs_for_report(report_id: str) -> list:
    logs = []
    if not os.path.exists(JSON_FILE_PATH):
        return logs
    try:
        with open(JSON_FILE_PATH, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    agent = data.get("agent")
                    # Map old names to new names if any exist in the trace log
                    if agent in ["CIRO_Orchestrator", "CIRO_Report_API", "SupervisorAgent"]:
                        agent = "Supervisor Agent"
                        data["agent"] = agent
                        data["emoji"] = "🧠"
                    elif agent in ["IngestionAgent", "Ingestion_Agent"]:
                        agent = "Ingestion Agent"
                        data["agent"] = agent
                        data["emoji"] = "👁️"
                    elif agent in ["ContextAgent", "Context_Agent", "AuthorityFinderAgent", "AuthorityFinderService"]:
                        agent = "Context Agent"
                        data["agent"] = agent
                        data["emoji"] = "📚"
                    elif agent in ["ReasoningAgent", "Reasoning_Agent"]:
                        agent = "Reasoning Agent"
                        data["agent"] = agent
                        data["emoji"] = "⚙️"
                    elif agent in ["DispatchAgent", "Dispatch_Agent"]:
                        agent = "Dispatch Agent"
                        data["agent"] = agent
                        data["emoji"] = "🚀"

                    if agent in ["Supervisor Agent", "Ingestion Agent", "Context Agent", "Reasoning Agent", "Dispatch Agent"]:
                        msg = data.get("message", "")
                        if report_id in msg or "unknown" in msg.lower() or not msg.startswith("["):
                            logs.append(data)
                except Exception:
                    continue
    except Exception as e:
        print(f"Error fetching logs for report: {e}")
    return logs

# Define Data Models
class GPSCoords(BaseModel):
    lat: float
    lng: float


class ReportPayload(BaseModel):
    report_id: str
    timestamp: Optional[str] = None
    image_url: str
    gps: GPSCoords
    voice_note_transcript: Optional[str] = ""
    location_name: Optional[str] = None


# Initialize Swarm Agents & Services
ingestion_agent = IngestionAgent()
context_agent = ContextAgent()
reasoning_agent = ReasoningAgent()
dispatch_agent = DispatchAgent()
authority_service = AuthorityFinderService()

# Global variable to track active report ID across tools
current_report_id = "unknown"


# Define Tools for Gemini Supervisor
def validate_evidence(image_url: str, voice_note_transcript: str, lat: float, lng: float) -> dict:
    """Validates if the image and transcript describe a genuine civic infrastructure issue."""
    logger.info("🧠 [Supervisor Agent] Calling Tool: validate_evidence")
    ingestion_logger = get_agent_logger("Ingestion Agent")
    ingestion_logger.info("Supervisor requested evidence analysis. Ingesting payload details...")
    
    result = ingestion_agent.process({
        "report_id": current_report_id,
        "image_url": image_url,
        "voice_note_transcript": voice_note_transcript,
        "gps": {"lat": lat, "lng": lng}
    })
    return result


def fuse_context(classification: str, lat: float, lng: float) -> dict:
    """Fuses coordinates with environmental telemetry (weather, traffic) and queries duplicate clusters."""
    logger.info("🧠 [Supervisor Agent] Calling Tool: fuse_context")
    context_logger = get_agent_logger("Context Agent")
    context_logger.info("Supervisor requested signal fusion. Initiating telemetry APIs...")
    
    result = context_agent.process(
        {"report_id": current_report_id, "gps": {"lat": lat, "lng": lng}},
        {"classification": classification}
    )
    return result


def find_authority_routing(classification: str, area: str, lat: float, lng: float) -> dict:
    """Routes the reported issue to the matching Pakistan civic department based on coordinates and classification."""
    logger.info("🧠 [Supervisor Agent] Calling Tool: find_authority_routing")
    context_logger = get_agent_logger("Context Agent")
    context_logger.info("Supervisor requested routing path. Checking geo-boundary dictionary...")
    
    result = authority_service.process(
        {"report_id": current_report_id, "gps": {"lat": lat, "lng": lng}},
        {"classification": classification},
        {"area": area}
    )
    return result


def evaluate_threat_severity(classification: str, weather_condition: str, traffic_impact: str, area: str, similar_reports: int) -> dict:
    """Evaluates danger levels and dynamic severity using safety heuristics."""
    logger.info("🧠 [Supervisor Agent] Calling Tool: evaluate_threat_severity")
    reasoning_logger = get_agent_logger("Reasoning Agent")
    reasoning_logger.info("Supervisor requested danger analysis. Traversing risk matrix check...")
    
    result = reasoning_agent.process(
        {"classification": classification},
        {
            "weather_condition": weather_condition,
            "traffic_impact": traffic_impact,
            "area": area,
            "similar_reports_nearby": similar_reports
        }
    )
    return result


def simulate_dispatch(classification: str, area: str, lat: float, lng: float, severity: str, justification: str, authority: dict) -> dict:
    """Generates municipal notice text, templates, ETA and civic rewards."""
    logger.info("🧠 [Supervisor Agent] Calling Tool: simulate_dispatch")
    dispatch_logger = get_agent_logger("Dispatch Agent")
    dispatch_logger.info("Supervisor requested dispatch action. Compiling copy templates...")
    
    result = dispatch_agent.process(
        {"report_id": current_report_id, "gps": {"lat": lat, "lng": lng}},
        {"classification": classification},
        {"area": area},
        {"severity_level": severity, "justification": justification},
        authority
    )
    return result


class SupervisorAgent:
    """Supervisor Agent coordinating the swarm via Gemini function calling."""

    def process(self, payload: dict) -> dict:
        global current_report_id
        current_report_id = payload.get("report_id", "unknown")
        
        lat = payload["gps"]["lat"]
        lng = payload["gps"]["lng"]
        image_url = payload["image_url"]
        transcript = payload.get("voice_note_transcript", "")
        
        logger.info(f"🤖 [Supervisor] Starting dynamic orchestration loop for report: {current_report_id}")
        
        prompt = (
            f"You are the SnapCity Swarm Supervisor. Process the new civic report (Report ID: {current_report_id}) at Lat={lat}, Lng={lng}.\n"
            f"Image URL: {image_url}\n"
            f"Voice Note Transcript: '{transcript}'\n\n"
            "Execution Instructions:\n"
            "1. Call `validate_evidence` using the image, transcript, and coordinates.\n"
            "2. Read the tool response. If `is_valid_civic_issue` is False, STOP immediately and reply that the report is rejected. DO NOT call any other tools.\n"
            "3. If valid, call `fuse_context` to gather weather, traffic, and duplicate clusters.\n"
            "4. Call `find_authority_routing` using the classification and area from context.\n"
            "5. Call `evaluate_threat_severity` using the classification and environmental telemetry.\n"
            "6. Call `simulate_dispatch` to generate tracking IDs, notices, templates, and civic rewards.\n"
            "7. Output a summary confirming all steps are successfully complete."
        )

        tools = [validate_evidence, fuse_context, find_authority_routing, evaluate_threat_severity, simulate_dispatch]
        
        client = None
        try:
            client = genai.Client()
        except Exception as e:
            logger.warning(f"Failed to initialize Gemini Client for Supervisor: {e}. Activating deterministic global fallback.")
            return self._fallback_orchestration(payload)
            
        messages = [types.Content(role="user", parts=[types.Part.from_text(text=prompt)])]
        
        results = {
            "ingestion": None,
            "context": None,
            "authority": None,
            "reasoning": None,
            "dispatch": None
        }
        
        try:
            # Run the agentic tool loop
            for _ in range(10):  # Hard limit to prevent loops
                response = None
                try:
                    response = client.models.generate_content(
                        model='gemini-3.1-flash-lite',
                        contents=messages,
                        config=types.GenerateContentConfig(
                            tools=tools,
                            temperature=0.1,
                            system_instruction="You are the SnapCity Supervisor Agent. You must call tools in sequence to process civic reports."
                        )
                    )
                except Exception as model_err:
                    logger.warning(f"Supervisor call failed on primary model: {model_err}. Falling back to 'gemini-2.5-flash'...")
                    response = client.models.generate_content(
                        model='gemini-2.5-flash',
                        contents=messages,
                        config=types.GenerateContentConfig(
                            tools=tools,
                            temperature=0.1,
                            system_instruction="You are the SnapCity Supervisor Agent. You must call tools in sequence to process civic reports."
                        )
                    )
                
                # Check for function calls
                if response.function_calls:
                    # Append the model's turn
                    messages.append(response.candidates[0].content)
                    
                    tool_response_parts = []
                    for function_call in response.function_calls:
                        name = function_call.name
                        args = function_call.args
                        
                        logger.info(f"🤖 [Supervisor] Executing tool call: {name}")
                        
                        if name == "validate_evidence":
                            res = validate_evidence(**args)
                            results["ingestion"] = res
                            if not res.get("is_valid_civic_issue", True):
                                return {"is_valid": False, "ingestion": res}
                        elif name == "fuse_context":
                            res = fuse_context(**args)
                            results["context"] = res
                        elif name == "find_authority_routing":
                            res = find_authority_routing(**args)
                            results["authority"] = res
                        elif name == "evaluate_threat_severity":
                            res = evaluate_threat_severity(**args)
                            results["reasoning"] = res
                        elif name == "simulate_dispatch":
                            res = simulate_dispatch(**args)
                            results["dispatch"] = res
                        else:
                            res = {"error": f"Unknown tool: {name}"}
                            
                        tool_response_parts.append(
                            types.Part.from_function_response(
                                name=name,
                                response={"result": res}
                            )
                        )
                    messages.append(types.Content(role="tool", parts=tool_response_parts))
                else:
                    logger.info("🤖 [Supervisor] Tool loop completed. Finalizing report packaging.")
                    break
            
            if results["ingestion"] and results["context"] and results["authority"] and results["reasoning"] and results["dispatch"]:
                return {"is_valid": True, **results}
            else:
                raise ValueError("Swarm loop finished but some tool results are missing.")
                
        except Exception as err:
            logger.error(f"Supervisor loop execution failed: {err}. Triggering global fallback.")
            return self._fallback_orchestration(payload)

    def _fallback_orchestration(self, payload: dict) -> dict:
        logger.info("🤖 [Supervisor] Running linear fallback orchestration pipeline...")
        try:
            # 1. Ingestion
            ingestion_result = ingestion_agent.process(payload)
            if not ingestion_result.get("is_valid_civic_issue", True):
                return {"is_valid": False, "ingestion": ingestion_result}
                
            # 2. Context
            context_result = context_agent.process(payload, ingestion_result)
            
            # 3. Authority
            authority_result = authority_service.process(payload, ingestion_result, context_result)
            
            # 4. Reasoning
            reasoning_result = reasoning_agent.process(ingestion_result, context_result)
            
            # 5. Dispatch
            dispatch_result = dispatch_agent.process(payload, ingestion_result, context_result, reasoning_result, authority_result)
            
            return {
                "is_valid": True,
                "ingestion": ingestion_result,
                "context": context_result,
                "authority": authority_result,
                "reasoning": reasoning_result,
                "dispatch": dispatch_result
            }
        except Exception as e:
            logger.error(f"Critical fallback orchestration failure: {e}")
            raise e


supervisor_agent = SupervisorAgent()


@router.get("/cases")
async def get_cases():
    try:
        cases = get_all_cases()
        return {"status": "success", "cases": cases}
    except Exception as e:
        logger.error(f"Error fetching cases: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/report")
async def process_report(payload: ReportPayload):
    logger.info("="*50)
    logger.info(f"NEW INCIDENT RECEIVED: {payload.report_id}")
    logger.info("="*50)
    
    payload_dict = payload.model_dump() if hasattr(payload, "model_dump") else payload.dict()
    
    try:
        # Execute orchestrator
        swarm_result = supervisor_agent.process(payload_dict)
        
        # Check validation rejection
        if not swarm_result.get("is_valid", True):
            ingestion_result = swarm_result["ingestion"]
            raw_response = ingestion_result.get("raw_model_response", "Raw response not available.")
            logger.warning(f"REJECTED - Ingestion validation failed. Response: {raw_response}")
            logger.info("="*50)
            
            # Streaming final explicit termination state to NDJSON track file for God Mode integrity
            try:
                with open(JSON_FILE_PATH, "a", encoding="utf-8") as f:
                    f.write(json.dumps({
                        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                        "emoji": "❌",
                        "agent": "Supervisor Agent",
                        "level": "WARNING",
                        "status": "REJECTED_NON_CIVIC",
                        "message": "The uploaded content does not contain an active civic infrastructure hazard."
                    }, ensure_ascii=False) + "\n")
            except Exception as write_err:
                logger.error(f"Failed to write REJECTED_NON_CIVIC trace frame: {write_err}")
                
            return JSONResponse(
                status_code=400,
                content={
                    "error": "invalid_civic_image",
                    "message": "The uploaded content does not contain an active civic infrastructure hazard."
                }
            )
            
        # Extract individual agent results
        ingestion_result = swarm_result["ingestion"]
        context_result = swarm_result["context"]
        authority_result = swarm_result["authority"]
        reasoning_result = swarm_result["reasoning"]
        dispatch_result = swarm_result["dispatch"]
        
        logger.info(f"Incident {payload.report_id} Orchestration Successful.")
        logger.info("="*50)

        # Assemble output payload preserving 100% contract compatibility
        response_data = {
            "report_id": payload.report_id,
            "timestamp": payload.timestamp or datetime.utcnow().isoformat(),
            "image_url": payload.image_url,
            "gps": payload_dict["gps"],
            "location_name": payload_dict.get("location_name"),
            "status": "success",
            
            # Legacy keys
            "classification": ingestion_result["classification"],
            "dispatch_simulation": dispatch_result,
            
            # Layout mappings matching the mobile client
            "detection": {
                "issue_type": ingestion_result["classification"].lower().replace(" ", "_").replace("/", "_"),
                "confidence_score": ingestion_result["confidence"],
                "visual_evidence": ingestion_result.get("visual_evidence", "")
            },
            "context": context_result,
            "reasoning": reasoning_result,
            "simulation_outcome": {
                "case_id": dispatch_result.get("case_id", "SC-204"),
                "assigned_responder": dispatch_result.get("assigned_responder", ""),
                "municipal_notice_drafted": dispatch_result.get("municipal_notice_drafted", ""),
                "estimated_resolution_time": dispatch_result.get("estimated_resolution_time", ""),
                "notice_draft": dispatch_result.get("notice_draft", ""),
                "authority": dispatch_result.get("authority", authority_result),
                "user_reward": dispatch_result.get("user_reward", {})
            },
            "authority": dispatch_result.get("authority", authority_result),
            
            # Return explicit logs for all 5 agents
            "logs": get_logs_for_report(payload.report_id),
            "agent_logs": get_logs_for_report(payload.report_id)
        }
        
        # Persist to database
        try:
            save_case(response_data)
        except Exception as db_err:
            logger.error(f"❌ Database sync failed: {str(db_err)}")
            raise HTTPException(
                status_code=500,
                detail=f"Database synchronization failed: {str(db_err)}"
            )
        
        logger.info(f"✅ Report {payload.report_id} completed successfully.")
        return response_data

    except HTTPException as http_err:
        raise http_err
    except Exception as e:
        logger.error(f"❌ Error during orchestration: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Orchestration Failed: {str(e)}")


@router.put("/verify-case/{case_id}")
async def verify_case(case_id: str):
    """Increment verification_count for a case when a user confirms they also encountered the issue."""
    logger.info(f"Verification request received for case: {case_id}")
    
    if supabase is None:
        logger.error("Supabase not configured")
        raise HTTPException(status_code=500, detail="Database not configured")
    
    try:
        # Fetch current verification count
        response = supabase.table("cases").select("verification_count").eq("case_id", case_id).execute()
        
        if not response.data:
            logger.warning(f"Case not found: {case_id}")
            raise HTTPException(status_code=404, detail=f"Case {case_id} not found")
        
        current_count = response.data[0].get("verification_count", 0) or 0
        new_count = current_count + 1
        
        # Update the verification count
        update_response = supabase.table("cases").update({"verification_count": new_count}).eq("case_id", case_id).execute()
        
        if update_response.data:
            logger.info(f"✅ Verification count incremented for {case_id}: {new_count}")
            return {"status": "success", "case_id": case_id, "verification_count": new_count}
        else:
            raise Exception(f"Supabase update returned empty response")
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Verification update failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Verification failed: {str(e)}")
