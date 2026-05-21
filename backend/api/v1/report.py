from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

from agents.ingestion import IngestionAgent
from agents.context import ContextAgent
from agents.reasoning import ReasoningAgent
from agents.dispatch import DispatchAgent
from agents.authority_finder import AuthorityFinderAgent
from utils.logger import get_agent_logger
from services.database import save_case, get_all_cases
from datetime import datetime

router = APIRouter()
logger = get_agent_logger("CIRO_Report_API")

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

# Initialize Swarm Agents
ingestion_agent = IngestionAgent()
context_agent = ContextAgent()
reasoning_agent = ReasoningAgent()
dispatch_agent = DispatchAgent()
authority_finder_agent = AuthorityFinderAgent()

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
    logger.info(f"NEW INCIDENT RECEIVED IN API: {payload.report_id}")
    logger.info("="*50)
    
    payload_dict = payload.model_dump() if hasattr(payload, "model_dump") else payload.dict()
    
    try:
        # Step 1: Multi-Modal Ingestion
        ingestion_result = ingestion_agent.process(payload_dict)
        
        # Strict Rejection Policy Guard
        if not ingestion_result.get("is_valid_civic_issue", True):
            raw_response = ingestion_result.get("raw_model_response", "Raw response not available.")
            logger.warning(f"REJECTING - Raw model response from IngestionAgent: {raw_response}")
            logger.warning(f"Incident {payload.report_id} REJECTED: Invalid civic issue content.")
            logger.info("="*50)
            raise HTTPException(status_code=400, detail="Invalid Image: Please upload a clear photo of the civic issue.")
        
        # Step 2: Context & Triangulation (Signal Fusion)
        context_result = context_agent.process(payload_dict, ingestion_result)
        
        # Step 3: Reasoning & Severity
        reasoning_result = reasoning_agent.process(ingestion_result, context_result)
        
        # Step 3.5: Find the best authority routing path for this report
        authority_result = authority_finder_agent.process(
            payload_dict,
            ingestion_result,
            context_result,
        )

        # Step 4: Action Simulator & Dispatch
        dispatch_result = dispatch_agent.process(
            payload_dict,
            ingestion_result,
            context_result,
            reasoning_result,
            authority_result,
        )

        logger.info(f"Incident {payload.report_id} Orchestration Complete.")
        logger.info("="*50)

        # Construct Final Response
        response_data = {
            "report_id": payload.report_id,
            "timestamp": payload.timestamp or datetime.utcnow().isoformat(),
            "image_url": payload.image_url,
            "gps": payload_dict["gps"],
            "location_name": payload_dict.get("location_name"),
            "status": "success",
            
            # Legacy fields for backwards compatibility
            "classification": ingestion_result["classification"],
            "dispatch_simulation": dispatch_result,
            
            # Fields matching the Flutter app sample output layout
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
            "authority": dispatch_result.get("authority", authority_result)
        }
        
        # Phase 1: Persistence
        save_case(response_data)
        
        return response_data

    except Exception as e:
        logger.error(f"Error during orchestration: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Orchestration Failed: {str(e)}")
