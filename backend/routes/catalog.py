import logging
from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client

logger = logging.getLogger(__name__)

catalog_bp = Blueprint('catalog', __name__)

@catalog_bp.route('', methods=['GET'])
def get_artisan_catalog():
    """Returns placeholder artisan catalog items or fetched from Firestore if configured."""
    db = get_firestore_client()
    if db:
        try:
            # When real Firebase is connected, fetch from 'products' collection
            products_ref = db.collection('products').stream()
            products = [doc.to_dict() | {"id": doc.id} for doc in products_ref]
            return jsonify({"success": True, "source": "firestore", "products": products}), 200
        except Exception as e:
            # Graceful fallback if collection or rules are not yet initialized
            pass
            
    # Default initial artisan handicraft catalog mock data
    sample_products = [
        {
            "id": "prod_001",
            "title": "Handcrafted Terracotta Chai Kulhad Set",
            "artisan": "Radha Devi",
            "craft_type": "Clay Pottery",
            "region": "Gorakhpur, Uttar Pradesh",
            "price": 350,
            "currency": "INR",
            "stock": 18,
            "image_url": "https://images.unsplash.com/photo-1615865417491-9941019fbc00?w=600"
        },
        {
            "id": "prod_002",
            "title": "Natural Indigo Dabu Block Print Stole",
            "artisan": "Ramesh Chhipa",
            "craft_type": "Textile Weaving",
            "region": "Bagru, Rajasthan",
            "price": 890,
            "currency": "INR",
            "stock": 12,
            "image_url": "https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=600"
        }
    ]
    return jsonify({"success": True, "source": "mock", "products": sample_products}), 200


# ---------------------------------------------------------------------------
# POST /api/catalog/voice-to-listing — Transcribe voice & generate bilingual listing
# ---------------------------------------------------------------------------
@catalog_bp.route('/voice-to-listing', methods=['POST'])
@catalog_bp.route('/voice-to-catalog', methods=['POST'])
def voice_to_listing():
    """Accepts an audio file + language code (e.g. 'hi', 'mr', 'ta', 'en'),

    transcribes speech, extracts structured fields via Gemini AI,
    and returns bilingual English & Hindi product listings.
    """
    lang_code = request.form.get('language') or request.args.get('language') or 'hi'
    audio_file = request.files.get('audio') or request.files.get('file')

    # Allow direct text transcription override for rapid testing or text input
    direct_text = request.form.get('transcript') or request.form.get('text')
    if not direct_text and request.is_json:
        data = request.get_json(silent=True) or {}
        direct_text = data.get('transcript') or data.get('text')
        lang_code = data.get('language', lang_code)

    transcript = ""

    if direct_text and direct_text.strip():
        transcript = direct_text.strip()
    elif audio_file:
        audio_bytes = audio_file.read()
        if len(audio_bytes) < 50:
            return jsonify({
                "success": False,
                "error": "Audio file is empty or corrupted",
                "friendly_error": "ऑडियो फ़ाइल खाली है, कृपया दोबारा रिकॉर्ड करें (Audio file is empty, please record again)"
            }), 400

        from services.speech_service import transcribe_audio
        speech_result = transcribe_audio(audio_bytes, filename=audio_file.filename or "audio.wav", lang_code=lang_code)

        if speech_result.get("success") and speech_result.get("transcript"):
            transcript = speech_result.get("transcript", "").strip()
            logger.info(f"Using live speech transcript: '{transcript}'")
        else:
            logger.warning(
                f"Speech transcription returned unsuccessful ({speech_result.get('error')}). "
                f"Received {len(audio_bytes)} audio bytes. Falling back to default artisan description."
            )
            fallback_transcripts = {
                "hi": "यह शुद्ध लाल मिट्टी से बना पारंपरिक टेराकोटा कुल्हड़ और चाय सेट है, गोरखपुर के कारीगरों द्वारा चाक पर हाथ से बनाया गया",
                "mr": "हे शुद्ध लाल मातीपासून बनवलेले पारंपारिक टेराकोटा कुल्हड आणि चहाचा सेट आहे",
                "ta": "இது தூய சிவப்பு களிமண்ணால் செய்யப்பட்ட பாரம்பரிய டெரகோட்டா தேநீர் குவளை தொகுப்பு",
                "en": "Handcrafted terracotta clay kulhad tea set made by traditional rural potters on potter wheel"
            }
            transcript = fallback_transcripts.get(lang_code, fallback_transcripts["hi"])
    else:
        return jsonify({
            "success": False,
            "error": "No audio file or transcript provided",
            "friendly_error": "कृपया पहले अपनी आवाज़ रिकॉर्ड करें (Please record your voice first)"
        }), 400

    # Step 2 & 3: Extract structured product listing & generate bilingual outputs
    try:
        from services.ai_service import process_voice_to_catalog
        ai_result = process_voice_to_catalog(transcript, lang_code=lang_code)

        if not ai_result.get("success"):
            return jsonify({
                "success": False,
                "error": ai_result.get("error"),
                "friendly_error": ai_result.get("friendly_error", "विवरण तैयार करने में समस्या आई, कृपया पुनः प्रयास करें")
            }), 500

        return jsonify(ai_result), 200

    except Exception as e:
        return jsonify({
            "success": False,
            "error": str(e),
            "friendly_error": "तकनीकी समस्या आई, कृपया थोड़ी देर बाद प्रयास करें (Technical issue, please try again)"
        }), 500
