# -*- coding: utf-8 -*-
"""
Generate a real Hindi TTS MP3 file and test the fixed speech pipeline.
"""
import os
import sys
import io
import logging

sys.stdout.reconfigure(encoding='utf-8')
logging.basicConfig(level=logging.DEBUG, format="%(levelname)s | %(name)s | %(message)s")

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MP3_PATH = os.path.join(BASE_DIR, "test_hindi_speech.mp3")

# ---------------------------------------------------------------------------
# Step 1: Generate real Hindi TTS MP3 using gTTS
# ---------------------------------------------------------------------------
print("=" * 60)
print("STEP 1: Generating Hindi TTS MP3 file...")
print("=" * 60)

HINDI_TEXT = "यह एक हाथ से बना हुआ मिट्टी का कुल्हड़ है जो गोरखपुर से आता है"

from gtts import gTTS
tts = gTTS(text=HINDI_TEXT, lang='hi', slow=False)
tts.save(MP3_PATH)
mp3_size = os.path.getsize(MP3_PATH)
print(f"Created: {MP3_PATH}")
print(f"Size: {mp3_size} bytes")
print(f"Text: {HINDI_TEXT}")

with open(MP3_PATH, "rb") as f:
    header = f.read(4)
print(f"First 4 bytes: {header} (starts with RIFF? {header == b'RIFF'})")

# ---------------------------------------------------------------------------
# Step 2: Test the FIXED speech_service.transcribe_audio with the MP3
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("STEP 2: Testing fixed transcribe_audio with MP3...")
print("=" * 60)

sys.path.insert(0, BASE_DIR)
from services.speech_service import transcribe_audio

with open(MP3_PATH, "rb") as f:
    mp3_bytes = f.read()

result = transcribe_audio(mp3_bytes, filename="test_hindi_speech.mp3", lang_code="hi")
print(f"\nResult: {result}")

if result.get("success"):
    print(f"\n>>> SUCCESS! Transcript: '{result['transcript']}'")
else:
    print(f"\n>>> FAILED: {result.get('error')}")

# ---------------------------------------------------------------------------
# Step 3: Also test the WAV endpoint directly (convert MP3 to WAV first)
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("STEP 3: Testing with WAV converted from the same TTS...")
print("=" * 60)

try:
    from pydub import AudioSegment
    audio = AudioSegment.from_mp3(MP3_PATH)
    wav_path = os.path.join(BASE_DIR, "test_hindi_speech.wav")
    audio = audio.set_channels(1).set_sample_width(2).set_frame_rate(16000)
    audio.export(wav_path, format="wav")
    print(f"Converted to WAV: {wav_path} ({os.path.getsize(wav_path)} bytes)")

    with open(wav_path, "rb") as f:
        wav_bytes = f.read()

    result2 = transcribe_audio(wav_bytes, filename="test_hindi_speech.wav", lang_code="hi")
    print(f"\nResult: {result2}")

    if result2.get("success"):
        print(f"\n>>> SUCCESS! Transcript: '{result2['transcript']}'")
    else:
        print(f"\n>>> FAILED: {result2.get('error')}")
except Exception as e:
    print(f"WAV test error: {e}")

print("\n" + "=" * 60)
print("TEST COMPLETE")
print("=" * 60)
