import os

import googlemaps
from dotenv import load_dotenv

from utils.logger import get_agent_logger

load_dotenv()

logger = get_agent_logger("TrafficService")

GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
gmaps = googlemaps.Client(key=GOOGLE_MAPS_API_KEY) if GOOGLE_MAPS_API_KEY else None


def get_traffic(lat: float, lng: float) -> str:
    """Fetch real-time traffic using Google Maps Directions API."""
    if gmaps is None:
        logger.warning("GOOGLE_MAPS_API_KEY not set. Returning traffic fallback.")
        return "Normal Flow"

    try:
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
                return f"Severe Congestion ({int(slowdown_pct)}% slower than usual)"
            if slowdown_pct > 10:
                return f"Moderate Slowdown ({int(slowdown_pct)}% slower)"
            return "Normal Flow"

    except Exception as e:
        logger.error(f"Google Maps Traffic API failed: {e}")

    return "Normal Flow"
