from typing import Optional
from utils.logger import get_agent_logger

logger = get_agent_logger("AuthorityFinderAgent")

class AuthorityFinderAgent:
    """Geo-aware authority routing for Pakistan civic hazards."""

    CITY_KEYWORDS = {
        "karachi": "Karachi",
        "gulshan": "Karachi",
        "defence": "Karachi",
        "lahore": "Lahore",
        "dha": "Lahore",
        "isl": "Islamabad",
        "islamabad": "Islamabad",
        "rawalpindi": "Rawalpindi",
        "faisalabad": "Faisalabad",
        "multan": "Multan",
        "hyderabad": "Hyderabad",
        "latifabad": "Hyderabad",
        "peshawar": "Peshawar",
        "quetta": "Quetta",
        "sukkur": "Sukkur",
    }

    def process(self, payload: dict, ingestion_data: dict, context_data: dict) -> dict:
        report_id = payload.get("report_id", "unknown")
        classification = ingestion_data.get("classification", "Unknown")
        location_name = (payload.get("location_name") or context_data.get("area") or "").strip()
        gps = payload.get("gps", {})
        lat = gps.get("lat")
        lng = gps.get("lng")

        city = self._identify_city(location_name, lat, lng)
        authority = self._match_authority(classification, city, location_name)

        logger.info(
            f"[{report_id}] Authority Finder routed '{classification}' to '{authority['name']}' in '{city}' for location '{location_name}'."
        )
        logger.debug(f"[{report_id}] Authority contact: {authority}")

        return authority

    def _identify_city(self, location_name: str, lat: Optional[float], lng: Optional[float]) -> str:
        lower_name = location_name.lower()
        for alias, city in self.CITY_KEYWORDS.items():
            if alias in lower_name:
                return city

        if isinstance(lat, (int, float)) and isinstance(lng, (int, float)):
            if 24.5 <= lat <= 25.5 and 66.5 <= lng <= 67.5:
                return "Karachi"
            if 31.0 <= lat <= 31.7 and 74.0 <= lng <= 74.5:
                return "Lahore"
            if 33.5 <= lat <= 34.1 and 72.8 <= lng <= 73.5:
                return "Islamabad"
            if 33.8 <= lat <= 34.2 and 72.8 <= lng <= 73.4:
                return "Rawalpindi"
            if 30.6 <= lat <= 31.0 and 73.0 <= lng <= 73.4:
                return "Faisalabad"
            if 25.3 <= lat <= 25.6 and 68.2 <= lng <= 68.7:
                return "Hyderabad"
            if 34.0 <= lat <= 35.0 and 71.2 <= lng <= 71.8:
                return "Peshawar"
            if 30.0 <= lat <= 31.0 and 66.5 <= lng <= 67.5:
                return "Quetta"

        return "Pakistan"

    def _match_authority(self, classification: str, city: str, location_name: str) -> dict:
        classification_lower = classification.lower()
        authority_profile = self._authority_profile_for(city)

        if "manhole" in classification_lower or "sewage" in classification_lower:
            return authority_profile.get("sewage", authority_profile["default"])

        if "garbage" in classification_lower or "waste" in classification_lower:
            return authority_profile.get("waste", authority_profile["default"])

        if "pothole" in classification_lower or "road" in classification_lower:
            return authority_profile.get("roads", authority_profile["default"])

        if "light" in classification_lower or "streetlight" in classification_lower:
            return authority_profile.get("streetlight", authority_profile["default"])

        return authority_profile["default"]

    def _authority_profile_for(self, city: str) -> dict:
        city_lower = city.lower()

        profiles = {
            "karachi": {
                "default": {"name": "KMC", "email": "info@kmc.gos.pk", "whatsapp": "+922199215000", "source": "Official Directory", "city": "Karachi"},
                "sewage": {"name": "Karachi Water & Sewerage Corp", "email": "info@kwsb.gos.pk", "whatsapp": "+923332222222", "source": "Official Directory", "city": "Karachi"},
                "waste": {"name": "Sindh Solid Waste Management Board", "email": "info@sswmb.gos.pk", "whatsapp": "+923181030851", "source": "Official Directory", "city": "Karachi"},
                "roads": {"name": "KMC Roads Dept", "email": "info@kmc.gos.pk", "whatsapp": "+922199215000", "source": "Official Directory", "city": "Karachi"},
                "streetlight": {"name": "K-Electric Support", "email": "speakto.us@ke.com.pk", "whatsapp": "+923480000118", "source": "Official Directory", "city": "Karachi"},
            },
            "lahore": {
                "default": {"name": "Lahore Development Authority", "email": "info@lda.gop.pk", "whatsapp": "+9242111111532", "source": "Official Directory", "city": "Lahore"},
                "sewage": {"name": "WASA Lahore", "email": "info@wasa.punjab.gov.pk", "whatsapp": "+924299264281", "source": "Official Directory", "city": "Lahore"},
                "waste": {"name": "Lahore Waste Management Company", "email": "info@lwmc.com.pk", "whatsapp": "+923151035133", "source": "Official Directory", "city": "Lahore"},
                "roads": {"name": "LDA Roads Dept", "email": "info@lda.gop.pk", "whatsapp": "+9242111111532", "source": "Official Directory", "city": "Lahore"},
                "streetlight": {"name": "LDA Infrastructure", "email": "info@lda.gop.pk", "whatsapp": "+9242111111532", "source": "Official Directory", "city": "Lahore"},
            },
            "islamabad": {
                "default": {"name": "Capital Development Authority", "email": "chairman@cda.gov.pk", "whatsapp": "+923355001213", "source": "Official Directory", "city": "Islamabad"},
                "sewage": {"name": "CDA Sanitation", "email": "sanitation@cda.gov.pk", "whatsapp": "+923355001213", "source": "Official Directory", "city": "Islamabad"},
                "waste": {"name": "CDA Sanitation", "email": "sanitation@cda.gov.pk", "whatsapp": "+923355001213", "source": "Official Directory", "city": "Islamabad"},
                "roads": {"name": "CDA Engineering", "email": "member.engineering@cda.gov.pk", "whatsapp": "+923355001213", "source": "Official Directory", "city": "Islamabad"},
                "streetlight": {"name": "CDA Streetlights", "email": "chairman@cda.gov.pk", "whatsapp": "+923355001213", "source": "Official Directory", "city": "Islamabad"},
            },
            "peshawar": {
                "default": {"name": "Water and Sanitation Services Peshawar", "email": "info@wssppeshawar.com", "whatsapp": "+92919219621", "source": "Official Directory", "city": "Peshawar"},
                "sewage": {"name": "WSSP Sewerage", "email": "info@wssppeshawar.com", "whatsapp": "+92919219621", "source": "Official Directory", "city": "Peshawar"},
                "waste": {"name": "WSSP Waste", "email": "info@wssppeshawar.com", "whatsapp": "+92919219621", "source": "Official Directory", "city": "Peshawar"},
                "roads": {"name": "Peshawar Development Authority", "email": "info@pda.gkp.pk", "whatsapp": "+92919217026", "source": "Official Directory", "city": "Peshawar"},
                "streetlight": {"name": "PDA Infrastructure", "email": "info@pda.gkp.pk", "whatsapp": "+92919217026", "source": "Official Directory", "city": "Peshawar"},
            },
            "hyderabad": {
                "default": {"name": "Hyderabad Municipal Corporation", "email": "info@hmc.gos.pk", "whatsapp": "+92229200124", "source": "Official Directory", "city": "Hyderabad"},
                "sewage": {"name": "WASA Hyderabad", "email": "info@hda.gos.pk", "whatsapp": "+92229200124", "source": "Official Directory", "city": "Hyderabad"},
                "waste": {"name": "SSWMB Hyderabad", "email": "info@sswmb.gos.pk", "whatsapp": "+923181030851", "source": "Official Directory", "city": "Hyderabad"},
                "roads": {"name": "HMC Roads", "email": "info@hmc.gos.pk", "whatsapp": "+92229200124", "source": "Official Directory", "city": "Hyderabad"},
                "streetlight": {"name": "HMC Streetlights", "email": "info@hmc.gos.pk", "whatsapp": "+92229200124", "source": "Official Directory", "city": "Hyderabad"},
            },
            "generic": {
                "default": {"name": "Provincial Municipal Authority", "email": "info@pakistan.gov.pk", "whatsapp": "+92519205300", "source": "Official Directory", "city": city},
                "sewage": {"name": "Provincial Sewerage Dept", "email": "info@pakistan.gov.pk", "whatsapp": "+92519205300", "source": "Official Directory", "city": city},
                "waste": {"name": "Provincial Waste Management", "email": "info@pakistan.gov.pk", "whatsapp": "+92519205300", "source": "Official Directory", "city": city},
                "roads": {"name": "Provincial Highway/Roads", "email": "info@pakistan.gov.pk", "whatsapp": "+92519205300", "source": "Official Directory", "city": city},
                "streetlight": {"name": "Provincial Energy/Streetlight Dept", "email": "info@pakistan.gov.pk", "whatsapp": "+92519205300", "source": "Official Directory", "city": city},
            },
        }

        return profiles.get(city_lower, profiles["generic"])
