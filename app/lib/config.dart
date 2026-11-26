// =============================================================================
// APP SETTINGS: the only file you should need to change to connect the app
// to your backend.
// =============================================================================

/// The address of your FastAPI backend (no "/" at the end).
///
/// Which address to use:
/// - **Real phone on the same Wi-Fi as your laptop:** use your laptop's IP
///   address, e.g. "http://192.168.1.23:8000". See "Find your laptop's IP
///   address" in the README.
/// - **Android emulator on your laptop:** use "http://10.0.2.2:8000"
///   (10.0.2.2 is the emulator's special name for "the computer I'm running on").
/// - "http://127.0.0.1:8000" does NOT work from a phone: on a phone,
///   127.0.0.1 means "this phone", not your laptop.
///
/// Remember to start the backend with `--host 0.0.0.0` so other devices
/// can reach it (see the README).
const String backendUrl = 'http://192.168.1.23:8000';

/// The longest a recording can be. The recording stops by itself after this.
const int maxRecordingSeconds = 120;

/// Recordings shorter than this are too short to give useful feedback.
const int minRecordingSeconds = 2;

/// How long to wait for the backend before giving up. Transcribing,
/// grammar feedback and pronunciation scoring together can take a while.
const Duration requestTimeout = Duration(seconds: 120);
