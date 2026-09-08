import os
import sys
import json
import requests

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SAMPLE_IMAGE = os.path.join(BASE_DIR, "sample_craft.jpg")
SAMPLE_AUDIO = os.path.join(BASE_DIR, "sample_audio.wav")
API_BASE = "http://127.0.0.1:5000"

def test_enhance_image():
    print("\n=======================================================")
    print("TEST 1: POST /api/products/enhance-image")
    print("=======================================================")
    url = f"{API_BASE}/api/products/enhance-image"
    if not os.path.exists(SAMPLE_IMAGE):
        print(f"Error: {SAMPLE_IMAGE} not found")
        return None

    with open(SAMPLE_IMAGE, "rb") as f:
        files = {"image": ("sample_craft.jpg", f, "image/jpeg")}
        print(f"Uploading {SAMPLE_IMAGE} to {url}...")
        resp = requests.post(url, files=files, timeout=60)

    print(f"Status Code: {resp.status_code}")
    try:
        data = resp.json()
        print("Actual Output JSON:")
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return data
    except Exception as e:
        print(f"Response text: {resp.text}")
        return None

def test_voice_to_listing_sample():
    print("\n=======================================================")
    print("TEST 2: POST /api/catalog/voice-to-listing (Audio File)")
    print("=======================================================")
    url = f"{API_BASE}/api/catalog/voice-to-listing"
    if not os.path.exists(SAMPLE_AUDIO):
        print(f"Error: {SAMPLE_AUDIO} not found")
        return None

    with open(SAMPLE_AUDIO, "rb") as f:
        files = {"audio": ("sample_audio.wav", f, "audio/wav")}
        data = {"language": "hi"}
        print(f"Uploading {SAMPLE_AUDIO} (language=hi) to {url}...")
        resp = requests.post(url, files=files, data=data, timeout=60)

    print(f"Status Code: {resp.status_code}")
    try:
        res = resp.json()
        print("Actual Output JSON:")
        print(json.dumps(res, indent=2, ensure_ascii=False))
        return res
    except Exception as e:
        print(f"Response text: {resp.text}")
        return None

def test_voice_to_listing_artisan_transcript():
    print("\n=======================================================")
    print("TEST 3: POST /api/catalog/voice-to-listing (Spoken Artisan Voice Transcript)")
    print("=======================================================")
    url = f"{API_BASE}/api/catalog/voice-to-listing"
    payload = {
        "transcript": "यह शुद्ध लाल मिट्टी से बना पारंपरिक टेराकोटा कुल्हड़ और चाय सेट है, गोरखपुर के कारीगरों द्वारा चाक पर हाथ से बनाया गया",
        "language": "hi"
    }
    print(f"Testing with Hindi artisan spoken input: {payload['transcript']}")
    resp = requests.post(url, json=payload, timeout=60)

    print(f"Status Code: {resp.status_code}")
    try:
        res = resp.json()
        print("Actual Output JSON:")
        print(json.dumps(res, indent=2, ensure_ascii=False))
        return res
    except Exception as e:
        print(f"Response text: {resp.text}")
        return None

def test_error_handling():
    print("\n=======================================================")
    print("TEST 4: Friendly Error Handling (No file provided)")
    print("=======================================================")
    url = f"{API_BASE}/api/catalog/voice-to-listing"
    resp = requests.post(url, data={"language": "hi"}, timeout=30)
    print(f"Status Code: {resp.status_code}")
    try:
        res = resp.json()
        print("Friendly Error Output JSON:")
        print(json.dumps(res, indent=2, ensure_ascii=False))
    except Exception:
        print(resp.text)

if __name__ == "__main__":
    test_enhance_image()
    test_voice_to_listing_artisan_transcript()
    test_voice_to_listing_sample()
    test_error_handling()
