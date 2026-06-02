import os
from pydantic import BaseModel, Field
from dotenv import load_dotenv

# Load local environment variables from .env
load_dotenv()

from google import genai
from google.genai import types

from utils.logger import get_agent_logger
from services.weather import get_weather
from services.traffic import get_traffic
from services.database import get_nearby_cases_count, get_similar_cases

logger = get_agent_logger("Context Agent")

# Google GenAI client (safely initialized at import-time)
client = None
try:
    client = genai.Client()
except Exception as e:
    logger.warning(f"Failed to initialize Google GenAI Client: {str(e)}. Agent will operate in fallback mode.")

class SignalFusionResult(BaseModel):
    area: str = Field(
        description="A synthesized or deduced neighborhood or city area name based on the GPS coordinates. E.g. 'Block 7, Gulshan-e-Iqbal' or 'Broadway Ave, Midtown'."
    )
    weather_condition: str = Field(
        description="Summary weather description, incorporating potential hazards (e.g. 'Heavy rain expected' or 'Clear and dry')."
    )
    traffic_impact: str = Field(
        description="Traffic impact assessment caused by the infrastructure issue (e.g. 'Slowdown detected', 'Gridlock risk', 'Uncongested')."
    )
    similar_reports_nearby: int = Field(
        description="Triangulated number of similar reports nearby based on cluster telemetry."
    )
    environmental_layout_summary: str = Field(
        description="A comprehensive synthesis of the environment, integrating traffic, storm conditions, and location vulnerability."
    )
    semantic_tags: list[str] = Field(
        description="List of risk labels reflecting environmental variables, such as 'Active Flood Risk', 'High Vulnerability Route', 'Chronic Failure Zone', 'Severe Traffic Bottleneck'."
    )
    internal_thought: str = Field(
        description="Detailed thought pattern explaining the signal fusion and context formulation process."
    )

class ContextAgent:
    """Context & Triangulation Agent performing Signal Fusion via Gemini-2.5-Flash."""

    def process(self, payload: dict, ingestion_result: dict) -> dict:
        report_id = payload.get("report_id", "unknown")
        gps = payload.get("gps", {})
        lat = gps.get("lat")
        lng = gps.get("lng")
        classification = ingestion_result.get("classification", "Unknown")
        confidence = ingestion_result.get("confidence", 80)

        logger.info(f"[{report_id}] Context Agent process started. Initiating local service pings...")

        # 1. Ping Local Services
        logger.info(f"[{report_id}] Pinging weather service for ({lat}, {lng})...")
        weather = get_weather(lat, lng)
        logger.info(f"[{report_id}] Result: Weather = '{weather}'")

        logger.info(f"[{report_id}] Pinging traffic service for ({lat}, {lng})...")
        traffic = get_traffic(lat, lng)
        logger.info(f"[{report_id}] Result: Traffic = '{traffic}'")

        # Dynamic duplication telemetry
        location_name = payload.get("location_name") or payload.get("area")
        similar_cases = get_similar_cases(lat, lng, classification)
        simulated_similar_count = len(similar_cases)
        if similar_cases:
            primary_similar = similar_cases[0]
            existing_cluster = (
                primary_similar.get("context", {}).get("duplicate_cluster_id")
                or primary_similar.get("raw_data", {}).get("context", {}).get("duplicate_cluster_id")
            )
        else:
            existing_cluster = None

        simulated_cluster_id = existing_cluster or (f"Cluster_{report_id[-4:].upper()}" if simulated_similar_count > 0 else None)
        logger.info(f"[{report_id}] Triangulating nearby issues. Found {simulated_similar_count} similar reports. Using cluster id {simulated_cluster_id}.")

        # 2. Formulate Signal Fusion Prompt
        raw_prompt = (
            f"GPS Coordinates: Lat={lat}, Lng={lng}\n"
            f"Classified Issue: '{classification}' (Confidence: {confidence}%)\n"
            f"Frontend Submitted Location: '{location_name or 'Unknown'}'\n"
            f"Local Weather Sensor: '{weather}'\n"
            f"Local Traffic Telemetry: '{traffic}'\n"
            f"Active Triangulated Cluster: Cluster ID={simulated_cluster_id}, Similar Reports Nearby={simulated_similar_count}\n\n"
            "Task: You are the Context & Triangulation Agent for SnapCity. Perform 'Signal Fusion'.\n"
            "Synthesize these environmental and telemetry inputs into a high-quality environmental layout packet. "
            "Formulate a realistic city neighborhood/area name corresponding to these coordinates or submitted location.\n"
            "Determine the traffic impact and weather conditions. Summarize the overall environmental risk. "
            "Append key semantic tag labels (such as 'Active Flood Risk', 'High Vulnerability Route', 'Chronic Failure Zone', 'Severe Traffic Bottleneck') based on the data points. "
            "Include your detailed step-by-step internal thoughts explaining your fusion process."
        )

        logger.info(f"[{report_id}] Preparing signal fusion payload for primary model 'gemini-3.1-flash-lite' (fallback: 'gemini-2.5-flash')...")
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
                        response_schema=SignalFusionResult,
                        temperature=0.2
                    )
                )
                logger.info(f"[{report_id}] Context Signal Fusion completed via primary 'gemini-3.1-flash-lite'.")
            except Exception as model_err:
                logger.warning(f"[{report_id}] Primary model 'gemini-3.1-flash-lite' failed: {str(model_err)}. Falling back to 'gemini-2.5-flash'...")
                response = client.models.generate_content(
                    model='gemini-2.5-flash',
                    contents=raw_prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_schema=SignalFusionResult,
                        temperature=0.2
                    )
                )
                logger.info(f"[{report_id}] Context Signal Fusion completed via secondary fallback 'gemini-2.5-flash'.")

            result: SignalFusionResult = response.parsed

            logger.info(f"[{report_id}] Context Signal Fusion complete via LLM.")
            logger.info(f"[{report_id}] Model Thought Process:\n{result.internal_thought}")
            logger.info(f"[{report_id}] Synthesized Area: '{result.area}'")
            logger.info(f"[{report_id}] Environmental Layout: '{result.environmental_layout_summary}'")
            logger.info(f"[{report_id}] Semantic Tags: {result.semantic_tags}")

            # Return a compatible dictionary combining old keys (for main.py) and new keys (matching sample output)
            return {
                # Old/existing keys
                "weather": weather,
                "traffic": traffic,
                "duplicate_cluster_id": simulated_cluster_id,
                
                # New sample-matching keys
                "area": location_name or result.area,
                "weather_condition": result.weather_condition,
                "traffic_impact": result.traffic_impact,
                "similar_reports_nearby": simulated_similar_count,
                
                # Enhanced keys
                "environmental_layout_summary": result.environmental_layout_summary,
                "semantic_tags": result.semantic_tags,
                "internal_thought": result.internal_thought,
            }

        except Exception as e:
            logger.error(f"[{report_id}] LLM Context Signal Fusion failed: {str(e)}. Falling back to deterministic fusion.")
            
            # Resilient fallback formulation
            fallback_area = "Block 7, Gulshan-e-Iqbal" if (lat and lat > 24 and lat < 25) else "Midtown District"
            fallback_weather = "Heavy rain expected" if weather == "Heavy Rain" else "Clear and sunny"
            fallback_traffic = "Slowdown detected" if traffic == "Heavy" else "Normal flow"
            
            fallback_tags = []
            if weather == "Heavy Rain":
                fallback_tags.append("Active Flood Risk")
            if traffic == "Heavy":
                fallback_tags.append("High Vulnerability Route")
            # If simulated cluster count is high, determine it as chronic fail zone in fallback
            if simulated_similar_count > 5:
                fallback_tags.append("Chronic Failure Zone")

            fallback_layout = f"Signal Fusion Fallback. Ingestion: '{classification}'. Environmental context Triangulated: Weather={fallback_weather}, Traffic={fallback_traffic}."
            fallback_thought = "LLM pipeline call failed. Deterministic Signal Fusion is running as high-reliability fallback."

            logger.info(f"[{report_id}] FALLBACK Area: '{fallback_area}', Tags: {fallback_tags}")
            
            return {
                # Old/existing keys
                "weather": weather,
                "traffic": traffic,
                "duplicate_cluster_id": simulated_cluster_id,

                # New keys
                "area": location_name or fallback_area,
                "weather_condition": fallback_weather,
                "traffic_impact": fallback_traffic,
                "similar_reports_nearby": simulated_similar_count,

                # Enhanced keys
                "environmental_layout_summary": fallback_layout,
                "semantic_tags": fallback_tags,
                "internal_thought": fallback_thought
            }
