"""R2-07 regressions for evidence-backed buyer trust and provenance surfaces."""
import os
import sys
from unittest.mock import patch

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from services import firebase_service  # noqa: E402

# Keep route tests hermetic: app construction must not initialize live Firebase.
with patch.object(firebase_service, 'init_firebase', return_value=None):
    from app import create_app  # noqa: E402

from routes import matching as matching_route  # noqa: E402
from routes import passport as passport_route  # noqa: E402
from routes import promo as promo_route  # noqa: E402


class _FakeSnapshot:
    def __init__(self, doc_id, data):
        self.id = doc_id
        self.exists = data is not None
        self._data = dict(data or {})

    def to_dict(self):
        return dict(self._data)


class _FakeCollection:
    def __init__(self, docs):
        self._docs = dict(docs)

    def document(self, doc_id):
        data = self._docs.get(doc_id)
        return _FakeDocumentReference(doc_id, data)

    def stream(self):
        return [_FakeSnapshot(doc_id, data) for doc_id, data in self._docs.items()]

    def where(self, field, operator, value):
        if operator == '==':
            return _FakeCollection({
                doc_id: data for doc_id, data in self._docs.items()
                if data.get(field) == value
            })
        return self


class _FakeDocumentReference:
    def __init__(self, doc_id, data):
        self._doc_id = doc_id
        self._data = data

    def get(self):
        return _FakeSnapshot(self._doc_id, self._data)


class _FakeFirestore:
    def __init__(self, products=None, users=None):
        self._collections = {
            'products': dict(products or {}),
            'users': dict(users or {}),
        }

    def collection(self, name):
        return _FakeCollection(self._collections.get(name, {}))


def _client():
    with patch.object(firebase_service, 'init_firebase', return_value=None):
        app = create_app()
    app.config.update(TESTING=True)
    return app.test_client()


def _sparse_product(**extra):
    return {
        'title': 'Blue clay bowl',
        'description': 'A bowl listed by an artisan.',
        'category': 'Pottery',
        'image_url': 'https://example.test/blue-bowl.jpg',
        'artisan_id': 'artisan_sparse',
        'created_at': '2026-09-01T10:00:00+00:00',
        **extra,
    }


def test_sparse_passport_uses_recorded_fields_and_image_url():
    db = _FakeFirestore(
        products={
            'sparse-product': _sparse_product(),
            'images-array-product': {
                'title': 'Woven mat',
                'images': ['https://example.test/woven-mat.jpg', 'https://example.test/second.jpg'],
            },
        },
        users={'artisan_sparse': {'name': 'Profile Artisan'}},
    )
    client = _client()
    with patch.object(passport_route, 'get_firestore_client', return_value=db):
        response = client.get('/api/passport/sparse-product', headers={'Accept': 'application/json'})
        assert response.status_code == 200
        passport = response.get_json()['passport']

        assert passport['title'] == 'Blue clay bowl'
        assert passport['image_url'] == 'https://example.test/blue-bowl.jpg'
        assert passport['artisan']['name'] == 'Profile Artisan'
        assert 'certification' not in passport
        assert 'materials' not in passport
        assert 'origin_region' not in passport
        assert 'artisan_story' not in passport
        assert 'fair_trade_verified' not in passport
        assert 'eco_friendly' not in passport
        assert 'sustainability' not in passport
        assert 'cluster' not in passport['artisan']
        assert 'phone_verified' not in passport['artisan']
        assert 'experience_years' not in passport['artisan']
        assert 'record_fingerprint' in passport

        images_response = client.get('/api/passport/images-array-product')
        assert images_response.status_code == 200
        assert (
            images_response.get_json()['passport']['image_url']
            == 'https://example.test/woven-mat.jpg'
        )
        images_html = client.get('/api/passport/images-array-product/view')
        assert b'<img src="https://example.test/woven-mat.jpg"' in images_html.data

        html = client.get('/api/passport/sparse-product/view')
        assert html.status_code == 200
        html_text = html.get_data(as_text=True)
        assert '<img src="https://example.test/blue-bowl.jpg"' in html_text
        assert 'Blue clay bowl' in html_text
        for unsupported_claim in (
            'GI / Certification (as recorded)',
            '100% Handcrafted',
            'Fair Trade Guarantee',
            'Verified Authenticity Certificate',
            'cryptographically anchored',
            'centuries-old indigenous technique',
            'Independent',
            'Natural River Clay',
            '3rd-generation heritage artisan',
        ):
            assert unsupported_claim not in html_text
        assert 'Passport record fingerprint' in html_text
        assert 'does not independently verify or certify them' in html_text


def test_passport_shows_actual_gi_cluster_materials_and_profile_fields():
    product = _sparse_product(
        gi_tag='Example GI',
        materials=['Linen', 'Natural dye'],
        artisan_cluster='Recorded cluster',
        story='A story recorded by the artisan.',
        fair_trade_verified=True,
        eco_friendly=False,
    )
    db = _FakeFirestore(
        products={'evidence-product': product},
        users={
            'artisan_sparse': {
                'name': 'Profile Artisan',
                'artisan_cluster': 'Profile cluster',
                'region': 'Recorded region',
                'experience_years': 7,
                'phone_verified': False,
            },
        },
    )
    client = _client()
    with patch.object(passport_route, 'get_firestore_client', return_value=db):
        response = client.get('/api/passport/evidence-product')
        assert response.status_code == 200
        passport = response.get_json()['passport']
        html_text = client.get('/api/passport/evidence-product/view').get_data(as_text=True)

    assert passport['certification'] == 'Example GI'
    assert passport['materials'] == ['Linen', 'Natural dye']
    assert passport['artisan_story'] == 'A story recorded by the artisan.'
    assert passport['origin_region'] == 'Recorded region'
    assert passport['fair_trade_verified'] is True
    assert passport['eco_friendly'] is False
    assert passport['artisan']['cluster'] == 'Profile cluster'
    assert passport['artisan']['experience_years'] == 7
    assert passport['artisan']['phone_verified'] is False

    assert 'Example GI' in html_text
    assert 'Linen' in html_text
    assert 'Profile cluster' in html_text
    assert 'Fair-trade field as recorded:</strong> True' in html_text
    assert 'Eco-friendly field as recorded:</strong> False' in html_text


def test_unknown_passport_is_not_substituted_with_demo_product():
    client = _client()
    db = _FakeFirestore()
    with patch.object(passport_route, 'get_firestore_client', return_value=db):
        response = client.get('/api/passport/arbitrary-missing-product')
        assert response.status_code == 404
        assert response.get_json() == {
            'success': False,
            'error': 'Product not found',
        }

        html_response = client.get('/api/passport/arbitrary-missing-product/view')
        assert html_response.status_code == 404
        assert b'Product not found' in html_response.data
        assert b'Terracotta' not in html_response.data
        direct_html_response = client.get('/passport/arbitrary-missing-product')
        assert direct_html_response.status_code == 404
        assert b'Terracotta' not in direct_html_response.data


def test_explicit_legacy_passport_smoke_fixture_is_neutral():
    client = _client()
    with patch.object(passport_route, 'get_firestore_client', return_value=_FakeFirestore()):
        response = client.get('/api/passport/test_passport_prod_01')
        assert response.status_code == 200
        passport = response.get_json()['passport']
        assert passport['title'] == 'Passport test item'
        assert 'certification' not in passport
        assert 'materials' not in passport
        assert 'artisan_story' not in passport
        html = client.get('/passport/test_passport_prod_01')
        assert html.status_code == 200
        assert b'Passport record fingerprint' in html.data

    with patch.object(passport_route, 'get_firestore_client', return_value=None):
        no_store_fixture = client.get('/api/passport/test_passport_prod_01')
        assert no_store_fixture.status_code == 200
        unavailable = client.get('/api/passport/arbitrary-product')
        assert unavailable.status_code == 503


def test_promo_fallback_uses_only_available_facts_and_unknown_is_404():
    db = _FakeFirestore(products={'sparse-product': _sparse_product()})
    client = _client()
    with patch.object(promo_route, 'get_firestore_client', return_value=db), patch.object(
        promo_route, '_generate_caption_with_gemini', side_effect=RuntimeError('offline')
    ):
        response = client.post(
            '/api/promo/generate',
            json={'product_id': 'sparse-product', 'language': 'en'},
        )
        assert response.status_code == 200
        body = response.get_json()
        caption = body['caption']
        assert body['ai_generated'] is False
        assert 'Blue clay bowl' in caption
        assert '₹' not in caption
        assert 'GI' not in caption
        assert 'certified' not in caption.lower()
        assert 'eco-friendly' not in caption.lower()
        assert 'sustainable' not in caption.lower()
        assert '100% authentic' not in caption.lower()
        assert 'master artisan' not in caption.lower()
        assert 'Support artisans through HunarSathi' in caption

        missing = client.post(
            '/api/promo/generate',
            json={'product_id': 'arbitrary-missing-product', 'language': 'en'},
        )
        assert missing.status_code == 404
        assert missing.get_json()['error'] == 'Product not found'


def test_promo_fallback_and_gemini_prompt_can_use_actual_metadata():
    product = _sparse_product(
        gi_tag='Example GI',
        materials=['Wool', 'Natural dye'],
        region='Kutch',
        price=850,
    )
    db = _FakeFirestore(products={'evidence-product': product})
    client = _client()
    with patch.object(promo_route, 'get_firestore_client', return_value=db), patch.object(
        promo_route, '_generate_caption_with_gemini', side_effect=RuntimeError('offline')
    ):
        response = client.post(
            '/api/promo/generate',
            json={'product_id': 'evidence-product', 'language': 'en'},
        )
    assert response.status_code == 200
    caption = response.get_json()['caption']
    assert 'Example GI' in caption
    assert 'Wool, Natural dye' in caption
    assert 'Kutch' in caption
    assert '₹850' in caption

    prompt = promo_route._build_caption_prompt(product, {}, 'English')
    assert 'Do not infer or invent GI certification' in prompt
    assert 'sustainability, eco-friendliness, fair-trade certification' in prompt
    assert 'Materials as recorded: Wool, Natural dye' in prompt
    assert 'Recorded region: Kutch' in prompt
    sparse_prompt = promo_route._build_caption_prompt(_sparse_product(), {}, 'English')
    assert 'Materials as recorded:' not in sparse_prompt
    assert 'Recorded region:' not in sparse_prompt


def _matching_result(product, artisan=None):
    db = _FakeFirestore(
        products={'match-product': product},
        users={'artisan_match': {'role': 'artisan', **(artisan or {})}},
    )
    client = _client()
    with patch.object(matching_route, 'get_firestore_client', return_value=db):
        response = client.post(
            '/api/matching/buyer-supplier',
            json={'category': 'Pottery', 'quantity': 1, 'budget': 1000, 'region': 'Bihar'},
        )
    assert response.status_code == 200, response.get_data(as_text=True)
    return response.get_json()['matches'][0]['artisan']


def test_matching_omits_missing_rating_and_review_count():
    artisan = _matching_result({
        'title': 'Pottery bowl',
        'description': 'A bowl',
        'category': 'Pottery',
        'region': 'Bihar',
        'price': 300,
        'artisan_id': 'artisan_match',
    })
    assert 'rating' not in artisan
    assert 'review_count' not in artisan


def test_matching_preserves_artisan_rating_and_falls_back_to_product_evidence():
    artisan_rating = _matching_result(
        {
            'title': 'Pottery bowl',
            'description': 'A bowl',
            'category': 'Pottery',
            'region': 'Bihar',
            'price': 300,
            'artisan_id': 'artisan_match',
            'rating': 3.1,
            'review_count': 4,
        },
        {'rating': 4.65, 'review_count': 12},
    )
    assert artisan_rating['rating'] == 4.65
    assert artisan_rating['review_count'] == 12

    product_rating = _matching_result(
        {
            'title': 'Pottery bowl',
            'description': 'A bowl',
            'category': 'Pottery',
            'region': 'Bihar',
            'price': 300,
            'artisan_id': 'artisan_match',
            'rating': 3.25,
            'review_count': 5,
        },
    )
    assert product_rating['rating'] == 3.25
    assert product_rating['review_count'] == 5


if __name__ == '__main__':
    _tests = [
        test_sparse_passport_uses_recorded_fields_and_image_url,
        test_passport_shows_actual_gi_cluster_materials_and_profile_fields,
        test_unknown_passport_is_not_substituted_with_demo_product,
        test_explicit_legacy_passport_smoke_fixture_is_neutral,
        test_promo_fallback_uses_only_available_facts_and_unknown_is_404,
        test_promo_fallback_and_gemini_prompt_can_use_actual_metadata,
        test_matching_omits_missing_rating_and_review_count,
        test_matching_preserves_artisan_rating_and_falls_back_to_product_evidence,
    ]
    for _test in _tests:
        _test()
        print(f'PASS {_test.__name__}')
    print('ALL R2-07 BUYER TRUST TRUTHFULNESS TESTS PASSED')
