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

## Current status: Step 1

The backend runs, but the `/analyze` endpoint returns **fake (dummy) results**.
No AI services are called yet. This lets us build and test the phone app first.

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

1. Make a copy of `.env.example` and name the copy `.env` (in the `backend` folder).
2. Open `.env` and paste your keys after the `=` signs.

You can leave them empty for now — the dummy version works without them.
The `.env` file is listed in `.gitignore`, so it will **never** be uploaded to GitHub.

### 6. Start the server

```bash
uvicorn main:app --reload
```

You should see `Uvicorn running on http://127.0.0.1:8000`. Leave this window open.
(`--reload` means the server restarts automatically when you edit the code.) Press `Ctrl+C` to stop it.

### 7. Try it out

Open http://127.0.0.1:8000/docs in your web browser. This is a free test page FastAPI makes for you:

1. Click **POST /analyze** → **Try it out**.
2. Choose any audio file (e.g. an `.m4a` or `.wav` voice recording).
3. Click **Execute**. You'll see the dummy feedback below.

Also try http://127.0.0.1:8000/ — it says `"status": "ok"` and shows which keys were found (true/false — never the keys themselves).

---

## Endpoints

| Method | Address | What it does |
|---|---|---|
| GET | `/` | Health check — is the server alive, which keys are loaded. |
| POST | `/analyze` | Send an audio file (form field name: `audio`). Returns feedback (dummy for now). |
