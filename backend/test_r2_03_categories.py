"""R2-03 regression: canonical product categories across marketplace flows.

Hermetic (no live Firestore/network):
- normalize_category mappings + canonical passthrough
- product creation stores canonical for legacy input
- product search matches legacy stored values via alias-aware filtering
- RFQ fallback/Gemini categories normalize to canonical
- pricing aliases normalize before logic without crash
"""
import io
import os
import sys
from unittest.mock import patch

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from services.categories import (  # noqa: E402
    CANONICAL_CATEGORIES,
    normalize_category,
)
from app import create_app  # noqa: E402


def _client():
    app = create_app()
    app.config.update(TESTING=True)
    return app.test_client()


# --- Fake Firestore for product create/search -------------------------------

class _FakeDoc:
    def __init__(self, doc_id, data):
        self.id = doc_id
        self._data = dict(data)

    def to_dict(self):
        return dict(self._data)


class _FakeDocRef:
    def __init__(self, store, doc_id):
        self._store = store
        self.id = doc_id

    def set(self, data):
        self._store[self.id] = dict(data)

    def get(self):
        exists = self.id in self._store
        doc = _FakeDoc(self.id, self._store.get(self.id, {}))
        doc.exists = exists
        return doc

    def update(self, updates):
        self._store[self.id].update(updates)


class _FakeCollection:
    def __init__(self, store):
        self._store = store

    def document(self, doc_id=None):
        import uuid
        doc_id = doc_id or f"doc_{uuid.uuid4().hex[:8]}"
        return _FakeDocRef(self._store, doc_id)

    def stream(self):
        return [_FakeDoc(doc_id, data) for doc_id, data in self._store.items()]

    def where(self, *args, **kwargs):
        # R2-03 search no longer relies on Firestore where for category;
        # tests only need stream(). Keep where as no-op passthrough.
        return self


class _FakeDB:
    def __init__(self):
        self.products = {}
        self.rfqs = {}

    def collection(self, name):
        if name == "products":
            return _FakeCollection(self.products)
        if name == "rfqs":
            return _FakeCollection(self.rfqs)
        return _FakeCollection({})


def test_normalize_mappings():
    assert normalize_category("Jewelry") == "Jewellery"
    assert normalize_category("jewellery") == "Jewellery"
    assert normalize_category("Woodwork") == "Wood Craft"
    assert normalize_category("Metalwork") == "Metal Craft"
    assert normalize_category("Accessories") == "Other"
    assert normalize_category("Stonework") == "Other"
    assert normalize_category("Basketry") == "Other"
    for canonical in CANONICAL_CATEGORIES:
        assert normalize_category(canonical) == canonical
        assert normalize_category(canonical.lower()) == canonical
    assert normalize_category("") == "Other"
    assert normalize_category(None) == "Other"


def test_product_creation_stores_canonical():
    from routes import products as products_route

    fake_db = _FakeDB()
    client = _client()
    with patch.object(products_route, "get_firestore_client", return_value=fake_db):
        resp = client.post(
            "/api/products",
            json={
                "artisan_id": "artisan_1",
                "title": "Brass idol",
                "price": 500,
                "stock_quantity": 3,
                "category": "Jewelry",
            },
        )
        assert resp.status_code == 201, resp.get_data(as_text=True)
        stored = list(fake_db.products.values())[0]
        assert stored["category"] == "Jewellery"


def test_product_search_matches_legacy():
    from routes import products as products_route

    fake_db = _FakeDB()
    fake_db.products["a"] = {"id": "a", "title": "Ring", "description": "", "price": 100, "category": "Jewelry"}
    fake_db.products["b"] = {"id": "b", "title": "Saree", "description": "", "price": 200, "category": "Textiles"}
    fake_db.products["c"] = {"id": "c", "title": "Carving", "description": "", "price": 300, "category": "Woodwork"}
    fake_db.products["d"] = {"id": "d", "title": "Idol", "description": "", "price": 400, "category": "Metalwork"}
    fake_db.products["e"] = {"id": "e", "title": "Tote", "description": "", "price": 150, "category": "Accessories"}

    client = _client()
    with patch.object(products_route, "get_firestore_client", return_value=fake_db):
        r = client.get("/api/products/search", query_string={"category": "Jewellery"})
        assert r.status_code == 200
        cats = [p["category"] for p in r.get_json()["products"]]
        assert cats == ["Jewellery"]

        r = client.get("/api/products/search", query_string={"category": "Wood Craft"})
        assert [p["category"] for p in r.get_json()["products"]] == ["Wood Craft"]

        r = client.get("/api/products/search", query_string={"category": "Metal Craft"})
        assert [p["category"] for p in r.get_json()["products"]] == ["Metal Craft"]

        r = client.get("/api/products/search", query_string={"category": "Other"})
        assert [p["category"] for p in r.get_json()["products"]] == ["Other"]


def test_rfq_fallback_normalizes_legacy_wording():
    from routes import rfq as rfq_route

    client = _client()
    with patch.object(rfq_route, "get_firestore_client", return_value=None):
        resp = client.post(
            "/api/rfq",
            json={"buyer_id": "buyer_1", "requirement_text": "I need 20 jewelry pieces please"},
        )
        assert resp.status_code == 200, resp.get_data(as_text=True)
        assert resp.get_json()["rfq"]["category"] == "Jewellery"

        resp = client.post(
            "/api/rfq",
            json={"buyer_id": "buyer_1", "requirement_text": "need woodwork items"},
        )
        assert resp.get_json()["rfq"]["category"] == "Wood Craft"


def test_rfq_gemini_legacy_output_normalized():
    from routes import rfq as rfq_route

    client = _client()
    fake_structured = {
        "category": "Jewelry",
        "quantity": 5,
        "target_price": 100.0,
        "deadline": "2026-10-26",
        "specifications": "test",
        "description": "test",
    }
    with patch.object(rfq_route, "_gemini_parse_rfq", return_value=fake_structured), patch.object(
        rfq_route, "get_firestore_client", return_value=None
    ):
        resp = client.post(
            "/api/rfq",
            json={"buyer_id": "buyer_1", "requirement_text": "anything"},
        )
        assert resp.get_json()["rfq"]["category"] == "Jewellery"


def test_pricing_aliases_normalize():
    from services.pricing_service import suggest_product_price

    for alias, canonical in [
        ("Jewelry", "Jewellery"),
        ("Woodwork", "Wood Craft"),
        ("Metalwork", "Metal Craft"),
        ("Accessories", "Other"),
    ]:
        res = suggest_product_price(category=alias, material_cost=100, size="medium", region="Uttar Pradesh")
        assert res["success"] is True
        assert res["category"] == canonical
        assert res["suggested_price"] > 0


def test_ai_voice_category_normalized():
    from services import ai_service as ai_mod

    fake_extracted = {
        "title_en": "t",
        "title_hi": "t",
        "description_en": "d",
        "description_hi": "d",
        "category": "Jewelry",
        "key_features": [],
    }
    with patch.object(ai_mod, "extract_product_listing_gemini", return_value=fake_extracted):
        out = ai_mod.process_voice_to_catalog("dummy transcript", "en")
        assert out["success"] is True
        assert out["category"] == "Jewellery"


if __name__ == "__main__":
    test_normalize_mappings()
    print("PASS normalize_mappings")
    test_product_creation_stores_canonical()
    print("PASS product_creation_stores_canonical")
    test_product_search_matches_legacy()
    print("PASS product_search_matches_legacy")
    test_rfq_fallback_normalizes_legacy_wording()
    print("PASS rfq_fallback_normalizes_legacy_wording")
    test_rfq_gemini_legacy_output_normalized()
    print("PASS rfq_gemini_legacy_output_normalized")
    test_pricing_aliases_normalize()
    print("PASS pricing_aliases_normalize")
    test_ai_voice_category_normalized()
    print("PASS ai_voice_category_normalized")
    print("ALL R2-03 CATEGORY TESTS PASSED")
