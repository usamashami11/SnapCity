import os
import json
from math import radians, sin, cos, sqrt, atan2
from typing import List, Dict, Any, Optional
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_KEY")

supabase: Optional[Client] = None
if SUPABASE_URL and SUPABASE_ANON_KEY:
    supabase = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)


def save_case(case_data: Dict[str, Any]):
    """Save case to Supabase 'cases' table."""
    if supabase is None:
        print("Supabase not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in backend/.env")
        return
    try:
        row = {
            "report_id": case_data.get("report_id"),
            "case_id": case_data.get("simulation_outcome", {}).get("case_id"),
            "timestamp": case_data.get("timestamp"),
            "image_url": case_data.get("image_url"),
            "lat": case_data.get("gps", {}).get("lat"),
            "lng": case_data.get("gps", {}).get("lng"),
            "location_name": case_data.get("location_name") or case_data.get("context", {}).get("area"),
            "classification": case_data.get("classification"),
            "issue_type": case_data.get("detection", {}).get("issue_type"),
            "confidence_score": case_data.get("detection", {}).get("confidence_score"),
            "area": case_data.get("context", {}).get("area"),
            "severity_level": case_data.get("reasoning", {}).get("severity_level"),
            "raw_data": case_data,
        }
        supabase.table("cases").upsert(row).execute()
    except Exception as e:
        print(f"Error saving to Supabase: {e}")


def get_all_cases() -> List[Dict[str, Any]]:
    """Fetch all cases from Supabase."""
    if supabase is None:
        return []
    try:
        response = supabase.table("cases").select("raw_data").order("created_at", desc=True).execute()
        return [row["raw_data"] for row in response.data]
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
