"""
Speaking feedback using Claude (Anthropic).

This file has one job: take the transcript of what the student said and
ask Claude for grammar corrections, a better version, a filler-word count,
a grammar score and tips. The wording of the instructions lives in
prompts.py so it's easy to edit.
"""

import json
import logging
import os

import anthropic
from fastapi import HTTPException
from pydantic import BaseModel, ValidationError, field_validator

from prompts import COACH_SYSTEM_PROMPT, build_user_message

logger = logging.getLogger(__name__)

DEFAULT_CLAUDE_MODEL = "claude-sonnet-5-5"

# How many times we ask Claude in total if the answer comes back broken:
# the first try plus one retry.
MAX_ATTEMPTS = 2

# These models support Anthropic's automatic "fallback": if the model
# declines a request, Anthropic quietly re-runs it on a backup model in
# the same call, so the student still gets feedback.
MODELS_WITH_FALLBACK = {
    "claude-sonnet-5-5",
    "claude-opus-5-5",
    "claude-opus-5",
    "claude-fable-5-1",
    "claude-fable-5-2",
}


# ---------------------------------------------------------------------------
# The shape of the answer we expect from Claude.
# Pydantic checks Claude's answer matches this shape exactly.
# ---------------------------------------------------------------------------

class Correction(BaseModel):
    original: str
    corrected: str
    explanation: str


class SpeakingFeedback(BaseModel):
    corrections: list[Correction]
    better_version: str
    filler_words: int
    grammar_score: int
    tips: list[str]

    @field_validator("filler_words")
    @classmethod
    def filler_words_not_negative(cls, value: int) -> int:
        if value < 0:
            raise ValueError("filler_words cannot be negative")
        return value

    @field_validator("grammar_score")
    @classmethod
    def score_in_range(cls, value: int) -> int:
        if not 0 <= value <= 100:
            raise ValueError("grammar_score must be between 0 and 100")
        return value

    @field_validator("tips")
    @classmethod
    def at_most_three_tips(cls, value: list[str]) -> list[str]:
        if not value:
            raise ValueError("expected 2 or 3 tips, got none")
        return value[:3]  # if Claude gives more than 3, keep the first 3


# The same shape written as a "JSON schema". We send this to Claude so
# its reply is forced to follow it (Anthropic calls this "structured outputs").
FEEDBACK_JSON_SCHEMA = {
    "type": "object",
    "properties": {
        "corrections": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "original": {"type": "string"},
                    "corrected": {"type": "string"},
                    "explanation": {"type": "string"},
                },
                "required": ["original", "corrected", "explanation"],
                "additionalProperties": False,
            },
        },
        "better_version": {"type": "string"},
        "filler_words": {"type": "integer"},
        "grammar_score": {"type": "integer"},
        "tips": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["corrections", "better_version", "filler_words", "grammar_score", "tips"],
    "additionalProperties": False,
}


class BrokenAnswerError(Exception):
    """Claude's reply wasn't the JSON we asked for."""


def _parse_feedback(response) -> SpeakingFeedback:
    """Turn Claude's reply into SpeakingFeedback, or raise BrokenAnswerError."""
    if response.stop_reason == "refusal":
        raise HTTPException(
            status_code=422,
            detail="Claude declined to give feedback on this recording. Try recording something different.",
        )
    if response.stop_reason == "max_tokens":
        raise BrokenAnswerError("the reply was cut off because it was too long")

    text = "".join(block.text for block in response.content if block.type == "text")
    try:
        data = json.loads(text)
        return SpeakingFeedback.model_validate(data)
    except (json.JSONDecodeError, ValidationError) as error:
        raise BrokenAnswerError(str(error)) from error


async def get_speaking_feedback(transcript: str) -> dict:
    """Ask Claude for feedback on the transcript. Returns a plain dict."""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="ANTHROPIC_API_KEY is missing. Add it to the backend/.env file and restart the server.",
        )
    model = os.getenv("CLAUDE_MODEL") or DEFAULT_CLAUDE_MODEL

    client = anthropic.AsyncAnthropic(api_key=api_key)

    request = {
        "model": model,
        "max_tokens": 16000,
        "system": COACH_SYSTEM_PROMPT,
        "messages": [{"role": "user", "content": build_user_message(transcript)}],
        "output_config": {
            # "medium" thinking effort: careful enough for grammar, but quick and cheap.
            "effort": "medium",
            # Force the reply to be JSON in exactly our shape.
            "format": {"type": "json_schema", "schema": FEEDBACK_JSON_SCHEMA},
        },
    }
    if model in MODELS_WITH_FALLBACK:
        request["betas"] = ["server-side-fallback-2026-07-01"]
        request["fallbacks"] = "default"

    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            response = await client.beta.messages.create(**request)
        except anthropic.AuthenticationError:
            raise HTTPException(
                status_code=500,
                detail="Anthropic rejected the API key. Check ANTHROPIC_API_KEY in backend/.env.",
            )
        except anthropic.PermissionDeniedError:
            raise HTTPException(
                status_code=500,
                detail="This Anthropic API key isn't allowed to do this. Check your Anthropic account settings.",
            )
        except anthropic.NotFoundError:
            raise HTTPException(
                status_code=500,
                detail=f"Anthropic doesn't recognise the model '{model}'. Check CLAUDE_MODEL in backend/.env.",
            )
        except anthropic.RateLimitError:
            raise HTTPException(
                status_code=429,
                detail="Anthropic says we've sent too many requests. Wait a minute and try again.",
            )
        except anthropic.BadRequestError as error:
            raise HTTPException(
                status_code=502,
                detail=f"Anthropic rejected the request (is your account out of credit?): {error.message}",
            )
        except anthropic.APIConnectionError:
            raise HTTPException(
                status_code=502,
                detail="Could not reach Anthropic. Check the internet connection and try again.",
            )
        except anthropic.APIStatusError as error:
            raise HTTPException(
                status_code=502,
                detail=f"Anthropic had a problem ({error.status_code}). Try again in a moment.",
            )

        try:
            feedback = _parse_feedback(response)
            return feedback.model_dump()
        except BrokenAnswerError as problem:
            # The technical details go to the server window, not to the user.
            logger.warning("Claude returned unusable feedback (attempt %d): %s", attempt, problem)

    raise HTTPException(
        status_code=502,
        detail="Claude's feedback came back in the wrong format twice, so we gave up. Please try again.",
    )
