# VOICE_CATALOG_AUDIT — Recording Pipeline (Do Not Edit)

> HEAD `0a9b4e0 fix: repair Android voice recording pipeline` (2026-09-10) audited. Physical-device verification PENDING. This doc is read-only; no code changed.

## 1. Files in the pipeline

- Capture/UI: `frontend/lib/screens/artisan/voice_catalog_screen.dart:12-511` (`_audioRecorder:27`, `_startRecording:59`, `_stopAndProcessRecording:101`, `_showError:200`, lang dropdown `:305-320`, mic `:370-411`, one-tap test `:493-511`), `screens/artisan/photo_capture_screen.dart:9-262` (step 1 → pushes Voice with `imageUrl`), `screens/artisan/listing_review_screen.dart:23-933` (step 3 review/publish).
- Upload: `frontend/lib/services/ai_catalog_service.dart:6-133` (`voiceToListing:65` — mock `:71-89`, JSON transcript `:94-105`, multipart audio `:106-120`, 45s timeout `:117`).
- Platform path: `services/recording_file.dart:1` (conditional export), `recording_file_io.dart:4-32` (`kalavistar_voice_<micro>.wav` in `systemTemp`, delete-after-read), `recording_file_stub.dart:3-5` (web `''/null`).
- Backend: `backend/routes/catalog.py:54-130` (dual route `voice-to-listing` + alias `voice-to-catalog`, lang default `hi:62`, `<50B→400:78-83`, `transcribe_audio:86`, fail→422 `:91-103`, `process_voice_to_catalog:114`), `services/speech_service.py:1-230` (locale map `:41-49`, friendly errors `:53-79`, pydub→WAV `:82-140`, `recognize_google:190`), `services/ai_service.py:9-255` (Gemini `3.6-flash→3.5-flash-lite→1.5-flash:159`, JSON-only prompt `:134-156`, keyword fallback `:53-113`, translate backfill `:237-244`).
- Deps: `record:^7.1.1` (`pubspec.yaml:45`, no `permission_handler` — relies on `record.hasPermission()`); `AndroidManifest.xml:2` `RECORD_AUDIO` (added in HEAD); `SpeechRecognition+pydub+deep-translator+google-genai` (`requirements.txt:9-12`).
- Tests/fixtures: `test/recording_file_test.dart:8-20` (suffix + round-trip + cleanup), `backend/test_phase2_endpoints.py` (audio + transcript + 400 case), `create_test_assets.py`, `debug_speech.py`, `test_speech_fix.py`, `sample_audio.wav`, `test_hindi_speech.*`.

## 2. What HEAD fixed (verified `git show --stat HEAD`)

1. Added `RECORD_AUDIO` to `AndroidManifest.xml` — before, `hasPermission():62` could never succeed → dead mic.
2. Real temp path instead of `path:''` (`voice_catalog_screen.dart:70,79,123-131`) — before, `stop()` returned null/empty → `No audio bytes` abort.
3. New `recording_file_{io,stub}.dart` split — `io` temp WAV + delete-after-read; stub keeps web building without `dart:io`.
4. Removed silent fake-listing fallback (`catalog.py:91-103`) — STT failure now honest `422 {success:false, error, friendly_error}` instead of hardcoded kulhad transcript. Frontend gates on `result['success']==true:171` → `_showError:188`.
5. Added regression test for path/round-trip/cleanup.

## 3. End-to-end flow

`PhotoCapture → VoiceCatalog (WAV 16kHz mono, timer+static bars) → POST /api/catalog/voice-to-listing {language, audio|transcript} → transcribe (pydub→16kHz WAV→Google STT hi-IN etc.) → Gemini bilingual {title_en/hi, description_en/hi, category, key_features} → ListingReview (editable titles/descs/category/features + AI price card) → ProductProvider.addProduct → popUntil(isFirst)`.

## 4. Error behavior (good after HEAD)

Per-locale `friendly_error` at every layer (`speech_service.py:52-80`, `catalog.py:82,99,108,128`, `ai_catalog_service.dart:124,133`, `voice_catalog_screen.dart:66,97,163,188,195`); backend logs STT class + locale + size instead of swallowing; image step never blocks (sample-URL fallback `photo_capture_screen.dart:105-108`).

## 5. UX weaknesses (fixable without touching recording core)

- No transcript review/correction — `listing_review_screen.dart:307-333` banner is read-only italic; artisan can only rewrite title/desc. Violates AGENTS.md transcript-review intent.
- No waveform (7 static bars `:427-441`), timer only; no max-duration guard; no mid-record cancel.
- No permission rationale; denied → dead end (manual Settings).
- Language mismatch: voice UI offers hi/en/mr/ta; `LanguageProvider` has hi/en/gu/mr/bn/ta; STT map adds te/gu/bn. Gu/bn/te speakers have no correct path; no auto-detect.
- Retry weak: failed upload discards audio (file deleted on read); SnackBar + re-tap only.
- One-tap sample button always visible (`:493-511`) — judge may confuse with real mic.
- Business-assistant mic is **simulated** (`business_assistant_screen.dart:142` bottom-sheet chips) — expectation gap for low-literacy users.
- Timeout UX flat: 40–45s with single spinner text; no offline-vs-unclear-audio distinction in UI tone.

## 6. Remaining verification (owner must do on hardware)

1. Android device: fresh install → allow mic → 5s Hindi note → listing appears; deny path → rationale; airplane mode → friendly offline error; 30s record → no crash/OOM.
2. Emulator: `adb reverse tcp:5000 tcp:5000` + `baseUrl 127.0.0.1` vs `10.0.2.2` note (`api_config.dart:13-17`).
3. Backend: `test_phase2_endpoints.py` audio + transcript + empty-audio 400 + garbled-audio 422 (expect Hindi friendly string, no listing).
4. iOS (currently broken): add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist` (missing) before any iOS demo; note `Info.plist:9-18` still `Frontend` display name.
5. Check FFmpeg present for non-WAV uploads (`speech_service.py:13-38` winget path); confirm `sample_audio.wav` is synthetic (not real speech — `create_test_assets.py:49-64`).

## 7. Safe next steps (no recording-core edits)

- Editable transcript field in review screen (prefilled, resubmit → regenerate listing).
- Hide sample-test behind `kDebugMode` or long-press.
- Align language lists to 6 everywhere; persist choice via `LanguageProvider`.
- Add cancel + 60s cap + retry-keeps-audio (read bytes before delete, cache in memory on failure).
- Real STT for assistant OR remove mic icon until real.
