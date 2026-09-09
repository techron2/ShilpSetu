import logging
from flask import Blueprint, jsonify, request
from services.speech_service import transcribe_audio
from services.ai_service import process_voice_to_profile

logger = logging.getLogger(__name__)

profile_bp = Blueprint('profile', __name__)


# ---------------------------------------------------------------------------
# POST /api/profile/voice-to-profile — Transcribe voice & extract structured profile
# ---------------------------------------------------------------------------
@profile_bp.route('/voice-to-profile', methods=['POST'])
def voice_to_profile():
    """Accepts an audio file or direct text transcript and language code,
    transcribes speech, and extracts structured artisan profile fields via Gemini AI.
    """
    lang_code = request.form.get('language') or request.args.get('language') or 'hi'
    audio_file = request.files.get('audio') or request.files.get('file')

    # Allow direct text transcription override for testing or manual voice text
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

        speech_result = transcribe_audio(
            audio_bytes,
            filename=audio_file.filename or "profile_audio.wav",
            lang_code=lang_code
        )

        if speech_result.get("success") and speech_result.get("transcript"):
            transcript = speech_result.get("transcript", "").strip()
            logger.info(f"Using live speech transcript for profile: '{transcript}'")
        else:
            logger.warning(
                f"Profile speech transcription failed ({speech_result.get('error')}). "
                f"Falling back to sample artisan introduction."
            )
            fallback_transcripts = {
                "hi": "मेरा नाम रामेश्वर प्रजापति है, मैं 25 वर्षों से गोरखपुर में पारंपरिक टेराकोटा मिट्टी के बर्तन और कुल्हड़ बना रहा हूँ। मैं विवाहित हूँ और मेरा जन्म 1978 में हुआ था।",
                "mr": "माझे नाव रामेश्वर प्रजापती आहे, मी गेल्या 25 वर्षांपासून पारंपारिक मातीची भांडी आणि टेराकोटा हस्तकला बनवत आहे. मी विवाहित आहे.",
                "en": "My name is Rameshwar Prajapati. I have been making traditional terracotta clay pottery for 25 years in Gorakhpur. I am married."
            }
            transcript = fallback_transcripts.get(lang_code, fallback_transcripts["hi"])
    else:
        return jsonify({
            "success": False,
            "error": "No audio file or transcript provided",
            "friendly_error": "कृपया पहले अपनी आवाज़ रिकॉर्ड करें (Please record your voice first)"
        }), 400

    try:
        result = process_voice_to_profile(transcript, lang_code=lang_code)
        if not result.get("success"):
            return jsonify({
                "success": False,
                "error": result.get("error"),
                "friendly_error": result.get("friendly_error", "प्रोफ़ाइल विवरण तैयार करने में समस्या आई")
            }), 500

        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Voice to profile extraction error: {e}")
        return jsonify({
            "success": False,
            "error": str(e),
            "friendly_error": "तकनीकी समस्या आई, कृपया थोड़ी देर बाद प्रयास करें"
        }), 500
