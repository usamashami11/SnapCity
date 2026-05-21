import requests
from utils.logger import get_agent_logger

logger = get_agent_logger("WeatherService")

def get_weather(lat: float, lng: float) -> str:
    """Fetch real-time weather using OpenMeteo API (Free/No Key)."""
    try:
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&current=weather_code"
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            code = data.get("current", {}).get("weather_code", 0)
            
            # WMO Weather interpretation codes (simplified)
            if code == 0: return "Clear sky"
            if code in [1, 2, 3]: return "Mainly clear/Partly cloudy"
            if code in [45, 48]: return "Foggy"
            if code in [51, 53, 55]: return "Drizzle"
            if code in [61, 63, 65]: return "Rainy"
            if code in [71, 73, 75]: return "Snow fall"
            if code in [80, 81, 82]: return "Rain showers"
            if code in [95, 96, 99]: return "Thunderstorm"
            return f"Weather Code {code}"
    except Exception as e:
        logger.error(f"Weather API failed: {e}")
    
    return "Cloudy" # Default fallback
