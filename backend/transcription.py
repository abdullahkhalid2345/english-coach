"""
Speech-to-text using OpenAI Whisper.

This file has one job: take an audio recording and turn it into text.
Keeping it separate from main.py makes main.py easier to read, and later
steps (Claude, Azure) will get their own files in the same way.
"""

import os

import openai
from fastapi import HTTPException

# Audio formats Whisper understands. Phones usually record m4a (iPhone),
# webm/ogg (Android, browsers), mp3 or wav.
SUPPORTED_FORMATS = {"m4a", "mp3", "mp4", "mpeg", "mpga", "wav", "webm", "ogg", "oga", "flac"}

# Some phones send a file without an extension, so we can also work out
# the format from the "content type" label the phone attaches.
CONTENT_TYPE_TO_FORMAT = {
    "audio/mp4": "m4a",
    "audio/m4a": "m4a",
    "audio/x-m4a": "m4a",
    "audio/aac": "m4a",
    "audio/mpeg": "mp3",
    "audio/mp3": "mp3",
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/wave": "wav",
    "audio/webm": "webm",
    "audio/ogg": "ogg",
    "audio/flac": "flac",
    "video/mp4": "mp4",
    "video/webm": "webm",
}

# OpenAI refuses files bigger than 25 MB.
MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024

WHISPER_MODEL = "whisper-1"

# Whisper normally "cleans up" speech by deleting filler words like "um".
# We want to count them, so we show Whisper an example sentence that
# includes fillers. That nudges it to write them down too.
KEEP_FILLER_WORDS_HINT = "Umm, let me think like, hmm... Okay, uh, here's what I'm, like, you know, thinking."


def detect_format(filename: str | None, content_type: str | None) -> str:
    """Work out the audio format (e.g. "m4a") or raise a clear error."""
    if filename and "." in filename:
        extension = filename.rsplit(".", 1)[1].lower()
        if extension in SUPPORTED_FORMATS:
            return extension

    if content_type:
        base_type = content_type.split(";")[0].strip().lower()
        if base_type in CONTENT_TYPE_TO_FORMAT:
            return CONTENT_TYPE_TO_FORMAT[base_type]

    raise HTTPException(
        status_code=400,
        detail=(
            f"Unsupported audio format (file: '{filename}', type: '{content_type}'). "
            f"Please send one of: {', '.join(sorted(SUPPORTED_FORMATS))}."
        ),
    )


async def transcribe_audio(audio_bytes: bytes, audio_format: str) -> dict:
    """Send the audio to Whisper. Returns {"transcript": ..., "duration_seconds": ...}."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="OPENAI_API_KEY is missing. Add it to the backend/.env file and restart the server.",
        )

    client = openai.AsyncOpenAI(api_key=api_key)

    try:
        result = await client.audio.transcriptions.create(
            model=WHISPER_MODEL,
            # OpenAI uses the file name's ending to know the format.
            file=(f"recording.{audio_format}", audio_bytes),
            # "verbose_json" gives us the recording length as well as the text.
            response_format="verbose_json",
            # Tell Whisper to expect English. This helps with accents.
            language="en",
            prompt=KEEP_FILLER_WORDS_HINT,
        )
    except openai.AuthenticationError:
        raise HTTPException(
            status_code=500,
            detail="OpenAI rejected the API key. Check OPENAI_API_KEY in backend/.env.",
        )
    except openai.RateLimitError:
        raise HTTPException(
            status_code=429,
            detail="OpenAI says we've sent too many requests or the account has no credit left. Try again later.",
        )
    except openai.BadRequestError as error:
        raise HTTPException(
            status_code=400,
            detail=f"OpenAI could not read this audio file. Is it a real, working recording? ({error.message})",
        )
    except (openai.APIConnectionError, openai.APITimeoutError):
        raise HTTPException(
            status_code=502,
            detail="Could not reach OpenAI. Check the internet connection and try again.",
        )
    except openai.APIError as error:
        raise HTTPException(
            status_code=502,
            detail=f"OpenAI had a problem transcribing the audio: {error.message}",
        )

    return {
        "transcript": (result.text or "").strip(),
        "duration_seconds": round(result.duration, 2) if result.duration is not None else None,
    }
