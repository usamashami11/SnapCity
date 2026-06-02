import os
import json
from datetime import datetime
from math import radians, sin, cos, sqrt, atan2
from typing import List, Dict, Any, Optional
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# Priority: Service Role Key for backend write access, fallback to Anon Key
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_ANON_KEY")

print(f"\n{'='*80}")
print(f"🔧 SUPABASE DATABASE INITIALIZATION")
print(f"URL: {SUPABASE_URL}")
print(f"KEY: {SUPABASE_KEY[:20] if SUPABASE_KEY else 'NOT SET'}...")
print(f"{'='*80}\n")

supabase: Optional[Client] = None
if SUPABASE_URL and SUPABASE_KEY:
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("✅ Supabase client created successfully")
    except Exception as e:
        print(f"❌ CRITICAL: Failed to create Supabase client: {str(e)}")
else:
    print(f"❌ CRITICAL: Missing environment variables. URL={bool(SUPABASE_URL)}, KEY={bool(SUPABASE_KEY)}")


def save_case(case_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Save case to Supabase 'cases' table with verification_count=1 and strict error handling.
    
    Args:
        case_data: Complete case dictionary from orchestration pipeline
        
    Returns:
        Response data from Supabase if successful
        
    Raises:
        Exception: If Supabase is not configured or write operation fails
    """
    print(f"\n{'='*80}")
    print(f"💾 ATTEMPTING SUPABASE CASE WRITE")
    print(f"Report ID: {case_data.get('report_id')}")
    print(f"{'='*80}")
    
    if supabase is None:
        error_msg = "❌ CRITICAL: Supabase not configured. Ensure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set in the environment or .env file."
        print(error_msg)
        raise Exception(error_msg)
    
    try:
        # Extract and validate case data
        report_id = case_data.get("report_id")
        case_id = case_data.get("simulation_outcome", {}).get("case_id")
        lat = case_data.get("gps", {}).get("lat")
        lng = case_data.get("gps", {}).get("lng")
        issue_type = case_data.get("detection", {}).get("issue_type")
        severity_level = case_data.get("reasoning", {}).get("severity_level")
        
        print(f"📋 Extracted fields:")
        print(f"   - report_id: {report_id}")
        print(f"   - case_id: {case_id}")
        print(f"   - lat: {lat}, lng: {lng}")
        print(f"   - issue_type: {issue_type}")
        print(f"   - severity_level: {severity_level}")
        
        # Build row with strict schema matching
        row = {
            "report_id": report_id,
            "case_id": case_id,
            "timestamp": case_data.get("timestamp") or datetime.utcnow().isoformat(),
            "image_url": case_data.get("image_url"),
            "lat": float(lat) if lat is not None else 0.0,
            "lng": float(lng) if lng is not None else 0.0,
            "location_name": case_data.get("location_name") or case_data.get("context", {}).get("area"),
            "classification": case_data.get("classification"),
            "issue_type": issue_type,
            "confidence_score": case_data.get("detection", {}).get("confidence_score"),
            "area": case_data.get("context", {}).get("area"),
            "severity_level": severity_level,
            "supervisor_summary": case_data.get("reasoning", {}).get("escalation_reason") or case_data.get("escalation_reason"),
            "verification_count": 1,
            "raw_data": case_data,
        }
        
        print(f"\n📤 Sending upsert payload to Supabase:")
        print(f"   - Table: 'cases'")
        print(f"   - Rows: {json.dumps(row, indent=2, default=str)[:200]}...")
        
        # Execute insert with explicit error capture
        print(f"\n🔄 Executing Supabase insert()...")
        try:
            response = supabase.table("cases").insert(row).execute()
        except Exception as e:
            print(f"SUPABASE ERROR: {e}")
            from fastapi import HTTPException
            raise HTTPException(status_code=500, detail=f"SUPABASE ERROR: {str(e)}")
        
        print(f"\n📬 Supabase response received:")
        print(f"   - Status: Success")
        print(f"   - Data: {response.data}")
        
        # Strict assertion: verify response contains data
        if not response.data:
            error_msg = f"❌ CRITICAL WRITE CRASH: Supabase insert returned empty data. Full response: {response}"
            print(error_msg)
            raise Exception(error_msg)
        
        print(f"\n✅ CASE WRITE SUCCESSFUL")
        print(f"   - Case ID: {case_id}")
        print(f"   - Verification Count: 1")
        print(f"{'='*80}\n")
        
        return response.data[0] if isinstance(response.data, list) else response.data
        
    except Exception as e:
        error_msg = f"❌ CRITICAL WRITE CRASH: {str(e)}"
        print(error_msg)
        print(f"Exception type: {type(e).__name__}")
        print(f"Full traceback: {e}")
        print(f"{'='*80}\n")
        raise e


def increment_verification(case_id: str) -> Dict[str, Any]:
    """
    Increment the verification_count for a specific case by 1.
    
    Args:
        case_id: The case ID to increment
        
    Returns:
        Updated case data
        
    Raises:
        Exception: If case not found or update fails
    """
    print(f"\n{'='*80}")
    print(f"🔄 ATTEMPTING VERIFICATION COUNT INCREMENT")
    print(f"Case ID: {case_id}")
    print(f"{'='*80}")
    
    if supabase is None:
        error_msg = "❌ CRITICAL: Supabase not configured"
        print(error_msg)
        raise Exception(error_msg)
    
    try:
        # Fetch current count
        print(f"\n📖 Fetching current case data...")
        response = supabase.table("cases").select("verification_count").eq("case_id", case_id).execute()
        
        if not response.data:
            error_msg = f"❌ CRITICAL: Case not found: {case_id}"
            print(error_msg)
            raise Exception(error_msg)
        
        current_count = response.data[0].get("verification_count", 0) or 0
        new_count = current_count + 1
        
        print(f"   - Current verification_count: {current_count}")
        print(f"   - New verification_count: {new_count}")
        
        # Update the count
        print(f"\n📤 Updating verification_count to {new_count}...")
        update_response = supabase.table("cases").update({"verification_count": new_count}).eq("case_id", case_id).execute()
        
        if not update_response.data:
            error_msg = f"❌ CRITICAL WRITE CRASH: Update returned empty response for case {case_id}"
            print(error_msg)
            raise Exception(error_msg)
        
        print(f"✅ VERIFICATION COUNT INCREMENTED SUCCESSFULLY")
        print(f"   - Case ID: {case_id}")
        print(f"   - New Count: {new_count}")
        print(f"{'='*80}\n")
        
        return {"case_id": case_id, "verification_count": new_count}
        
    except Exception as e:
        error_msg = f"❌ CRITICAL INCREMENT CRASH: {str(e)}"
        print(error_msg)
        print(f"{'='*80}\n")
        raise e


def get_all_cases() -> List[Dict[str, Any]]:
    """Fetch all cases from Supabase."""
    if supabase is None:
        return []
    try:
        response = supabase.table("cases").select("*").order("created_at", desc=True).execute()
        results = []
        for row in response.data:
            raw_data = row.get("raw_data")
            if not raw_data:
                # Reconstruct raw_data from columns
                raw_data = {
                    "report_id": row.get("report_id") or "rep_unknown",
                    "timestamp": row.get("timestamp") or row.get("created_at"),
                    "image_url": row.get("image_url") or "",
                    "gps": {"lat": row.get("lat") or 0.0, "lng": row.get("lng") or 0.0},
                    "location_name": row.get("location_name") or row.get("area") or "",
                    "classification": row.get("classification") or row.get("issue_type") or "",
                    "detection": {
                        "issue_type": row.get("issue_type") or "",
                        "confidence_score": row.get("confidence_score") or 100,
                    },
                    "context": {
                        "area": row.get("area") or row.get("location_name") or "",
                        "similar_reports_nearby": 0,
                    },
                    "reasoning": {
                        "severity_level": row.get("severity_level") or "MEDIUM",
                    },
                    "simulation_outcome": {
                        "case_id": row.get("case_id") or row.get("report_id") or "SC-204",
                        "assigned_responder": "Municipal Authority",
                        "estimated_resolution_time": "3 days",
                        "user_reward": {"civic_points_earned": 50, "message": "Good citizen reward!"}
                    }
                }
            results.append(raw_data)
        return results
    except Exception as e:
        print(f"Error fetching from Supabase: {e}")
        return []


def _haversine_distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Return the great-circle distance between two points on the Earth."""
    lat1_r, lng1_r, lat2_r, lng2_r = map(radians, [lat1, lng1, lat2, lng2])
    delta_lat = lat2_r - lat1_r
    delta_lng = lng2_r - lng1_r
    a = sin(delta_lat / 2) ** 2 + cos(lat1_r) * cos(lat2_r) * sin(delta_lng / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return 6371.0 * c


def get_similar_cases(lat: float, lng: float, classification: str, radius_km: float = 0.1) -> List[Dict[str, Any]]:
    """Find similar nearby cases with the same classification."""
    if supabase is None:
        return []
    try:
        lat_delta = radius_km / 111.0
        lng_delta = radius_km / 111.0

        response = supabase.table("cases") \
            .select("raw_data, lat, lng, classification") \
            .gte("lat", lat - lat_delta) \
            .lte("lat", lat + lat_delta) \
            .gte("lng", lng - lng_delta) \
            .lte("lng", lng + lng_delta) \
            .execute()

        matches = []
        for row in response.data:
            row_lat = row.get("lat")
            row_lng = row.get("lng")
            row_class = (row.get("classification") or "").lower().strip()
            if row_lat is None or row_lng is None:
                continue
            if row_class != classification.lower().strip():
                continue
            distance = _haversine_distance_km(lat, lng, float(row_lat), float(row_lng))
            if distance <= radius_km:
                matches.append({
                    "distance_km": distance,
                    "report_id": row.get("report_id"),
                    "context": row.get("raw_data", {}).get("context", {}),
                    "raw_data": row.get("raw_data", {}),
                })
        return sorted(matches, key=lambda item: item["distance_km"])
    except Exception as e:
        print(f"Error querying similar cases from Supabase: {e}")
        return []


def get_nearby_cases_count(lat: float, lng: float, radius_km: float = 0.5) -> int:
    """Calculate nearby cases count using bounding box."""
    if supabase is None:
        return 0
    try:
        lat_delta = radius_km / 111.0
        lng_delta = radius_km / 111.0

        response = supabase.table("cases") \
            .select("report_id") \
            .gte("lat", lat - lat_delta) \
            .lte("lat", lat + lat_delta) \
            .gte("lng", lng - lng_delta) \
            .lte("lng", lng + lng_delta) \
            .execute()

        return len(response.data)
    except Exception as e:
        print(f"Error querying nearby from Supabase: {e}")
        return 0
