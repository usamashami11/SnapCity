import warnings
# Suppress Pydantic UserWarnings triggered during google-genai schema compilation
warnings.filterwarnings("ignore", category=UserWarning, module="pydantic")

import os

from fastapi import FastAPI
from dotenv import load_dotenv

# Load local environment variables from .env at startup
load_dotenv()

# google-genai reads GOOGLE_API_KEY; project standard is GEMINI_API_KEY
_gemini_key = os.getenv("GEMINI_API_KEY")
if _gemini_key:
    os.environ.setdefault("GOOGLE_API_KEY", _gemini_key)

from api.v1 import v1_router
from utils.logger import get_agent_logger

app = FastAPI(title="SnapCity CIRO API", version="1.0.0", description="Backend orchestration for Google Antigravity Hackathon Challenge 3.")
logger = get_agent_logger("CIRO_Orchestrator")

# Include the structured endpoints router
app.include_router(v1_router, prefix="/api/v1")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
