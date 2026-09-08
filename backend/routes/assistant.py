import logging
from flask import Blueprint, jsonify, request
from services.assistant_service import ask_business_assistant

logger = logging.getLogger(__name__)

assistant_bp = Blueprint('assistant', __name__)


@assistant_bp.route('/ask', methods=['POST'])
def ask_assistant_endpoint():
    """Accepts free-text artisan business questions and returns empathetic,

    actionable advice from the Gemini AI Business Counselor.
    """
    try:
        data = request.get_json(silent=True) or {}

        artisan_id = data.get('artisan_id', 'artisan_001')
        question = data.get('question') or data.get('prompt') or data.get('message')
        language = data.get('language', 'hi')

        if not question or not str(question).strip():
            return jsonify({
                "success": False,
                "error": "Missing question in request body",
                "friendly_error": "कृपया अपना सवाल पूछें (Please provide your question)"
            }), 400

        result = ask_business_assistant(
            artisan_id=artisan_id,
            question=str(question),
            language=language
        )

        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Error in /api/assistant/ask: {e}", exc_info=True)
        return jsonify({
            "success": False,
            "error": str(e),
            "friendly_error": "व्यापार सहायक से उत्तर प्राप्त करने में समस्या आई (Assistant encountered an error)"
        }), 500
