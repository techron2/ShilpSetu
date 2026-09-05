from flask import Blueprint, jsonify

health_bp = Blueprint('health', __name__)

@health_bp.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint to verify backend service status.
    
    Returns:
        JSON response with {"status": "ok"} and HTTP status 200.
    """
    return jsonify({"status": "ok"}), 200
