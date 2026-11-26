"""
Audio conversion using ffmpeg.

Azure's pronunciation scoring only accepts one kind of audio: WAV,
16 kHz, mono (one channel), 16-bit. Phones record m4a, webm, mp3 and so on,
so we convert with ffmpeg, a free program that can read almost any audio.
"""

import logging
import os
import shutil
import subprocess


logger = logging.getLogger(__name__)


class AudioConversionError(Exception):
    """Something went wrong converting the audio. The message is safe to show to the user."""


def find_ffmpeg() -> str:
    """Return the path to ffmpeg, or raise a clear error if it isn't installed."""
    # You can point to ffmpeg directly in .env (useful on Windows), for example:
    # FFMPEG_PATH=C:\ffmpeg\bin\ffmpeg.exe
    custom_path = os.getenv("FFMPEG_PATH")
    if custom_path:
        if os.path.isfile(custom_path):
            return custom_path
        raise AudioConversionError(f"FFMPEG_PATH in .env points to '{custom_path}', but there is no file there.")

    found = shutil.which("ffmpeg")
    if found:
        return found
    raise AudioConversionError(
        "ffmpeg is not installed (or not on the PATH), so the audio can't be prepared for "
        "pronunciation scoring. See 'Install ffmpeg' in the README."
    )


def ffmpeg_is_installed() -> bool:
    try:
        find_ffmpeg()
        return True
    except AudioConversionError:
        return False


def convert_to_azure_wav(input_path: str, output_path: str) -> None:
    """Convert any audio file into a 16 kHz, mono, 16-bit WAV file."""
    command = [
        find_ffmpeg(),
        "-y",                    # overwrite the output file if it exists
        "-loglevel", "error",    # only print real errors
        "-i", input_path,        # the uploaded recording
        "-vn",                   # ignore any video track
        "-ac", "1",              # mono
        "-ar", "16000",          # 16 kHz
        "-sample_fmt", "s16",    # 16-bit
        "-f", "wav",
        output_path,
    ]
    try:
        finished = subprocess.run(command, capture_output=True, timeout=60)
    except subprocess.TimeoutExpired:
        raise AudioConversionError("Converting the audio took too long (over 60 seconds).")
    except OSError as error:
        raise AudioConversionError(f"Could not run ffmpeg: {error}")

    if finished.returncode != 0:
        # The technical details go to the server window, not to the user.
        logger.warning("ffmpeg failed: %s", finished.stderr.decode(errors="replace").strip()[-500:])
        raise AudioConversionError(
            "The recording couldn't be converted for pronunciation scoring. The file may be damaged."
        )
