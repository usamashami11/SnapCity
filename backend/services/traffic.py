import os
import requests
import googlemaps
from dotenv import load_dotenv

from utils.logger import get_agent_logger

load_dotenv()

logger = get_agent_logger("TrafficService")

GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
gmaps = None
if GOOGLE_MAPS_API_KEY and not any(placeholder in GOOGLE_MAPS_API_KEY for placeholder in ["YOUR_GOOGLE_MAPS_API_KEY", "YOUR_API_KEY", "placeholder", "google_maps_key"]):
    try:
        gmaps = googlemaps.Client(key=GOOGLE_MAPS_API_KEY)
    except Exception as e:
        logger.warning(f"Failed to initialize Google Maps client: {e}")


def get_traffic(lat: float, lng: float) -> str:
    """
    Fetches real-time traffic using a dual-provider model:
    1. Primary: OpenStreetMap Nominatim reverse geocoding to infer traffic by road class.
    2. Fallback: Google Maps Directions API (if configured and OSM fails).
    3. Tertiary: Static fallback values.
    """
    logger.info(f"Analyzing road traffic density for: Lat={lat}, Lng={lng}")

    if lat is None or lng is None:
        logger.warning("Invalid coordinates provided to traffic service. Using default.")
        return "Heavy (Simulated fallback)"

    # --- 1. Primary: OpenStreetMap Nominatim ---
    url = f"https://nominatim.openstreetmap.org/reverse?format=json&lat={lat}&lon={lng}"
    headers = {
        "User-Agent": "SnapCity-CIRO-Traffic/1.0 (contact: support@snapcity.example.com)",
        "Accept-Language": "en"
    }

    try:
        logger.info("Attempting OSM Nominatim reverse lookup...")
        response = requests.get(url, headers=headers, timeout=4)
        if response.status_code == 200:
            data = response.json()
            address = data.get("address", {})
            road_name = address.get("road", "Unknown Road")
            suburb = address.get("suburb", address.get("neighbourhood", "Unknown Suburb"))
            city = address.get("city", address.get("town", address.get("county", "Unknown Area")))

            road_type = data.get("type", "").lower()
            osm_class = data.get("class", "").lower()

            logger.info(f"OSM Nominatim Geocoded: Road='{road_name}', Type='{road_type}', Class='{osm_class}'")

            if osm_class in ["highway"] and road_type in ["motorway", "trunk", "primary"]:
                traffic_status = f"Heavy (Arterial backup on major road: {road_name}, {suburb})"
            elif osm_class in ["highway"] and road_type in ["secondary", "tertiary"]:
                traffic_status = f"Moderate (Feeder traffic on {road_name}, {suburb})"
            elif osm_class in ["highway"] and road_type in ["residential", "living_street", "service"]:
                traffic_status = f"Light (Uncongested local flow on {road_name})"
            else:
                traffic_status = f"Moderate (General urban flow in {suburb}, {city})"

            logger.info(f"OSM dynamic traffic condition calculated: {traffic_status}")
            return traffic_status
        else:
            logger.warning(f"OSM Nominatim returned status code {response.status_code}.")
    except Exception as e:
        logger.warning(f"OSM Nominatim traffic lookup failed: {str(e)}.")

    # --- 2. Fallback: Google Maps Directions ---
    if gmaps is not None:
        try:
            logger.info("Falling back to Google Maps Directions API traffic lookup...")
            origin = (lat, lng)
            destination = (lat + 0.001, lng + 0.001)

            directions_result = gmaps.directions(
                origin,
                destination,
                mode="driving",
                departure_time="now",
            )

            if directions_result:
                leg = directions_result[0]["legs"][0]
                duration = leg["duration"]["value"]
                duration_in_traffic = leg.get("duration_in_traffic", {}).get("value", duration)

                slowdown_pct = ((duration_in_traffic - duration) / duration) * 100 if duration > 0 else 0

                if slowdown_pct > 30:
                    status = f"Severe Congestion ({int(slowdown_pct)}% slower than usual)"
                elif slowdown_pct > 10:
                    status = f"Moderate Slowdown ({int(slowdown_pct)}% slower)"
                else:
                    status = "Normal Flow"

                logger.info(f"Google Maps traffic condition calculated: {status}")
                return status
        except Exception as e:
            logger.error(f"Google Maps traffic fallback failed: {str(e)}")

    # --- 3. Tertiary Fallback ---
    logger.warning("All traffic services failed or unconfigured. Returning default fallback.")
    return "Normal Flow"
