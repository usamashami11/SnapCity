import os
import json
from math import radians, sin, cos, sqrt, atan2
from typing import List, Dict, Any, Optional
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

print(f"\n{'='*80}")
print(f"🔧 SUPABASE DATABASE INITIALIZATION (GOD MODE)")
print(f"URL: {SUPABASE_URL}")
print(f"KEY: {SUPABASE_SERVICE_ROLE_KEY[:20] if SUPABASE_SERVICE_ROLE_KEY else 'NOT SET'}... (SERVICE_ROLE)")
print(f"{'='*80}\n")

supabase: Optional[Client] = None
if SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY:
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        print("✅ Supabase client created successfully with SERVICE_ROLE")
    except Exception as e:
        print(f"❌ CRITICAL: Failed to create Supabase client: {str(e)}")
        raise e
else:
    print(f"❌ CRITICAL: Missing environment variables. URL={bool(SUPABASE_URL)}, SERVICE_ROLE_KEY={bool(SUPABASE_SERVICE_ROLE_KEY)}")


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
        error_msg = "❌ CRITICAL: Supabase not configured. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in backend/.env"
        print(error_msg)
        raise Exception(error_msg)
    
    try:
        # Extract and validate case data
        report_id = case_data.get("report_id")
        lat = case_data.get("gps", {}).get("lat")
        lng = case_data.get("gps", {}).get("lng")
        issue_type = case_data.get("ingestion", {}).get("classification") or case_data.get("detection", {}).get("issue_type")
        severity_level = case_data.get("reasoning", {}).get("severity_level")
        
        # Build row with strict schema matching for Phase 2 Godmode
        row = {
            "report_id": report_id,
            "lat": float(lat) if lat is not None else 0.0,
            "lng": float(lng) if lng is not None else 0.0,
            "issue_type": issue_type,
            "severity_level": severity_level,
            "verification_count": 1,
            "image_url": case_data.get("image_url"),
            "location_name": case_data.get("location_name") or case_data.get("context", {}).get("area"),
            "raw_data": case_data,
        }
        
        print(f"\n📤 FORCING SUPABASE WRITE (BYPASSING RLS):")
        print(f"   - Row: {json.dumps(row, indent=2, default=str)}")
        
        # Execute insert with explicit error capture
        response = supabase.table("cases").insert(row).execute()
        print(f"✅ SUPABASE WRITE SUCCESS: {response.data}")
        return response.data
        
    except Exception as e:
        print(f"SUPABASE ERROR: {e}")
        raise HTTPException(status_code=500, detail=f"Database force-write failed: {str(e)}")


def get_all_cases() -> List[Dict[str, Any]]:
    """Fetch all cases from Supabase."""
    if supabase is None:
        return []
    try:
        response = supabase.table("cases").select("*").order("created_at", desc=True).execute()
        return response.data
    except Exception as e:
        print(f"Error fetching cases: {e}")
        return []


def increment_verification(report_id: str) -> Dict[str, Any]:
    """Increments the verification_count for a specific case."""
    if supabase is None:
        raise Exception("Supabase not configured")
    
    try:
        # First get current count
        response = supabase.table("cases").select("verification_count").eq("report_id", report_id).execute()
        if not response.data:
            raise Exception(f"Case with report_id {report_id} not found")
        
        current_count = response.data[0].get("verification_count", 1)
        new_count = current_count + 1
        
        # Update
        update_res = supabase.table("cases").update({"verification_count": new_count}).eq("report_id", report_id).execute()
        return update_res.data[0]
    except Exception as e:
        print(f"Error incrementing verification: {e}")
        raise e


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
