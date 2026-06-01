import os
import json
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()

class AuthPayload(BaseModel):
    email: str
    password: str

# Mock Database for God Mode Authentication
ADMIN_CREDENTIALS = {
    "admin@snapcity.com": "runtime terrors"
}

# Anchored log file paths matching logger.py virtual footprint
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.dirname(os.path.dirname(CURRENT_DIR)) # Root of backend workspace
JSON_FILE_PATH = os.path.join(BACKEND_DIR, "agent_traces.json")
LOG_FILE_PATH = os.path.join(BACKEND_DIR, "agent_traces.log")

@router.post("/godmode/auth")
async def godmode_auth(payload: AuthPayload):
    """Hidden Developer Endpoint for God Mode Authentication."""
    if ADMIN_CREDENTIALS.get(payload.email) == payload.password:
        return {"status": "success", "token": "mock_jwt_token_123"}
    raise HTTPException(status_code=401, detail="Invalid credentials")

@router.get("/godmode/logs")
async def godmode_logs(token: str = None, format: str = "text"):
    """Hidden Developer Endpoint to stream agent traces for the Flutter App."""
    if token != "mock_jwt_token_123":
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    if format == "json":
        if not os.path.exists(JSON_FILE_PATH):
            return {"logs": []}
            
        try:
            with open(JSON_FILE_PATH, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
                parsed_logs = []
                for line in lines[-100:]:
                    cleaned = line.strip()
                    if cleaned:
                        try:
                            parsed_logs.append(json.loads(cleaned))
                        except Exception:
                            continue
                return {"logs": parsed_logs}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to read JSON logs: {str(e)}")
    else:
        if not os.path.exists(LOG_FILE_PATH):
            return {"logs": []}
            
        try:
            with open(LOG_FILE_PATH, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
                return {"logs": [line.strip() for line in lines[-100:]]}
        except Exception as e:
            raise HTTPException(status_code=500, detail="Failed to read logs")
