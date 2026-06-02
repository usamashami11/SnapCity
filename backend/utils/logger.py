import logging
import sys
import json
from datetime import datetime
import os

# Calculate absolute paths relative to the utils/logger.py file directory
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
# Ensures absolute anchoring within backend workspace regardless of where runtime CMD invoker is located
BACKEND_DIR = os.path.abspath(os.path.join(CURRENT_DIR, ".."))
LOG_FILE_PATH = os.path.join(BACKEND_DIR, "agent_traces.log")
JSON_FILE_PATH = os.path.join(BACKEND_DIR, "agent_traces.json")

# Reconfigure standard output to support UTF-8 Emojis on Windows terminals cleanly
import io
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    elif hasattr(sys.stdout, 'buffer'):
        # Fallback: wrap raw buffer with utf-8 TextIOWrapper
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
except Exception:
    pass

# Map high-clarity emojis to each SnapCity Swarm component for premium terminal visualization
EMOJI_MAP = {
    "Supervisor Agent": "🧠",
    "Ingestion Agent": "👁️",
    "Context Agent": "📚",
    "Reasoning Agent": "⚙️",
    "Dispatch Agent": "🚀"
}

# 1. Elite Terminal & File Text Formatter
class AgentFormatter(logging.Formatter):
    def format(self, record):
        timestamp = datetime.now().strftime("%H:%M:%S")
        emoji = EMOJI_MAP.get(record.name, "📝")
        return f"[{timestamp}] {emoji} [{record.name}] {record.getMessage()}"

# 2. Structured JSON File Formatter (NDJSON format)
class JsonFormatter(logging.Formatter):
    def format(self, record):
        emoji = EMOJI_MAP.get(record.name, "📝")
        log_data = {
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "emoji": emoji,
            "agent": record.name,
            "level": record.levelname,
            "message": record.getMessage()
        }
        return json.dumps(log_data, ensure_ascii=False)

logger = logging.getLogger("CIRO_Swarm")
logger.setLevel(logging.DEBUG)

# Standard Text File handler
file_handler = logging.FileHandler(LOG_FILE_PATH, mode='a', encoding='utf-8')
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(AgentFormatter())

# Structured JSON File handler (NDJSON / JSON lines)
json_handler = logging.FileHandler(JSON_FILE_PATH, mode='a', encoding='utf-8')
json_handler.setLevel(logging.DEBUG)
json_handler.setFormatter(JsonFormatter())

# Console Stream handler
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(AgentFormatter())

def get_agent_logger(agent_name: str):
    agent_logger = logging.getLogger(agent_name)
    agent_logger.setLevel(logging.DEBUG)
    
    # Avoid duplicate handlers if logger instantiated repeatedly
    if not agent_logger.handlers:
        agent_logger.addHandler(file_handler)
        agent_logger.addHandler(json_handler)
        agent_logger.addHandler(console_handler)
        
    # Prevent log bubbling up to the root logger which might double print
    agent_logger.propagate = False
    return agent_logger
