"""
English Coach backend.

Step 1: a skeleton server. The /analyze endpoint accepts an audio file
and returns FAKE (dummy) results so the app can be built and tested
before we connect the real AI services.
"""

import os

from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, UploadFile

# Read the secret keys from the .env file into the program.
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")          # for Whisper (speech -> text)
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")    # for Claude (grammar feedback)
AZURE_SPEECH_KEY = os.getenv("AZURE_SPEECH_KEY")      # for pronunciation scoring
AZURE_SPEECH_REGION = os.getenv("AZURE_SPEECH_REGION")

app = FastAPI(title="English Coach API")


@app.get("/")
def health_check():
    """A simple 'are you alive?' check. Also shows which keys were found (never the keys themselves)."""
    return {
        "status": "ok",
        "keys_loaded": {
            "openai": bool(OPENAI_API_KEY),
            "anthropic": bool(ANTHROPIC_API_KEY),
            "azure_speech": bool(AZURE_SPEECH_KEY and AZURE_SPEECH_REGION),
        },
    }


@app.post("/analyze")
async def analyze(audio: UploadFile = File(...)):
    """Receive a recording and return feedback. For now the feedback is dummy data."""
    content = await audio.read()
    if not content:
        raise HTTPException(status_code=400, detail="The audio file is empty.")

    # Later steps will replace this dummy data with real results from
    # Whisper, Claude and Azure.
    return {
        "file_name": audio.filename,
        "file_size_bytes": len(content),
        "transcript": "I goes to school yesterday.",
        "corrected_sentence": "I went to school yesterday.",
        "better_alternatives": [
            "Yesterday, I went to school.",
            "I attended school yesterday.",
        ],
        "grammar_notes": [
            "Use the past tense 'went' because 'yesterday' is in the past."
        ],
        "pronunciation": {
            "overall_score": 82,
            "accuracy": 85,
            "fluency": 78,
            "completeness": 90,
        },
        "is_dummy_data": True,
    }
