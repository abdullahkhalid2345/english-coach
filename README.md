# English Coach

An AI English speaking coach. You record yourself speaking, and the app tells you:

- what you said (speech-to-text with OpenAI Whisper),
- how to fix your grammar and say it better (Claude),
- how good your pronunciation was (Azure Speech).

Then you try again and see if you improved.

## Folders

| Folder | What it is |
|---|---|
| `backend/` | The "brain" that runs on a computer/server (Python + FastAPI). |
| `app/` | The phone app (Flutter). *Coming in a later step.* |

## Current status: Step 3

- ✅ **Speech-to-text is real.** `/analyze` sends your recording to OpenAI Whisper and returns what you said.
- ✅ **Speaking feedback is real.** Claude corrects your grammar, rewrites your answer in natural English,
  counts filler words ("um", "like"...), gives a grammar score and 2–3 tips.
- ⏳ **Pronunciation scores are still fake (dummy) data.** They will become real in the next step (Azure).

## Files in `backend/`

| File | What it does |
|---|---|
| `main.py` | The server. Receives the recording and puts all the results together. |
| `transcription.py` | Speech → text, using OpenAI Whisper. |
| `feedback.py` | Text → grammar feedback, using Claude. |
| `prompts.py` | **The instructions given to Claude.** Edit this to change the coach's tone or rules. |
| `requirements.txt` | The list of tools to install. |
| `.env.example` | Template for your secret keys. |

---

## How to run the backend (step by step)

### 1. Install Python

Download Python 3.10 or newer from https://www.python.org/downloads/.
On Windows, tick **"Add Python to PATH"** during installation.

Check it worked by opening a terminal (Mac: "Terminal", Windows: "Command Prompt") and typing:

```bash
python --version
```

(On Mac you may need to type `python3` instead of `python` everywhere below.)

### 2. Go into the backend folder

```bash
cd path/to/english-coach/backend
```

### 3. Create a "virtual environment" (a private box for this project's tools)

```bash
python -m venv venv
```

Turn it on:

- **Mac / Linux:** `source venv/bin/activate`
- **Windows:** `venv\Scripts\activate`

You'll see `(venv)` at the start of the line. Do this "turn it on" step every time you open a new terminal.

### 4. Install the tools the backend needs

```bash
pip install -r requirements.txt
```

### 5. Add your secret keys

You need two keys for now:

- **OpenAI** (speech-to-text): https://platform.openai.com/api-keys. Add a little credit to your OpenAI
  account; Whisper costs about $0.006 per minute of audio.
- **Anthropic** (Claude feedback): https://console.anthropic.com/settings/keys. Add a little credit to your
  Anthropic account too; one piece of feedback costs well under one US cent.

Then:

1. Make a copy of `.env.example` and name the copy `.env` (in the `backend` folder).
2. Open `.env` and replace the fake `OPENAI_API_KEY` and `ANTHROPIC_API_KEY` values with your real keys.
   It should look like:

   ```
   OPENAI_API_KEY=sk-proj-abc123...
   ANTHROPIC_API_KEY=sk-ant-abc123...
   CLAUDE_MODEL=claude-sonnet-5-5
   ```

   No spaces and no quotes. Leave the Azure lines as they are for now.
   `CLAUDE_MODEL` chooses which Claude model gives the feedback; `claude-sonnet-5-5` is a good default.

The `.env` file is listed in `.gitignore`, so it will **never** be uploaded to GitHub.
If you change `.env` while the server is running, stop it (`Ctrl+C`) and start it again.

### 6. Start the server

```bash
uvicorn main:app --reload
```

You should see `Uvicorn running on http://127.0.0.1:8000`. Leave this window open.
(`--reload` means the server restarts automatically when you edit the code.) Press `Ctrl+C` to stop it.

### 7. Check the server found your keys

Open http://127.0.0.1:8000/ in your browser. You should see `"openai": true` and `"anthropic": true`.
If one says `false`, the `.env` file is in the wrong folder, is named wrongly (e.g. `.env.txt`), or the key is empty.

### 8. Test with a sample audio file

**Get a recording.** Use your phone's voice recorder app and say a sentence in English,
e.g. *"Yesterday I go to the market and buyed some apples."* Send the file to your computer
(email, AirDrop, Google Drive…). Accepted formats: **m4a, mp3, wav, webm**, plus ogg, flac and mp4. Max 25 MB.

**Option A – in the browser (easiest):**

1. Open http://127.0.0.1:8000/docs.
2. Click **POST /analyze** → **Try it out**.
3. Next to `audio`, click **Choose File** and pick your recording.
4. Click **Execute** and scroll down to **Response body**.

**Option B – from a terminal** (open a *second* terminal; the server must keep running in the first):

```bash
curl -F "audio=@/path/to/your/recording.m4a" http://127.0.0.1:8000/analyze
```

**What you should get back** (it takes a few seconds; everything is real except `pronunciation`):

```json
{
  "file_name": "recording.m4a",
  "file_size_bytes": 48213,
  "transcript": "Um, yesterday I go to the market and buyed some apples.",
  "duration_seconds": 3.8,
  "corrections": [
    {
      "original": "I go",
      "corrected": "I went",
      "explanation": "Use the past tense because you are talking about yesterday."
    },
    {
      "original": "buyed",
      "corrected": "bought",
      "explanation": "\"Buy\" is irregular: the past tense is \"bought\"."
    }
  ],
  "better_version": "Yesterday I went to the market and bought some apples.",
  "filler_words": 1,
  "grammar_score": 65,
  "tips": [
    "When you talk about the past, check that every verb is in the past tense.",
    "Learn the common irregular verbs like buy → bought and go → went.",
    "Try pausing silently instead of saying \"um\"."
  ],
  "pronunciation": {"overall_score": 82, "...": "..."},
  "dummy_fields": ["pronunciation"]
}
```

`dummy_fields` lists the parts that are still fake, so the app knows not to trust them yet.
Claude's exact words will be different every time.

### Changing how the coach talks

Open `backend/prompts.py`. It contains, in plain English, the instructions Claude follows: be friendly,
ignore punctuation, keep explanations to one simple sentence, how to score, and so on. Change the wording,
save, and the server restarts by itself (thanks to `--reload`). Keep the five field names the same,
because the code reads them.

### If something goes wrong

Instead of crashing, the server replies with a `detail` message telling you what happened:

| Message starts with… | What to do |
|---|---|
| `OPENAI_API_KEY is missing` / `ANTHROPIC_API_KEY is missing` | Add the key to `backend/.env` and restart the server. |
| `OpenAI rejected the API key` / `Anthropic rejected the API key` | The key is wrong or was deleted. Make a new one and paste it in again. |
| `Anthropic doesn't recognise the model` | Check the spelling of `CLAUDE_MODEL` in `.env` (or delete that line to use the default). |
| `We couldn't hear any speech` | The recording was silent or too quiet. Record again closer to the microphone. |
| `came back in the wrong format twice` | Rare. Claude's answer was garbled twice in a row. Just try again. |
| `Claude declined to give feedback` | Claude wouldn't comment on what was said. Record something different. |
| `Unsupported audio format` | Send an m4a, mp3, wav or webm file. |
| `The audio file is empty` / `too big` | Record again; keep it under 25 MB. |
| `OpenAI could not read this audio file` | The file is broken or isn't really audio. Try another recording. |
| `too many requests` / `no credit` / `out of credit` | Wait a minute, or add credit to your OpenAI or Anthropic account. |
| `Could not reach OpenAI` / `Could not reach Anthropic` | Check your internet connection. |

---

## Endpoints

| Method | Address | What it does |
|---|---|---|
| GET | `/` | Health check — is the server alive, which keys are loaded. |
| POST | `/analyze` | Send an audio file (form field name: `audio`). Returns the transcript, its length and Claude's feedback, plus dummy pronunciation scores. |
