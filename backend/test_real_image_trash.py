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
    real_trash_image = "https://images.unsplash.com/photo-1626005596519-76fb9ee12d26?fm=jpg"

    payload = {
        "report_id": "rep_real_trash_100",
        "image_url": real_trash_image,
        "gps": {
            "lat": 33.4958,
            "lng": 73.1056
        },
        "voice_note_transcript": "I would like to urgently report an overflowing and unhygienic trash can in our area that is creating a foul odor and attracting pests. Could you please send a sanitation team to empty, wash, and disinfect this bin as soon as possible?"
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
