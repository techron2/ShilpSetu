import os
import logging
from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv

# Load environment variables from backend/.env explicitly
env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
load_dotenv(dotenv_path=env_path)

# Configure basic logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("shilpsetu_backend")

# Startup verification for GEMINI_API_KEY
gemini_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
if gemini_key:
    masked_key = f"{gemini_key[:4]}...{gemini_key[-4:]}" if len(gemini_key) >= 8 else "***"
    print(f"[STARTUP] GEMINI_API_KEY loaded: {masked_key} (len={len(gemini_key)})")
    logger.info(f"[STARTUP] GEMINI_API_KEY loaded: {masked_key}")
else:
    print("[STARTUP] GEMINI_API_KEY: NOT SET")
    logger.warning("[STARTUP] GEMINI_API_KEY not found in environment (.env). Fallback modes will be active.")

def create_app():
    """Application factory for ShilpSetu Flask Backend."""
    app = Flask(__name__)
    
    # Enable Cross-Origin Resource Sharing (CORS) for mobile/web frontends
    CORS(app, resources={r"/*": {"origins": "*"}})
    
    # Static files serving for enhanced artisan images
    from flask import send_from_directory
    static_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
    enhanced_dir = os.path.join(static_dir, "enhanced")
    os.makedirs(enhanced_dir, exist_ok=True)

    @app.route("/static/enhanced/<path:filename>")
    def serve_enhanced_image(filename):
        return send_from_directory(enhanced_dir, filename)
    
    # Initialize Firebase Admin SDK (with placeholder handling)
    from services.firebase_service import init_firebase
    init_firebase(app)
    
    # Register API blueprints
    from routes import register_routes
    register_routes(app)
    
    @app.route("/")
    def index():
        return {
            "app": "ShilpSetu Backend API",
            "version": "1.0.0",
            "health_check": "/api/health",
            "message": "AI-Driven Market Linkage and Smart Cataloging for Marginalized Artisans"
        }, 200

    return app

app = create_app()

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_ENV", "development") == "development"
    logger.info(f"Starting ShilpSetu backend server on port {port} (debug={debug})...")
    app.run(host="0.0.0.0", port=port, debug=debug)
