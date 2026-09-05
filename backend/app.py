import os
import logging
from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv

# Load environment variables from .env if present
load_dotenv()

# Configure basic logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("shilpsetu_backend")

def create_app():
    """Application factory for ShilpSetu Flask Backend."""
    app = Flask(__name__)
    
    # Enable Cross-Origin Resource Sharing (CORS) for mobile/web frontends
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    
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
