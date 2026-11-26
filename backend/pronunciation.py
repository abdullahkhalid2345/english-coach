"""
Pronunciation scoring using Azure Speech "pronunciation assessment".

This file has one job: given the recording and the words the student
meant to say (the Whisper transcript), score how well each word was
pronounced.

Unlike transcription and feedback, this step is allowed to fail: if Azure
isn't set up or has a problem, the student still gets their transcript
and grammar feedback. So the main function never raises an error; it
returns (result, None) on success or (None, "error message") on failure.
"""

import asyncio
import difflib
import json
import logging
import os
import string
import tempfile
import threading

from audio_convert import AudioConversionError, convert_to_azure_wav

logger = logging.getLogger(__name__)

LANGUAGE = "en-US"

# Words scoring below this are listed in "difficult_words".
DIFFICULT_WORD_THRESHOLD = 70

# Give up on Azure if it takes longer than this.
AZURE_TIMEOUT_SECONDS = 120


class PronunciationError(Exception):
    """Pronunciation scoring failed. The message is safe to show to the user."""


async def assess_pronunciation(audio_bytes: bytes, audio_format: str, reference_text: str):
    """
    Score the pronunciation of the recording.

    Returns (pronunciation_dict, None) if it worked,
    or (None, "a clear message") if it didn't.
    """
    key = os.getenv("AZURE_SPEECH_KEY")
    region = os.getenv("AZURE_SPEECH_REGION")
    if not key or not region:
        return None, (
            "Pronunciation scoring is turned off: AZURE_SPEECH_KEY and AZURE_SPEECH_REGION "
            "must both be set in backend/.env."
        )

    try:
        # The Azure library and ffmpeg are both "blocking" (they make the program
        # wait), so we run them in a separate thread. That way the server can
        # keep doing other work, like asking Claude for feedback, at the same time.
        result = await asyncio.to_thread(_convert_and_assess, audio_bytes, audio_format, reference_text, key, region)
        return result, None
    except (AudioConversionError, PronunciationError) as error:
        logger.warning("Pronunciation scoring failed: %s", error)
        return None, str(error)
    except Exception:  # anything unexpected: log the details, keep the request alive
        logger.exception("Unexpected error during pronunciation scoring")
        return None, "Pronunciation scoring failed because of an unexpected error. Check the server window for details."


def _convert_and_assess(audio_bytes, audio_format, reference_text, key, region) -> dict:
    """Save the upload to a temporary folder, convert it to WAV, and send it to Azure."""
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as folder:
        input_path = os.path.join(folder, f"upload.{audio_format}")
        wav_path = os.path.join(folder, "converted.wav")
        with open(input_path, "wb") as file:
            file.write(audio_bytes)

        convert_to_azure_wav(input_path, wav_path)
        segments = _run_azure(wav_path, reference_text, key, region)

    return _combine_segments(segments, reference_text)


def _run_azure(wav_path: str, reference_text: str, key: str, region: str) -> list[dict]:
    """
    Send the WAV file to Azure and collect the results.

    Azure splits a recording into "segments" (roughly, one per sentence or
    pause) and scores each one. We use "continuous" recognition so that
    recordings with pauses, or longer than 30 seconds, are scored in full.
    """
    # Imported here so the server still starts (with pronunciation turned off)
    # if the Azure package is missing.
    try:
        import azure.cognitiveservices.speech as speechsdk
    except ImportError:
        raise PronunciationError(
            "The Azure Speech package isn't installed. Run: pip install -r requirements.txt"
        )

    speech_config = speechsdk.SpeechConfig(subscription=key, region=region)
    speech_config.speech_recognition_language = LANGUAGE
    audio_config = speechsdk.audio.AudioConfig(filename=wav_path)

    assessment_config = speechsdk.PronunciationAssessmentConfig(
        reference_text=reference_text,
        grading_system=speechsdk.PronunciationAssessmentGradingSystem.HundredMark,
        granularity=speechsdk.PronunciationAssessmentGranularity.Word,
        enable_miscue=True,  # notice skipped or extra words
    )
    # Prosody = rhythm, stress and intonation (how natural it sounds).
    if hasattr(assessment_config, "enable_prosody_assessment"):
        assessment_config.enable_prosody_assessment()

    recognizer = speechsdk.SpeechRecognizer(speech_config=speech_config, audio_config=audio_config)
    assessment_config.apply_to(recognizer)

    segments: list[dict] = []
    problems: list[str] = []
    finished = threading.Event()

    def on_recognized(event):
        if event.result.reason != speechsdk.ResultReason.RecognizedSpeech:
            return
        scores = speechsdk.PronunciationAssessmentResult(event.result)
        # The total speaking time of this segment, used to weigh the fluency score.
        raw = json.loads(event.result.properties.get(speechsdk.PropertyId.SpeechServiceResponse_JsonResult) or "{}")
        best = (raw.get("NBest") or [{}])[0]
        duration = sum(int(word.get("Duration", 0)) for word in best.get("Words", []))
        segments.append({
            "accuracy": scores.accuracy_score,
            "fluency": scores.fluency_score,
            "prosody": getattr(scores, "prosody_score", None),
            "duration": duration,
            "words": [
                {"word": word.word, "accuracy_score": word.accuracy_score, "error_type": word.error_type}
                for word in scores.words
            ],
        })

    def on_canceled(event):
        details = event.result.cancellation_details
        if details.reason == speechsdk.CancellationReason.Error:
            problems.append(_explain_azure_error(details.error_details or ""))
        finished.set()

    recognizer.recognized.connect(on_recognized)
    recognizer.canceled.connect(on_canceled)
    recognizer.session_stopped.connect(lambda event: finished.set())

    recognizer.start_continuous_recognition()
    completed_in_time = finished.wait(timeout=AZURE_TIMEOUT_SECONDS)
    recognizer.stop_continuous_recognition()
    # Let go of the WAV file so the temporary folder can be deleted (matters on Windows).
    del recognizer, audio_config

    if problems:
        raise PronunciationError(problems[0])
    if not completed_in_time:
        raise PronunciationError(f"Azure took longer than {AZURE_TIMEOUT_SECONDS} seconds, so we stopped waiting.")
    if not segments:
        raise PronunciationError("Azure couldn't hear any clear speech in the recording to score.")
    return segments


def _explain_azure_error(details: str) -> str:
    """Turn Azure's technical error text into a clear message."""
    lowered = details.lower()
    if "401" in lowered or "authentication" in lowered or "unauthorized" in lowered:
        return "Azure rejected the key. Check AZURE_SPEECH_KEY and AZURE_SPEECH_REGION in backend/.env."
    if "429" in lowered or "quota" in lowered or "throttl" in lowered:
        return "Azure says we've used too much (free-tier limit or too many requests). Try again later."
    if "connection" in lowered or "resolve" in lowered or "network" in lowered or "1006" in lowered:
        return (
            "Could not reach Azure. Check the internet connection, and that AZURE_SPEECH_REGION "
            "(e.g. eastus) matches the region of your Azure Speech resource."
        )
    return f"Azure Speech had a problem: {details[:300]}"


def _split_into_words(text: str) -> list[str]:
    """'Hello, World!' -> ['hello', 'world']"""
    words = (word.strip(string.punctuation).lower() for word in text.split())
    return [word for word in words if word]


def _combine_segments(segments: list[dict], reference_text: str) -> dict:
    """
    Combine Azure's per-segment results into one set of scores.

    This follows Microsoft's own sample code for long recordings: in
    continuous mode Azure doesn't report skipped or extra words, so we line
    up what Azure heard against the reference text ourselves.
    """
    heard_words = [word for segment in segments for word in segment["words"]]
    reference_words = _split_into_words(reference_text)

    # Line up the reference words and the heard words to find skipped
    # ("Omission") and extra ("Insertion") words.
    matcher = difflib.SequenceMatcher(None, reference_words, [w["word"].lower() for w in heard_words])
    words = []
    for tag, ref_start, ref_end, heard_start, heard_end in matcher.get_opcodes():
        if tag == "equal":
            words.extend(heard_words[heard_start:heard_end])
        if tag in ("insert", "replace"):
            for word in heard_words[heard_start:heard_end]:
                if word["error_type"] == "None":
                    word = {**word, "error_type": "Insertion"}
                words.append(word)
        if tag in ("delete", "replace"):
            for skipped in reference_words[ref_start:ref_end]:
                words.append({"word": skipped, "accuracy_score": 0, "error_type": "Omission"})

    # Accuracy: average of all words the student was meant to say.
    scored = [w["accuracy_score"] for w in words if w["error_type"] != "Insertion"]
    accuracy = sum(scored) / len(scored) if scored else 0

    # Fluency: average of the segments, giving longer segments more weight.
    total_duration = sum(s["duration"] for s in segments)
    if total_duration:
        fluency = sum(s["fluency"] * s["duration"] for s in segments) / total_duration
    else:
        fluency = sum(s["fluency"] for s in segments) / len(segments)

    # Completeness: what share of the words the student meant to say were
    # actually said (even if mispronounced). Skipped words lower it.
    said = len([w for w in words if w["error_type"] not in ("Omission", "Insertion")])
    completeness = min(100.0, said / len(reference_words) * 100) if reference_words else 0

    # Prosody: average of the segments (only if Azure returned it).
    prosody_values = [s["prosody"] for s in segments if s["prosody"] is not None]
    prosody = sum(prosody_values) / len(prosody_values) if prosody_values else None

    # Overall: Microsoft's formula. The weakest score counts most (40%),
    # the others 20% each. Without prosody, the other two get 30% each.
    parts = sorted(score for score in (accuracy, fluency, completeness, prosody) if score is not None)
    if len(parts) == 4:
        overall = parts[0] * 0.4 + parts[1] * 0.2 + parts[2] * 0.2 + parts[3] * 0.2
    else:
        overall = parts[0] * 0.4 + parts[1] * 0.3 + parts[2] * 0.3

    # Words the student said but found hard. Skipped words (Omission) and
    # extra words like "uh" (Insertion) are left out.
    difficult_words = [
        w for w in words
        if w["error_type"] not in ("Omission", "Insertion")
        and w["accuracy_score"] is not None
        and w["accuracy_score"] < DIFFICULT_WORD_THRESHOLD
    ]

    return {
        "accuracy_score": round(accuracy, 1),
        "fluency_score": round(fluency, 1),
        "completeness_score": round(completeness, 1),
        "prosody_score": round(prosody, 1) if prosody is not None else None,
        "overall_score": round(overall, 1),
        "words": words,
        "difficult_words": difficult_words,
    }
