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

    title = product.get('title', 'Handcrafted Indian Artifact')
    price = product.get('price', 0)
    category = product.get('category', 'Handicrafts')
    region = product.get('region') or artisan.get('region') or 'India'
    materials = ", ".join(product.get('materials', ['Natural Sustainable Materials']))
    artisan_name = artisan.get('name', 'Heritage Artisan')
    lang_desc = _LANG_NAMES.get(language, language)

    prompt = f"""You are a master social media copywriter for KalaVistar, a platform celebrating traditional Indian artisans.
Write an authentic, warm, and highly engaging promotional caption suitable for sharing directly on WhatsApp and social media.

Product Details:
- Title: {title}
- Craft / Category: {category}
- Origin Region: {region}
- Materials: {materials}
- Price: ₹{price}
- Artisan: {artisan_name}

Target Language: {lang_desc}

Requirements:
1. Write primarily in {lang_desc}. If the language is Hindi, use natural, expressive conversational Hindi (Devanagari script).
2. Highlight the 100% handcrafted authenticity, direct artisan support, and sustainable materials.
3. Include culturally appealing emojis (🌿, 🪔, 🏺, ✨, 🇮🇳, 🛒).
4. State the price clearly: ₹{price}.
5. Include a call to action asking people to message or order to support local artisans directly (#VocalForLocal).
6. End with relevant hashtags: #KalaVistar #VocalForLocal #HandmadeInIndia #IndianHandicrafts #{category.replace(' ', '')}
7. Keep the caption concise (between 80 and 150 words).
8. Return ONLY the caption text without any introductory text, markdown fences, or explanations."""

    response = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=prompt
    )
    text = response.text.strip()
    # Strip any accidental markdown formatting
    text = re.sub(r'^```[a-zA-Z]*\n', '', text)
    text = re.sub(r'\n```$', '', text)
    return text.strip()


def _fallback_caption(product: dict, artisan: dict, language: str) -> str:
    title = product.get('title', 'हस्तनिर्मित पारंपरिक कलाकृति')
    price = product.get('price', 0)
    category = product.get('category', 'Handicraft')
    region = product.get('region') or artisan.get('region') or 'भारत'
    artisan_name = artisan.get('name', 'शिल्पकार')
    pid = product.get('id', 'item')

    if language.startswith('hi'):
        return (
            f"🌿 *KalaVistar विशेष — {title}* 🏺✨\n\n"
            f"नमस्ते जी! यह सुंदर और शत-प्रतिशत प्राकृतिक {title} हमारे हुनरमंद शिल्पकार {artisan_name} ({region}) द्वारा "
            f"पूर्णतः पारंपरिक पद्धति से हस्तनिर्मित किया गया है।\n\n"
            f"✅ 100% शुद्ध और प्रामाणिक हस्तशिल्प\n"
            f"🌱 पर्यावरण अनुकूल एवं टिकाऊ\n"
            f"💰 *विशेष मूल्य: मात्र ₹{price}*\n\n"
            f"सीधे स्थानीय कारीगरों को समर्थन दें और अपने घर में लाएं भारतीय विरासत की मिठास! 🪔\n\n"
            f"📲 ऑर्डर करने या पूछताछ के लिए अभी रिप्लाई करें या KalaVistar पर देखें!\n\n"
            f"#KalaVistar #VocalForLocal #HandmadeInIndia #AtmanirbharBharat #{category}"
        )
    else:
        return (
            f"🌿 *Direct from Heritage Artisans: {title}* 🏺✨\n\n"
            f"Support local craft! This authentic, 100% handcrafted {title} was lovingly created by "
            f"master artisan {artisan_name} from {region}.\n\n"
            f"✅ Authentic GI Certified Craftsmanship\n"
            f"🌱 Sustainable & Eco-friendly\n"
            f"💰 *Special Price: ₹{price}*\n\n"
            f"Bring home the soul of Indian heritage while empowering rural artisan communities directly. 🇮🇳\n\n"
            f"📲 Reply to this message or order via KalaVistar today!\n\n"
            f"#KalaVistar #VocalForLocal #HandmadeInIndia #SupportArtisans #{category}"
        )


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
    product = None
    artisan = {}

    if db:
        try:
            pdoc = db.collection('products').document(product_id).get()
            if pdoc.exists:
                product = pdoc.to_dict()
                product['id'] = pdoc.id
        except Exception as e:
            logger.warning(f"Error fetching product {product_id}: {e}")

    if not product:
        product = {
            "id": product_id,
            "title": "हस्तनिर्मित पारंपरिक टेराकोटा कुल्हड़ (Terracotta Kulhad Set)",
            "category": "Pottery",
            "price": 350.0,
            "region": "Gorakhpur, Uttar Pradesh",
            "materials": ["River Clay", "Natural Glaze"],
            "images": ["https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800"],
            "artisan_id": "artisan_demo_01"
        }

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

    images = product.get('images', [])
    image_url = images[0] if isinstance(images, list) and images else ""

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
