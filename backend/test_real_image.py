import os
import sys
import json
import asyncio
import httpx

# Reconfigure standard output to support UTF-8 Emojis on Windows terminals cleanly
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

# Ensure local project folder is in the Python search path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from main import app

async def test_dynamic_real_image():
    print("==================================================")
    print("STARTING SNAPCITY DYNAMIC MULTIMODAL VISION TEST")
    print("==================================================")

    # We provide a REAL public photograph of a damaged asphalt road pothole from Wikipedia Commons
    # real_pothole_image = "https://upload.wikimedia.org/wikipedia/commons/e/e0/Pothole.jpg"
    real_pothole_image = "https://images.unsplash.com/photo-1657811146537-90d7d8133224?fm=jpg"

    payload = {
        "report_id": "rep_real_pothole_101",
        "image_url": real_pothole_image,
        "gps": {
            "lat": 24.9180,
            "lng": 67.0971
        },
        "voice_note_transcript": "There is a massive road damage pothole right in the center of the lane. Please send a crew."
    }

    print(f"\nSending payload with REAL Image URL:\n{json.dumps(payload, indent=2)}")

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        print("\n--- Dispatching Report to Swarm Engine ---")
        response = await client.post("/api/v1/report", json=payload)
        
        print(f"Status Code: {response.status_code}")
        print("\n=== Swarm Orchestrator Output Packet ===")
        print(json.dumps(response.json(), indent=2))

if __name__ == "__main__":
    asyncio.run(test_dynamic_real_image())
