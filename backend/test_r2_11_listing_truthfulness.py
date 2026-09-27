"""Hermetic R2-11 tests for truthful product-listing extraction provenance."""
import json
import os
import sys
from pathlib import Path
from types import ModuleType
from unittest.mock import patch

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from services import ai_service as ai_mod  # noqa: E402
from services import firebase_service  # noqa: E402


def _install_fake_genai(response_text=None, error=None):
    calls = []

    class FakeModels:
        def generate_content(self, *, model, contents, config):
            calls.append((model, contents, config))
            if error is not None:
                raise RuntimeError(error)
            return type("FakeResponse", (), {"text": response_text})()

    class FakeClient:
        def __init__(self, *, api_key):
            assert api_key == "local-r2-11-test-key"
            self.models = FakeModels()

    google_module = ModuleType("google")
    genai_module = ModuleType("google.genai")
    genai_module.Client = FakeClient
    types_module = ModuleType("google.genai.types")
    types_module.GenerateContentConfig = lambda **kwargs: kwargs
    genai_module.types = types_module
    google_module.genai = genai_module
    modules = {
        "google": google_module,
        "google.genai": genai_module,
        "google.genai.types": types_module,
    }
    return patch.dict(sys.modules, modules), calls


def _valid_listing(category="Pottery"):
    return {
        "title_en": "Pottery cup",
        "title_hi": "मिट्टी का कप",
        "description_en": "I make a pottery cup.",
        "description_hi": "मैं मिट्टी का कप बनाता हूँ।",
        "category": category,
        "key_features": [],
    }


def test_missing_api_key_uses_fallback_and_marks_unstructured():
    with patch.dict(os.environ, {"GEMINI_API_KEY": "", "GOOGLE_API_KEY": ""}), patch.object(
        ai_mod, "_translate_text", side_effect=lambda text, target: text
    ):
        result = ai_mod.process_voice_to_catalog("मैं मिट्टी का कप बनाता हूँ", "hi")

    assert result["success"] is True
    assert result["ai_structured"] is False
    assert result["category"] == "Pottery"
    assert "मैं मिट्टी का कप बनाता हूँ" in result["description_hi"]


def test_valid_gemini_output_is_marked_structured_and_prompt_is_truthful():
    fake_modules, calls = _install_fake_genai(json.dumps(_valid_listing()))
    with patch.dict(os.environ, {"GEMINI_API_KEY": "local-r2-11-test-key"}), fake_modules:
        result = ai_mod.process_voice_to_catalog("I make a pottery cup.", "en")

    assert result["success"] is True
    assert result["ai_structured"] is True
    assert calls
    prompt = calls[0][1]
    assert "Use ONLY facts supported by the artisan's transcript" in prompt
    assert "Do not infer or invent material" in prompt
    assert "If a detail is missing, omit it" in prompt
    assert "do not invent items to fill a quota" in prompt


def test_gemini_candidates_failing_use_fallback_and_mark_unstructured():
    fake_modules, calls = _install_fake_genai(error="offline")
    with patch.dict(os.environ, {"GEMINI_API_KEY": "local-r2-11-test-key"}), fake_modules, patch.object(
        ai_mod, "_translate_text", side_effect=lambda text, target: text
    ):
        result = ai_mod.process_voice_to_catalog("मैं लकड़ी का डिब्बा बनाता हूँ", "hi")

    assert result["success"] is True
    assert result["ai_structured"] is False
    assert result["category"] == "Wood Craft"
    assert len(calls) == 3


def test_malformed_gemini_json_uses_fallback_and_marks_unstructured():
    fake_modules, _ = _install_fake_genai("not a JSON listing")
    with patch.dict(os.environ, {"GEMINI_API_KEY": "local-r2-11-test-key"}), fake_modules, patch.object(
        ai_mod, "_translate_text", side_effect=lambda text, target: text
    ):
        result = ai_mod.process_voice_to_catalog("I make pottery cups.", "en")

    assert result["success"] is True
    assert result["ai_structured"] is False
    assert result["category"] == "Pottery"


def test_unusable_gemini_fields_use_fallback_and_mark_unstructured():
    unusable = _valid_listing()
    unusable["title_en"] = 123
    fake_modules, _ = _install_fake_genai(json.dumps(unusable))
    with patch.dict(os.environ, {"GEMINI_API_KEY": "local-r2-11-test-key"}), fake_modules, patch.object(
        ai_mod, "_translate_text", side_effect=lambda text, target: text
    ):
        result = ai_mod.process_voice_to_catalog("I make pottery cups.", "en")

    assert result["success"] is True
    assert result["ai_structured"] is False
    assert result["title_en"] == "Artisan Pottery Product"


def test_pottery_fallback_does_not_invent_product_facts():
    with patch.object(ai_mod, "_translate_text", side_effect=lambda text, target: text):
        result = ai_mod._fallback_artisan_extraction("मैं मिट्टी का कप बनाता हूँ", "hi")
    output = " ".join(
        [result["title_en"], result["title_hi"], result["description_en"], result["description_hi"]]
        + result["key_features"]
    ).lower()
    for unsupported in ("river clay", "eco-friendly", "organic", "microwave", "traditional wheel", "100% natural"):
        assert unsupported not in output
    assert result["key_features"] == []
    assert "मैं मिट्टी का कप बनाता हूँ" in result["description_hi"]


def test_wood_fallback_does_not_invent_species_or_finish():
    with patch.object(ai_mod, "_translate_text", side_effect=lambda text, target: text):
        result = ai_mod._fallback_artisan_extraction("मैं लकड़ी का डिब्बा बनाता हूँ", "hi")
    output = json.dumps(result, ensure_ascii=False).lower()
    for unsupported in ("sheesham", "seasoned hardwood", "durable polish"):
        assert unsupported not in output


def test_painting_fallback_does_not_invent_origin_or_authenticity():
    with patch.object(ai_mod, "_translate_text", side_effect=lambda text, target: text):
        result = ai_mod._fallback_artisan_extraction("मैं मधुबनी पेंटिंग बनाता हूँ", "hi")
    output = json.dumps(result, ensure_ascii=False).lower()
    for unsupported in ("bihar", "natural dyes", "certified", "authenticity", "प्रमाणित", "प्रामाणिकता"):
        assert unsupported not in output
    assert result["category"] == "Painting"


def test_textile_fallback_does_not_invent_material_or_technique():
    with patch.object(ai_mod, "_translate_text", side_effect=lambda text, target: text):
        result = ai_mod._fallback_artisan_extraction("I make textiles.", "en")
    output = json.dumps(result, ensure_ascii=False).lower()
    for unsupported in ("botanical dyes", "organic", "natural cotton", "heritage block printing"):
        assert unsupported not in output
    assert result["category"] == "Textiles"


def test_catalog_routes_always_return_extraction_provenance():
    with patch.object(firebase_service, "init_firebase", return_value=None):
        from app import create_app

        app = create_app()
    app.config.update(TESTING=True)
    client = app.test_client()

    for endpoint, ai_result, expected in (
        ("/api/catalog/voice-to-listing", {"success": True, "ai_structured": True}, True),
        ("/api/catalog/voice-to-catalog", {"success": True}, False),
    ):
        with patch("services.ai_service.process_voice_to_catalog", return_value=ai_result):
            response = client.post(endpoint, json={"transcript": "I make a cup."})
        assert response.status_code == 200
        body = response.get_json()
        assert body["success"] is True
        assert body["ai_structured"] is expected


def test_startup_logging_does_not_format_or_expose_key_fragments():
    source = (Path(BASE_DIR) / "app.py").read_text(encoding="utf-8")
    assert "GEMINI_API_KEY: configured" in source
    assert "masked_key" not in source
    assert "gemini_key[:" not in source
    assert "gemini_key[-" not in source
    assert "len(gemini_key)" not in source


if __name__ == "__main__":
    _tests = [
        test_missing_api_key_uses_fallback_and_marks_unstructured,
        test_valid_gemini_output_is_marked_structured_and_prompt_is_truthful,
        test_gemini_candidates_failing_use_fallback_and_mark_unstructured,
        test_malformed_gemini_json_uses_fallback_and_marks_unstructured,
        test_unusable_gemini_fields_use_fallback_and_mark_unstructured,
        test_pottery_fallback_does_not_invent_product_facts,
        test_wood_fallback_does_not_invent_species_or_finish,
        test_painting_fallback_does_not_invent_origin_or_authenticity,
        test_textile_fallback_does_not_invent_material_or_technique,
        test_catalog_routes_always_return_extraction_provenance,
        test_startup_logging_does_not_format_or_expose_key_fragments,
    ]
    for _test in _tests:
        _test()
        print(f"PASS {_test.__name__}")
    print("ALL R2-11 LISTING TRUTHFULNESS TESTS PASSED")
