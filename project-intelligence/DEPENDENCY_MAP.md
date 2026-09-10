# DEPENDENCY_MAP — What a New Dev Actually Needs to Run This

> Verified from `pubspec.yaml`, `requirements.txt`, `app.py:7-26`, `config.py`, `.env.example`, `firebase_options.dart`, `config/api_config.dart`, `services/speech_service.py:13-38`, `services/image_service.py`, `test_phase*.py`. Secrets never opened (`.env`, `serviceAccountKey.json` existence only).

## 1. Flutter (frontend/)

- SDK: Dart `^3.13.2` (`pubspec.yaml:22`), `flutter pub get`, `flutter run -d chrome` (web, no mic file path — uses blob stub) or `flutter run` (USB Android).
- Deps (`pubspec.yaml:38-49`): `provider`, `firebase_core/auth/firestore/storage`, `http`, `image_picker`, `record`, `qr_flutter`, `fl_chart`, `share_plus`, `shared_preferences`. Note: `firebase_storage` declared but unused in `lib/` — do not remove (additive asset work may use it).
- Firebase: `lib/firebase_options.dart` already points to `shilpsetu-37bcd` (works as-is if project still live); else replace via FlutterFire CLI. `google-services.json` / `GoogleService-Info.plist` must match `applicationId com.shilpsetu.frontend` (`build.gradle.kts:19`).
- Backend address — THE #1 GOTCHA: `lib/config/api_config.dart:14 baseUrl=http://127.0.0.1:5000` works for **desktop Chrome + iOS simulator only**.
  - Android emulator: uncomment `http://10.0.2.2:5000` (`:17`) OR `adb reverse tcp:5000 tcp:5000` then keep `127.0.0.1`.
  - Physical Android + laptop same Wi-Fi: set `baseUrl=http://<LAPTOP_LAN_IP>:5000` (e.g. `192.168.1.x`), keep Flask `host=0.0.0.0` (`app.py:70`), allow firewall.
  - `useMock=false` (`:10`) — mocks dormant; empty DB means empty UI (seed first).

## 2. Flask (backend/)

- Python 3.10+ recommended; `cd backend; pip install -r requirements.txt; python app.py` → `http://127.0.0.1:5000/api/health → {"status":"ok"}` (`routes/health.py:5-12`).
- `requirements.txt:1-15`: `flask, flask-cors, python-dotenv, firebase-admin, rembg, opencv-headless, pillow, numpy, SpeechRecognition, deep-translator, google-genai, pydub, scikit-learn, pandas, joblib`. Heavy: `rembg` downloads `u2netp` ONNX on first enhance (~170MB); `opencv-headless` avoids GUI deps.
- Missing from requirements (install manually for tests): `requests` (all `test_phase*.py`), `gTTS` (`test_speech_fix.py:25`). Add only to a test-requirements file later — do not touch runtime file in this phase.
- Env (`backend/.env`, template `.env.example:1-10`): `PORT=5000`, `FLASK_ENV=development`, `GEMINI_API_KEY` (or `GOOGLE_API_KEY` — code checks both `app.py:19`), `FIREBASE_STORAGE_BUCKET` (e.g. `shilpsetu-artisan.appspot.com`). Note: `FIREBASE_CREDENTIALS_PATH` in example is **ignored** — code hardcodes `config.py:7-8 serviceAccountKey.json` in `backend/`.
- Firebase key: real `serviceAccountKey.json` present on this machine (untracked? verify `git status`); placeholder at `serviceAccountKey.json.placeholder:1-13`. Without key, `firebase_service.py:11-49` logs + returns `None` → all routes serve mock/fallback (demo still runs, writes fail with 500 `no DB`).
- Startup log tells truth: `[STARTUP] GEMINI_API_KEY loaded: abcd...wxyz` vs `NOT SET → fallback modes` (`app.py:18-26`). No key = keyword listings, regex RFQ, template captions, heuristic prices — still demoable.

## 3. AI / media system deps

- Gemini: one key in `.env`; models tried in order — listing `3.6-flash→3.5-flash-lite→1.5-flash` (`ai_service.py:159`), RFQ `2.0-flash` (`rfq.py:77`), assistant `2.5-flash→1.5-flash` (`assistant_service.py:316`), promo `2.5-flash` (`promo.py:72`), image `2.5-flash-image→3.1-flash-image→3-pro-image→3.1-flash-lite-image` (`image_service.py:220-225`). Quota error on one → falls through, not crash.
- FFmpeg (REQUIRED for non-WAV voice): `speech_service.py:13-38` checks PATH then winget `Gyan.FFmpeg...ffmpeg-9.0.1-full_build\bin`, injects PATH. Install: `winget install Gyan.FFmpeg` (Windows) / `brew install ffmpeg` (macOS) / `apt install ffmpeg` (Linux). WAV 16kHz mono from app bypasses conversion; MP3/M4A/WEBM need it.
- rembg/ONNX + OpenCV: first `POST /api/products/enhance-image` is slow (model fetch); subsequent ~seconds. `static/enhanced/` auto-created (`app.py:39`).

## 4. Runbook (copy-paste)

```bash
# 1. Backend
cd backend
pip install -r requirements.txt
# ensure backend/.env has GEMINI_API_KEY=... ; serviceAccountKey.json present
python app.py
# expect [STARTUP] GEMINI_API_KEY loaded + Serving on 0.0.0.0:5000
curl http://127.0.0.1:5000/api/health   # {"status":"ok"}

# 2. Seed demo catalog (after IMPLEMENTATION_ROADMAP Phase 1 script lands)
python seed_demo_catalog.py              # expect 24 products, per-category counts
curl "http://127.0.0.1:5000/api/products/search?limit=5"

# 3. Frontend (new terminal)
cd frontend
flutter pub get
flutter run -d chrome                    # web demo (no mic file test)
# Android emulator: adb reverse tcp:5000 tcp:5000  OR  switch api_config.dart to 10.0.2.2
flutter run                              # device/emulator

# 4. Voice check (no hardware needed)
cd backend
python test_phase2_endpoints.py          # enhance + voice transcript + 400 case
python test_speech_fix.py                # Hindi TTS → transcribe path
```

## 5. Hidden traps that already cost time

- `127.0.0.1` vs `10.0.2.2` vs LAN IP (see §1) — decide per target before reporting "backend unreachable".
- `FIREBASE_CREDENTIALS_PATH` env name does nothing; file must literally be `backend/serviceAccountKey.json`.
- `firebase_options.dart` same key copy-pasted for all platforms + defaults to `web` on Linux/macOS — desktop test auth may behave as web.
- Synthetic `sample_audio.wav` is harmonic tone, not speech (`create_test_assets.py:49-64`) — STT failure on it is expected, not a bug; use `test_hindi_speech.wav` for real STT proof.
- `pubspec.lock` + generated `linux/macos/windows/flutter/*` show as modified in `git status` — build artifacts, ignore.
