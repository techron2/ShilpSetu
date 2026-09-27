"""Hermetic RFQ provenance and deterministic supplier-matching semantics tests."""
import os
import sys
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from services import firebase_service  # noqa: E402

with patch.object(firebase_service, 'init_firebase', return_value=None):
    from app import create_app  # noqa: E402

from routes import rfq as rfq_route  # noqa: E402


class _FakeFirestore:
    def __init__(self):
        self.rfqs = {}

    def collection(self, name):
        assert name == 'rfqs'
        return _FakeRfqCollection(self.rfqs)


class _FakeRfqCollection:
    def __init__(self, records):
        self.records = records

    def document(self, doc_id=None):
        chosen_id = doc_id or f'rfq-{len(self.records) + 1}'
        return _FakeRfqReference(self.records, chosen_id)


class _FakeRfqReference:
    def __init__(self, records, doc_id):
        self.records = records
        self.id = doc_id

    def set(self, value):
        self.records[self.id] = dict(value)


def _client():
    with patch.object(firebase_service, 'init_firebase', return_value=None):
        app = create_app()
    app.config.update(TESTING=True)
    return app.test_client()


def _valid_gemini_rfq(category='Pottery'):
    return {
        'category': category,
        'quantity': 20,
        'target_price': 300.0,
        'deadline': '2026-10-27',
        'specifications': 'Pottery cups, buyer requirements apply',
        'description': '20 pottery cups for a buyer.',
    }


def _post(client, text='I need 20 pottery cups, budget ₹6000, delivery next month.'):
    return client.post(
        '/api/rfq',
        json={'buyer_id': 'test-buyer', 'requirement_text': text},
    )


def test_gemini_success_sets_consistent_no_database_provenance():
    client = _client()
    with patch.object(rfq_route, 'get_firestore_client', return_value=None), patch.object(
        rfq_route, '_gemini_parse_rfq', return_value=_valid_gemini_rfq()
    ):
        response = _post(client)

    assert response.status_code == 200
    body = response.get_json()
    assert body['success'] is True
    assert body['ai_structured'] is True
    assert body['rfq']['ai_parsed'] is True
    assert body['rfq']['category'] == 'Pottery'


def test_gemini_failure_uses_useful_fallback_and_marks_no_database_provenance():
    client = _client()
    requirement = 'I need 20 pottery cups, budget ₹6000, delivery next month.'
    with patch.object(rfq_route, 'get_firestore_client', return_value=None), patch.object(
        rfq_route, '_gemini_parse_rfq', side_effect=RuntimeError('offline')
    ):
        response = _post(client, text=requirement)

    assert response.status_code == 200
    body = response.get_json()
    rfq = body['rfq']
    assert body['success'] is True
    assert body['ai_structured'] is False
    assert rfq['ai_parsed'] is False
    assert rfq['quantity'] == 20
    assert rfq['target_price'] == 300
    assert rfq['category'] == 'Pottery'
    assert rfq['description'] == requirement
    deadline = datetime.strptime(rfq['deadline'], '%Y-%m-%d').date()
    today = datetime.now(timezone.utc).date()
    assert deadline in (today + timedelta(days=29), today + timedelta(days=30))


def test_malformed_gemini_output_falls_back_instead_of_claiming_ai_success():
    client = _client()
    with patch.object(rfq_route, 'get_firestore_client', return_value=None), patch.object(
        rfq_route, '_gemini_parse_rfq', return_value={'category': 'Pottery'}
    ):
        response = _post(client)

    body = response.get_json()
    assert response.status_code == 200
    assert body['ai_structured'] is False
    assert body['rfq']['ai_parsed'] is False
    assert body['rfq']['quantity'] == 20


def test_firestore_document_and_response_preserve_actual_parser_provenance():
    client = _client()
    for parser_result, expected_ai in (
        (_valid_gemini_rfq(), True),
        (RuntimeError('offline'), False),
    ):
        db = _FakeFirestore()
        parser_patch = (
            patch.object(rfq_route, '_gemini_parse_rfq', return_value=parser_result)
            if isinstance(parser_result, dict)
            else patch.object(rfq_route, '_gemini_parse_rfq', side_effect=parser_result)
        )
        with patch.object(rfq_route, 'get_firestore_client', return_value=db), parser_patch:
            response = _post(client)

        assert response.status_code == 201
        body = response.get_json()
        assert body['success'] is True
        assert body['ai_structured'] is expected_ai
        assert body['rfq']['ai_parsed'] is expected_ai
        assert len(db.rfqs) == 1
        stored_rfq = next(iter(db.rfqs.values()))
        assert stored_rfq['ai_parsed'] is expected_ai


def test_legacy_gemini_categories_are_normalized_before_return():
    client = _client()
    for legacy, canonical in (
        ('Jewelry', 'Jewellery'),
        ('Woodwork', 'Wood Craft'),
        ('Metalwork', 'Metal Craft'),
    ):
        with patch.object(rfq_route, 'get_firestore_client', return_value=None), patch.object(
            rfq_route, '_gemini_parse_rfq', return_value=_valid_gemini_rfq(legacy)
        ):
            response = _post(client)
        assert response.status_code == 200
        body = response.get_json()
        assert body['rfq']['ai_parsed'] is True
        assert body['rfq']['category'] == canonical


if __name__ == '__main__':
    _tests = [
        test_gemini_success_sets_consistent_no_database_provenance,
        test_gemini_failure_uses_useful_fallback_and_marks_no_database_provenance,
        test_malformed_gemini_output_falls_back_instead_of_claiming_ai_success,
        test_firestore_document_and_response_preserve_actual_parser_provenance,
        test_legacy_gemini_categories_are_normalized_before_return,
    ]
    for _test in _tests:
        _test()
        print(f'PASS {_test.__name__}')
    print('ALL R2-08 RFQ AI-SEMANTICS TESTS PASSED')
