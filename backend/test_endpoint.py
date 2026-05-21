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

async def test_pipeline():
    print("========================================")
    print("STARTING SNAPCITY AGENT SWARM INTEGRATION TEST (ASYNC)")
    print("========================================")

    payload = {
        "report_id": "rep_10293",
        "image_url": "https://storage.mock/images/issue_01.jpg",
        "gps": {
            "lat": 24.9180,
            "lng": 67.0971
        },
        "voice_note_transcript": "There is a deep open manhole on the main school route causing severe danger for kids walking home in this storm."
    }

    print(f"Sending payload:\n{json.dumps(payload, indent=2)}")

    try:
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            print("\n--- TEST 1: VALID CIVIC ISSUE ---")
            response1 = await client.post("/api/v1/report", json=payload)
            print(f"Response Status Code: {response1.status_code}")
            if response1.status_code == 200:
                print("SUCCESS! ORCHESTRATION COMPLETED (200 OK).")
            else:
                print(f"FAILED! Server returned error: {response1.text}")
                
            print("\n--- TEST 2: INVALID CIVIC ISSUE (Guardrail Test) ---")
            invalid_payload = payload.copy()
            invalid_payload["report_id"] = "rep_99999"
            invalid_payload["voice_note_transcript"] = "Here is a cute selfie of my dog sitting inside my living room."
            
            response2 = await client.post("/api/v1/report", json=invalid_payload)
            print(f"Response Status Code: {response2.status_code}")
            if response2.status_code == 400:
                print("SUCCESS! INVALID REPORT PROPERLY REJECTED (400 Bad Request).")
                print(f"Error Message: {response2.json()}")
            else:
                print(f"FAILED! Expected 400, got: {response2.status_code} - {response2.text}")
                
    except Exception as e:
        print(f"\nCRITICAL EXCEPTION RUNNING INTEGRATION TEST: {str(e)}")

    print("\n========================================")
    print("CHECKING AGENT TRACES LOG FILE")
    print("========================================")
    
    log_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "agent_traces.log")
    if os.path.exists(log_file):
        print(f"Log file found at: {log_file}")
        print("\nLast 40 lines of agent_traces.log:\n")
        with open(log_file, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
            for line in lines[-40:]:
                print(line.strip())
    else:
        print("Log file NOT found!")

if __name__ == "__main__":
    asyncio.run(test_pipeline())
