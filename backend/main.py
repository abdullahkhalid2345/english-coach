"""
English Coach backend.

Step 4: /analyze
  1. turns the recording into text with OpenAI Whisper,
  2. asks Claude for grammar corrections and speaking tips, and
  3. asks Azure Speech to score the pronunciation.
Steps 2 and 3 run at the same time to save waiting.
"""

import asyncio
import os

from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, UploadFile

from audio_convert import ffmpeg_is_installed
from feedback import DEFAULT_CLAUDE_MODEL, get_speaking_feedback
from pronunciation import assess_pronunciation
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
            "claude_model": os.getenv("CLAUDE_MODEL") or DEFAULT_CLAUDE_MODEL,
            "azure_speech": bool(AZURE_SPEECH_KEY and AZURE_SPEECH_REGION),
        },
        "ffmpeg_found": ffmpeg_is_installed(),
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
    if not transcription["transcript"]:
        raise HTTPException(
            status_code=400,
            detail="We couldn't hear any speech in the recording. Try again a bit closer to the microphone.",
        )

    # 4. Grammar feedback (Claude) and pronunciation scoring (Azure), at the same time.
    #    If Claude fails, the whole request fails with a clear error.
    #    If Azure fails, we still return everything else, with "pronunciation": null
    #    and the reason in "pronunciation_error".
    feedback, (pronunciation, pronunciation_error) = await asyncio.gather(
        get_speaking_feedback(transcription["transcript"]),
        assess_pronunciation(content, audio_format, transcription["transcript"]),
    )

    return {
        "file_name": audio.filename,
        "file_size_bytes": len(content),
        "transcript": transcription["transcript"],
        "duration_seconds": transcription["duration_seconds"],
        "corrections": feedback["corrections"],
        "better_version": feedback["better_version"],
        "filler_words": feedback["filler_words"],
        "grammar_score": feedback["grammar_score"],
        "tips": feedback["tips"],
        "pronunciation": pronunciation,
        "pronunciation_error": pronunciation_error,
    }
