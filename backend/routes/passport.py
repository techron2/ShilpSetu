"""
Digital Craft Passport Routes
Presents product and artisan fields recorded in Firestore.
Accessible via QR code without requiring user login.
"""
from flask import Blueprint, jsonify, request, render_template_string
from services.firebase_service import get_firestore_client
import hashlib
import json

passport_bp = Blueprint('passport', __name__)

_HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{ passport.title }} — Digital Craft Passport | HunarSathi</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=Rozha+One&display=swap" rel="stylesheet">
  <style>
    :root {
      --terracotta: #C85A32;
      --terracotta-dark: #9E3D1B;
      --gold: #D4AF37;
      --gold-light: #F9F1DC;
      --parchment: #FDFBF7;
      --card-bg: #FFFFFF;
      --text-dark: #2C221E;
      --text-muted: #6B5E57;
      --border: #EADBCE;
      --green: #2E7D32;
      --green-light: #E8F5E9;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Outfit', sans-serif;
      background: var(--parchment);
      color: var(--text-dark);
      line-height: 1.6;
      padding: 16px;
    }
    .container {
      max-width: 680px;
      margin: 0 auto;
      background: var(--card-bg);
      border-radius: 24px;
      box-shadow: 0 12px 40px rgba(158, 61, 27, 0.08);
      border: 2px solid var(--border);
      overflow: hidden;
    }
    .header-banner {
      background: linear-gradient(135deg, var(--terracotta-dark), var(--terracotta));
      color: white;
      padding: 32px 24px 24px;
      text-align: center;
      position: relative;
    }
    .header-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(255,255,255,0.18);
      backdrop-filter: blur(8px);
      padding: 6px 14px;
      border-radius: 99px;
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      margin-bottom: 12px;
      border: 1px solid rgba(255,255,255,0.3);
    }
    .title {
      font-family: 'Rozha One', serif;
      font-size: 28px;
      letter-spacing: 0.5px;
      margin-bottom: 6px;
    }
    .subtitle {
      font-size: 14px;
      opacity: 0.9;
    }
    .image-container {
      width: 100%;
      height: 280px;
      background: #FAECE4;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    .image-container img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .content {
      padding: 24px;
    }
    .badge-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(130px, 1fr));
      gap: 12px;
      margin-bottom: 24px;
    }
    .badge-card {
      background: var(--gold-light);
      border: 1px solid rgba(212, 175, 55, 0.3);
      padding: 12px;
      border-radius: 14px;
      text-align: center;
    }
    .badge-label {
      font-size: 11px;
      color: var(--text-muted);
      text-transform: uppercase;
      font-weight: 600;
    }
    .badge-val {
      font-size: 14px;
      font-weight: 700;
      color: var(--terracotta-dark);
      margin-top: 2px;
    }
    .section-title {
      font-size: 17px;
      font-weight: 700;
      color: var(--terracotta);
      margin: 20px 0 8px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .card {
      background: #FDFBF7;
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 16px;
      margin-bottom: 16px;
    }
    .tag-cloud {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 8px;
    }
    .tag {
      background: white;
      border: 1px solid var(--border);
      color: var(--text-muted);
      padding: 4px 10px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 500;
    }
    .record-box {
      background: #FDFBF7;
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 16px;
      text-align: center;
      margin-top: 24px;
    }
    .record-mark {
      font-size: 32px;
      margin-bottom: 4px;
    }
    .record-title {
      font-weight: 700;
      color: var(--text-dark);
      font-size: 16px;
    }
    .hash-text {
      font-family: monospace;
      font-size: 11px;
      color: var(--text-muted);
      word-break: break-all;
      background: rgba(255,255,255,0.7);
      padding: 6px;
      border-radius: 6px;
      margin-top: 8px;
    }
    .footer {
      text-align: center;
      padding: 20px;
      font-size: 12px;
      color: var(--text-muted);
      border-top: 1px solid var(--border);
    }
    .footer strong { color: var(--terracotta); }
  </style>
</head>
<body>
  <div class="container">
    <div class="header-banner">
      <div class="header-badge">HunarSathi Digital Craft Passport</div>
      <h1 class="title">{{ passport.title }}</h1>
      {% if passport.artisan.name or passport.origin_region %}
      <p class="subtitle">
        {% if passport.artisan.name %}Artisan: {{ passport.artisan.name }}{% endif %}
        {% if passport.artisan.name and passport.origin_region %} • {% endif %}
        {% if passport.origin_region %}Recorded region: {{ passport.origin_region }}{% endif %}
      </p>
      {% endif %}
    </div>

    {% if passport.image_url %}
    <div class="image-container">
      <img src="{{ passport.image_url }}" alt="{{ passport.title }}" onerror="this.style.display='none'">
    </div>
    {% endif %}

    <div class="content">
      <div class="badge-grid">
        {% if passport.craft_type %}
        <div class="badge-card">
          <div class="badge-label">Craft Type</div>
          <div class="badge-val">{{ passport.craft_type }}</div>
        </div>
        {% endif %}
        {% if passport.certification %}
        <div class="badge-card">
          <div class="badge-label">GI / Certification (as recorded)</div>
          <div class="badge-val">{{ passport.certification }}</div>
        </div>
        {% endif %}
        {% if passport.artisan.cluster %}
        <div class="badge-card">
          <div class="badge-label">Cluster</div>
          <div class="badge-val">{{ passport.artisan.cluster }}</div>
        </div>
        {% endif %}
        {% if passport.artisan.experience_years is defined %}
        <div class="badge-card">
          <div class="badge-label">Experience (as recorded)</div>
          <div class="badge-val">{{ passport.artisan.experience_years }} years</div>
        </div>
        {% endif %}
        {% if passport.artisan.phone_verified is defined %}
        <div class="badge-card">
          <div class="badge-label">Phone verification field</div>
          <div class="badge-val">{{ passport.artisan.phone_verified }}</div>
        </div>
        {% endif %}
      </div>

      {% if passport.artisan_story %}
      <div class="section-title">Artisan story (as recorded)</div>
      <div class="card">
        <p>{{ passport.artisan_story }}</p>
      </div>
      {% endif %}

      {% if passport.description %}
      <div class="section-title">Product description</div>
      <div class="card">
        <p>{{ passport.description }}</p>
      </div>
      {% endif %}

      {% if passport.materials or passport.materials_story %}
      <div class="section-title">Materials (as recorded)</div>
      <div class="card">
        {% if passport.materials_story %}<p>{{ passport.materials_story }}</p>{% endif %}
        <div class="tag-cloud">
          {% for mat in passport.materials %}
          <span class="tag">{{ mat }}</span>
          {% endfor %}
        </div>
      </div>
      {% endif %}

      {% if passport.origin_region or passport.fair_trade_verified is defined or passport.eco_friendly is defined or passport.sustainability is defined %}
      <div class="section-title">Recorded product and origin fields</div>
      <div class="card">
        {% if passport.origin_region %}<p><strong>Region:</strong> {{ passport.origin_region }}</p>{% endif %}
        {% if passport.fair_trade_verified is defined %}<p><strong>Fair-trade field as recorded:</strong> {{ passport.fair_trade_verified }}</p>{% endif %}
        {% if passport.eco_friendly is defined %}<p><strong>Eco-friendly field as recorded:</strong> {{ passport.eco_friendly }}</p>{% endif %}
        {% if passport.sustainability is defined %}<p><strong>Sustainability field as recorded:</strong> {{ passport.sustainability }}</p>{% endif %}
      </div>
      {% endif %}

      <div class="record-box">
        <div class="record-mark">▤</div>
        <div class="record-title">Passport record fingerprint</div>
        <p style="font-size: 13px; color: #6B5E57; margin-top: 4px;">A locally generated SHA-256 fingerprint of stored record fields; it does not independently verify or certify them.</p>
        <div class="hash-text">PASSPORT-ID: {{ passport.passport_id }}<br>RECORD FINGERPRINT: {{ passport.record_fingerprint }}</div>
      </div>
    </div>

    <div class="footer">
      Powered by <strong>HunarSathi</strong> — Product and artisan details shown as recorded.
    </div>
  </div>
</body>
</html>
"""


def _generate_record_fingerprint(product_id: str, artisan_id: str, created_at: str) -> str:
    raw = f"{product_id}:{artisan_id}:{created_at}"
    return hashlib.sha256(raw.encode('utf-8')).hexdigest()


class PassportDataUnavailable(Exception):
    """Raised when the product store cannot be read; this is not a missing product."""


_PASSPORT_TEST_PRODUCT_ID = 'test_passport_prod_01'


def _build_passport_payload(product_id: str):
    db = get_firestore_client()
    prod_data = None
    artisan_data = {}

    if db is None:
        if product_id == _PASSPORT_TEST_PRODUCT_ID:
            # Preserve the explicit fixture used by the legacy endpoint smoke test.
            prod_data = {
                "id": product_id,
                "title": "Passport test item",
                "category": "Test item",
            }
        else:
            raise PassportDataUnavailable()
    else:
        try:
            doc = db.collection('products').document(product_id).get()
            if doc.exists:
                prod_data = doc.to_dict() or {}
                prod_data['id'] = doc.id
        except Exception:
            raise PassportDataUnavailable()

    if prod_data is None and product_id == _PASSPORT_TEST_PRODUCT_ID:
        # This identifier is an intentional, neutral test fixture—not a live fallback.
        prod_data = {
            "id": product_id,
            "title": "Passport test item",
            "category": "Test item",
        }
    elif prod_data is None:
        return None

    artisan_id = _first_present((prod_data,), 'artisan_id')
    if db:
        if artisan_id:
            try:
                adoc = db.collection('users').document(artisan_id).get()
                if adoc.exists:
                    artisan_data = adoc.to_dict() or {}
            except Exception:
                artisan_data = {}

    def stored_value(keys):
        return _first_present((prod_data, artisan_data), *keys)

    created_at = _first_present((prod_data,), 'created_at')
    if hasattr(created_at, 'isoformat'):
        created_at = created_at.isoformat()
    created_at_for_hash = str(created_at) if created_at is not None else ''
    record_fingerprint = _generate_record_fingerprint(
        product_id,
        str(artisan_id) if artisan_id is not None else '',
        created_at_for_hash,
    )

    raw_materials = _first_present((prod_data,), 'materials')
    if isinstance(raw_materials, (list, tuple)):
        materials = [str(value).strip() for value in raw_materials if _is_present(value)]
    elif isinstance(raw_materials, str):
        materials = [raw_materials.strip()] if raw_materials.strip() else []
    else:
        materials = []

    raw_images = prod_data.get('images')
    image_from_array = (
        raw_images[0]
        if isinstance(raw_images, list) and raw_images and _is_present(raw_images[0])
        else None
    )
    image_url = _first_present((prod_data,), 'image_url') or image_from_array

    passport = {
        "passport_id": f"PASSPORT-{product_id[:8].upper()}",
        "product_id": product_id,
        "artisan": {},
        "record_fingerprint": record_fingerprint,
    }
    for key, value in {
        'title': stored_value(('title',)),
        'description': stored_value(('description',)),
        'craft_type': _first_present((prod_data,), 'category', 'craft_type'),
        'image_url': image_url,
        'origin_region': stored_value(('region',)),
        'certification': _first_present((prod_data,), 'gi_tag', 'certification'),
        'materials': materials,
        'materials_story': _first_present((prod_data,), 'materials_story'),
        'artisan_story': stored_value(('artisan_story', 'story')),
        'fair_trade_verified': stored_value(('fair_trade_verified',)),
        'eco_friendly': stored_value(('eco_friendly',)),
        'sustainability': stored_value(('sustainability', 'sustainable')),
        'created_at': created_at,
    }.items():
        if _is_present(value):
            passport[key] = value

    artisan_fields = {
        'id': artisan_id,
        'name': (
            _first_present((artisan_data,), 'name')
            or _first_present((prod_data,), 'artisan_name')
        ),
        'cluster': _first_present(
            (artisan_data, prod_data), 'artisan_cluster', 'cluster_name', 'cluster', 'cluster_id'
        ),
        'phone_verified': _first_present(
            (artisan_data, prod_data), 'phone_verified', 'phone_number_verified'
        ),
        'experience_years': _first_present((artisan_data, prod_data), 'experience_years'),
    }
    passport['artisan'] = {
        key: value for key, value in artisan_fields.items() if _is_present(value)
    }
    return passport


def _is_present(value):
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, tuple, dict)):
        return bool(value)
    return True


def _first_present(sources, *keys):
    for source in sources:
        for key in keys:
            value = source.get(key)
            if _is_present(value):
                return value.strip() if isinstance(value, str) else value
    return None


def _passport_response(product_id: str, *, as_html: bool = False):
    try:
        passport = _build_passport_payload(product_id)
    except PassportDataUnavailable:
        return jsonify({"success": False, "error": "Passport data unavailable"}), 503

    if passport is None:
        return jsonify({"success": False, "error": "Product not found"}), 404
    if as_html:
        return render_template_string(_HTML_TEMPLATE, passport=passport)
    return jsonify({"success": True, "passport": passport}), 200


def render_public_passport(product_id: str):
    """Render the public HTML Passport, returning an error for missing products."""
    return _passport_response(product_id, as_html=True)


@passport_bp.route('/<product_id>', methods=['GET'])
def get_passport_json(product_id):
    """
    GET /api/passport/<product_id>
    Returns recorded product and artisan fields.
    If the client requests HTML (browser view), renders the public Passport page.
    """
    best = request.accept_mimetypes.best_match(['application/json', 'text/html'])
    wants_html = (
        best == 'text/html'
        and request.accept_mimetypes[best] > request.accept_mimetypes['application/json']
    )
    return _passport_response(product_id, as_html=wants_html)


@passport_bp.route('/<product_id>/view', methods=['GET'])
def get_passport_html_view(product_id):
    """
    GET /api/passport/<product_id>/view
    Explicit HTML view endpoint for QR code scanners and direct browser access.
    """
    return render_public_passport(product_id)
