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

async def run_rejection_tests():
    print("==================================================")
    print("STARTING SNAPCITY STRICT REJECTION INTEGRATION TEST")
    print("==================================================")

    # Test Case 1: Valid civic report (Deep open manhole)
    valid_payload = {
        "report_id": "rep_valid_991",
        "image_url": "https://storage.mock/images/pothole.jpg", # Mock URL representing valid input
        "gps": {"lat": 24.9180, "lng": 67.0971},
        "voice_note_transcript": "There is a massive open manhole on the route to school."
    }

    # Test Case 2: Rejected spam/off-topic report (Cute cat)
    invalid_payload = {
        "report_id": "rep_invalid_104",
        "image_url": "https://upload.wikimedia.org/wikipedia/commons/3/3a/Cat03.jpg", # Real image of a cat
        "gps": {"lat": 24.9180, "lng": 67.0971},
        "voice_note_transcript": "Look at this incredibly cute stray cat I found sitting on the street."
    }

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Dispatch Valid Report
        print("\n--- [TEST 1] Dispatching Valid Civic Report ---")
        res_valid = await client.post("/api/v1/report", json=valid_payload)
        print(f"Status Code: {res_valid.status_code}")
        print("Response JSON:")
        print(json.dumps(res_valid.json(), indent=2))

        # 2. Dispatch Invalid Report
        print("\n--- [TEST 2] Dispatching Invalid Off-Topic Report (Cat Picture) ---")
        res_invalid = await client.post("/api/v1/report", json=invalid_payload)
        print(f"Status Code: {res_invalid.status_code}")
        print("Response JSON:")
        print(json.dumps(res_invalid.json(), indent=2))

if __name__ == "__main__":
    asyncio.run(run_rejection_tests())
