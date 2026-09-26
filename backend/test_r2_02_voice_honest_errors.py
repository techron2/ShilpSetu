"""R2-02 regression: honest STT errors for /api/catalog/voice-to-listing.

Hermetic Flask test-client tests (no network/STT/ffmpeg):
- direct transcript still succeeds with AI processing mocked
- STT success uses the actual returned transcript
- STT failure does NOT inject hardcoded terracotta fallback
- STT failure returns 422 with machine error + friendly_error
- empty/corrupt audio remains rejected (400)
"""
import io
import os
import sys
from unittest.mock import patch

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from app import create_app  # noqa: E402

TERRACOTTA_MARKERS = [
    "टेराकोटा कुल्हड़",
    "टेराकोटा कुल्हड",
    "terracotta clay kulhad",
    "गोरखपुर",
]


def _client():
    app = create_app()
    app.config.update(TESTING=True)
    return app.test_client()


def test_direct_transcript_succeeds():
    client = _client()
    fake_ai = {
        "success": True,
        "transcript": "handmade cotton saree",
        "title_en": "Handmade Cotton Saree",
        "title_hi": "हस्तनिर्मित सूती साड़ी",
        "description_en": "desc en",
        "description_hi": "desc hi",
        "category": "Textiles",
        "key_features": ["handloom"],
    }
    with patch("services.ai_service.process_voice_to_catalog", return_value=fake_ai) as mock_ai:
        resp = client.post(
            "/api/catalog/voice-to-listing",
            json={"transcript": "handmade cotton saree", "language": "en"},
        )
        assert resp.status_code == 200, resp.get_data(as_text=True)
        data = resp.get_json()
        assert data["success"] is True
        mock_ai.assert_called_once()
        called_transcript = mock_ai.call_args[0][0]
        assert called_transcript == "handmade cotton saree"


def test_stt_success_uses_real_transcript():
    client = _client()
    real_transcript = "real spoken blue pottery vase from Jaipur"
    with patch(
        "services.speech_service.transcribe_audio",
        return_value={"success": True, "transcript": real_transcript, "error": None},
    ), patch(
        "services.ai_service.process_voice_to_catalog",
        return_value={"success": True, "transcript": real_transcript, "title_en": "t",
                      "title_hi": "t", "description_en": "d", "description_hi": "d",
                      "category": "Pottery", "key_features": []},
    ) as mock_ai:
        payload = b"RIFF" + b"\x00" * 200  # >50 bytes so route accepts it
        resp = client.post(
            "/api/catalog/voice-to-listing",
            data={"language": "en", "audio": (io.BytesIO(payload), "voice.wav")},
            content_type="multipart/form-data",
        )
        assert resp.status_code == 200, resp.get_data(as_text=True)
        mock_ai.assert_called_once()
        assert mock_ai.call_args[0][0] == real_transcript
        body = resp.get_data(as_text=True)
        for marker in TERRACOTTA_MARKERS:
            assert marker not in body


def test_stt_failure_returns_422_without_fallback():
    client = _client()
    with patch(
        "services.speech_service.transcribe_audio",
        return_value={
            "success": False,
            "transcript": "",
            "error": "Speech was unintelligible",
            "friendly_error": "आवाज़ साफ़ सुनाई नहीं दी, कृपया दोबारा बोलें (Could not transcribe)",
        },
    ), patch("services.ai_service.process_voice_to_catalog") as mock_ai:
        payload = b"RIFF" + b"\x00" * 200
        resp = client.post(
            "/api/catalog/voice-to-listing",
            data={"language": "hi", "audio": (io.BytesIO(payload), "voice.wav")},
            content_type="multipart/form-data",
        )
        assert resp.status_code == 422, resp.get_data(as_text=True)
        data = resp.get_json()
        assert data["success"] is False
        assert "friendly_error" in data
        assert data["friendly_error"]
        mock_ai.assert_not_called()
        body = resp.get_data(as_text=True)
        for marker in TERRACOTTA_MARKERS:
            assert marker not in body


def test_empty_audio_rejected():
    client = _client()
    resp = client.post(
        "/api/catalog/voice-to-listing",
        data={"language": "hi", "audio": (io.BytesIO(b"tiny"), "voice.wav")},
        content_type="multipart/form-data",
    )
    assert resp.status_code == 400, resp.get_data(as_text=True)
    assert resp.get_json()["success"] is False


def test_missing_audio_and_transcript_rejected():
    client = _client()
    resp = client.post(
        "/api/catalog/voice-to-listing",
        data={"language": "hi"},
        content_type="multipart/form-data",
    )
    assert resp.status_code == 400, resp.get_data(as_text=True)


if __name__ == "__main__":
    test_direct_transcript_succeeds()
    print("PASS direct_transcript_succeeds")
    test_stt_success_uses_real_transcript()
    print("PASS stt_success_uses_real_transcript")
    test_stt_failure_returns_422_without_fallback()
    print("PASS stt_failure_returns_422_without_fallback")
    test_empty_audio_rejected()
    print("PASS empty_audio_rejected")
    test_missing_audio_and_transcript_rejected()
    print("PASS missing_audio_and_transcript_rejected")
    print("ALL R2-02 VOICE HONEST-ERROR TESTS PASSED")
