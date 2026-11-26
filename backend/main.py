"""
English Coach backend.

Step 2: /analyze now turns the recording into real text with OpenAI Whisper.
The grammar feedback and pronunciation scores are still FAKE (dummy) data;
later steps will connect Claude and Azure.
"""

import os

from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, UploadFile

from transcription import MAX_FILE_SIZE_BYTES, detect_format, transcribe_audio

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
    """Receive a recording, transcribe it, and return feedback."""
    # 1. Check the file is a format we accept (m4a, mp3, wav, webm, ...).
    audio_format = detect_format(audio.filename, audio.content_type)

    # 2. Read the file and check it isn't empty or too big.
    content = await audio.read()
    if not content:
        raise HTTPException(status_code=400, detail="The audio file is empty.")
    if len(content) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=413,
            detail="The audio file is too big. The limit is 25 MB (about 25 minutes of speech).",
        )

    # 3. Real speech-to-text with OpenAI Whisper.
    transcription = await transcribe_audio(content, audio_format)

    # 4. Everything below "transcript" and "duration_seconds" is still dummy
    #    data. Later steps will replace it with real results from Claude and Azure.
    return {
        "file_name": audio.filename,
        "file_size_bytes": len(content),
        "transcript": transcription["transcript"],
        "duration_seconds": transcription["duration_seconds"],
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
        # Tells the app which parts are still fake.
        "dummy_fields": [
            "corrected_sentence",
            "better_alternatives",
            "grammar_notes",
            "pronunciation",
        ],
    }
