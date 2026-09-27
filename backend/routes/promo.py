"""
AI Promotional Caption Generation Routes
Uses Gemini API to craft engaging, culturally resonant WhatsApp/social captions
in the artisan's preferred language, complete with hashtags, emojis, and provenance link.
"""
import logging
import os
import re
from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client

logger = logging.getLogger(__name__)

promo_bp = Blueprint('promo', __name__)

_LANG_NAMES = {
    'hi': 'Hindi (हिन्दी)',
    'en': 'English',
    'bn': 'Bengali (বাংলা)',
    'te': 'Telugu (తెలుగు)',
    'mr': 'Marathi (मराठी)',
    'ta': 'Tamil (தமிழ்)',
    'gu': 'Gujarati (ગુજરાતી)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'ml': 'Malayalam (മലയാളം)',
    'pa': 'Punjabi (ਪੰਜਾਬੀ)',
    'or': 'Odia (ଓଡ଼ିଆ)',
}


def _generate_caption_with_gemini(product: dict, artisan: dict, language: str) -> str:
    from google import genai  # type: ignore

    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY not configured")

    client = genai.Client(api_key=api_key)

    lang_desc = _LANG_NAMES.get(language, language)
    prompt = _build_caption_prompt(product, artisan, lang_desc)

    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=prompt
    )
    text = response.text.strip()
    # Strip any accidental markdown formatting
    text = re.sub(r'^```[a-zA-Z]*\n', '', text)
    text = re.sub(r'\n```$', '', text)
    return text.strip()


def _build_caption_prompt(product: dict, artisan: dict, lang_desc: str) -> str:
    """Build a prompt from recorded fields only; absent values stay absent."""
    facts = []

    def add_fact(label, value):
        if _is_present(value):
            facts.append(f"- {label}: {_format_fact(value)}")

    add_fact('Product title', product.get('title'))
    add_fact('Craft / category', product.get('category'))
    add_fact('Product description', product.get('description'))
    region = _first_present(product.get('region'), artisan.get('region'))
    add_fact('Recorded region', region)
    add_fact('Materials as recorded', product.get('materials'))
    add_fact('Price in INR', f"₹{product['price']}" if _is_present(product.get('price')) else None)
    add_fact('Artisan name', artisan.get('name') or product.get('artisan_name'))
    add_fact('GI / certification metadata as recorded', _first_present(product.get('gi_tag'), product.get('certification')))
    add_fact(
        'Fair-trade field as recorded',
        _first_present(product.get('fair_trade_verified'), artisan.get('fair_trade_verified')),
    )
    add_fact(
        'Eco-friendly field as recorded',
        _first_present(product.get('eco_friendly'), artisan.get('eco_friendly')),
    )
    add_fact(
        'Sustainability field as recorded',
        _first_present(
            product.get('sustainability'),
            product.get('sustainable'),
            artisan.get('sustainability'),
            artisan.get('sustainable'),
        ),
    )

    available_facts = '\n'.join(facts) if facts else '- No product metadata was provided.'
    return f"""You write warm, concise promotional captions for HunarSathi listings.

Recorded product facts (the only product-specific facts you may use):
{available_facts}

Target language: {lang_desc}

Truthfulness rules:
- Use only the recorded facts above. Omit missing fields; do not fill gaps with assumptions.
- Do not infer or invent GI certification, sustainability, eco-friendliness, fair-trade certification, artisan experience, heritage generations, materials, geographic origin, verification, or authenticity certification when the corresponding fact is absent.
- A GI or certification value is only metadata as recorded; do not upgrade it to government, third-party, or verified certification.
- Do not describe the item as 100% handcrafted, authentic, natural, sustainable, or eco-friendly unless that exact claim is supported by a recorded field above.
- A general invitation to discover the listing or support artisans through HunarSathi is allowed; do not claim guaranteed direct compensation or verification.

Write primarily in the target language. Include the recorded price only if present. Keep the caption concise and return only caption text, without markdown or explanations."""


def _fallback_caption(product: dict, artisan: dict, language: str) -> str:
    title = _first_present(product.get('title'))
    price = product.get('price')
    category = _first_present(product.get('category'))
    region = _first_present(product.get('region'), artisan.get('region'))
    artisan_name = _first_present(artisan.get('name'), product.get('artisan_name'))
    materials = _format_fact(product.get('materials'))
    gi_value = _first_present(product.get('gi_tag'), product.get('certification'))
    fair_trade = _first_present(
        product.get('fair_trade_verified'), artisan.get('fair_trade_verified')
    )
    eco_friendly = _first_present(product.get('eco_friendly'), artisan.get('eco_friendly'))
    sustainability = _first_present(
        product.get('sustainability'),
        product.get('sustainable'),
        artisan.get('sustainability'),
        artisan.get('sustainable'),
    )

    lines = []
    if language.startswith('hi'):
        lines.append(f"✨ HunarSathi पर देखें: {title}" if title else '✨ HunarSathi पर यह लिस्टिंग देखें')
        if category:
            lines.append(f"श्रेणी: {category}")
        if _is_present(price):
            lines.append(f"कीमत: ₹{price}")
        if artisan_name:
            lines.append(f"शिल्पकार: {artisan_name}")
        if region:
            lines.append(f"दर्ज क्षेत्र: {region}")
        if materials:
            lines.append(f"दर्ज सामग्री: {materials}")
        if gi_value:
            lines.append(f"GI / प्रमाणन फ़ील्ड में दर्ज: {gi_value}")
        if fair_trade is not None:
            lines.append(f"Fair-trade फ़ील्ड में दर्ज: {fair_trade}")
        if eco_friendly is not None:
            lines.append(f"Eco-friendly फ़ील्ड में दर्ज: {eco_friendly}")
        if sustainability is not None:
            lines.append(f"Sustainability फ़ील्ड में दर्ज: {sustainability}")
        lines.extend(['', 'HunarSathi के माध्यम से शिल्पकारों को समर्थन दें।', '#HunarSathi #SupportArtisans'])
    else:
        lines.append(f"✨ Discover {title} on HunarSathi" if title else '✨ Discover this listing on HunarSathi')
        if category:
            lines.append(f"Category: {category}")
        if _is_present(price):
            lines.append(f"Price: ₹{price}")
        if artisan_name:
            lines.append(f"Artisan: {artisan_name}")
        if region:
            lines.append(f"Recorded region: {region}")
        if materials:
            lines.append(f"Materials as listed: {materials}")
        if gi_value:
            lines.append(f"GI / certification field as recorded: {gi_value}")
        if fair_trade is not None:
            lines.append(f"Fair-trade field as recorded: {fair_trade}")
        if eco_friendly is not None:
            lines.append(f"Eco-friendly field as recorded: {eco_friendly}")
        if sustainability is not None:
            lines.append(f"Sustainability field as recorded: {sustainability}")
        lines.extend(['', 'Support artisans through HunarSathi.', '#HunarSathi #SupportArtisans'])
    return '\n'.join(lines)


def _is_present(value):
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, tuple, dict)):
        return bool(value)
    return True


def _first_present(*values):
    for value in values:
        if _is_present(value):
            return value.strip() if isinstance(value, str) else value
    return None


def _format_fact(value):
    if isinstance(value, (list, tuple)):
        return ', '.join(str(item).strip() for item in value if _is_present(item))
    if isinstance(value, dict):
        return ', '.join(f'{key}: {item}' for key, item in value.items() if _is_present(item))
    return str(value).strip() if value is not None else ''


@promo_bp.route('/generate', methods=['POST'])
def generate_promo_caption():
    """
    POST /api/promo/generate
    Request body (JSON):
        product_id (str, required)
        language   (str, optional — defaults to artisan language preference or 'hi')
    """
    data = request.get_json(silent=True) or {}
    product_id = data.get('product_id', '').strip()
    req_lang = data.get('language', '').strip().lower()

    if not product_id:
        return jsonify({"success": False, "error": "product_id is required"}), 400

    db = get_firestore_client()
    if db is None:
        return jsonify({"success": False, "error": "Product data unavailable"}), 503

    product = None
    artisan = {}

    try:
        pdoc = db.collection('products').document(product_id).get()
        if pdoc.exists:
            product = pdoc.to_dict() or {}
            product['id'] = pdoc.id
    except Exception:
        logger.warning("Could not load product metadata for promo generation")
        return jsonify({"success": False, "error": "Product data unavailable"}), 503

    if product is None:
        return jsonify({"success": False, "error": "Product not found"}), 404

    artisan_id = product.get('artisan_id')
    if artisan_id and db:
        try:
            adoc = db.collection('users').document(artisan_id).get()
            if adoc.exists:
                artisan = adoc.to_dict()
        except Exception:
            pass

    # Language selection: request language > artisan profile language > default 'hi'
    language = req_lang or artisan.get('language_preference') or 'hi'

    caption = None
    ai_generated = False
    try:
        caption = _generate_caption_with_gemini(product, artisan, language)
        ai_generated = True
    except Exception as ge:
        logger.info(f"Gemini promo generation fallback triggered: {ge}")
        caption = _fallback_caption(product, artisan, language)

    images = product.get('images')
    image_url = _first_present(product.get('image_url'))
    if not image_url and isinstance(images, list) and images:
        image_url = _first_present(images[0]) or ''

    host = request.host_url.rstrip('/')
    passport_url = f"{host}/passport/{product_id}"

    return jsonify({
        "success": True,
        "ai_generated": ai_generated,
        "product_id": product_id,
        "product_title": product.get('title'),
        "price": product.get('price'),
        "language": language,
        "caption": caption,
        "image_url": image_url,
        "passport_url": passport_url
    }), 200
