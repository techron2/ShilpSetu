import os
import json
import logging
from config import SERVICE_ACCOUNT_KEY_PATH

logger = logging.getLogger(__name__)

_firebase_app = None
_firestore_db = None

def init_firebase(app=None):
    """Initializes Firebase Admin SDK using the local service account key file.

    Expects the private key file at /backend/serviceAccountKey.json.
    Initializes using credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH) with no CLI or env-only auth.
    If the file is not yet downloaded, logs a clear notification and keeps
    the server running with mock/fallback services.
    """
    global _firebase_app, _firestore_db

    if not os.path.exists(SERVICE_ACCOUNT_KEY_PATH):
        logger.info(
            f"Firebase service account key not found at '{SERVICE_ACCOUNT_KEY_PATH}'. "
            "Place your downloaded serviceAccountKey.json in the /backend directory. "
            "Backend is currently running with mock/fallback services."
        )
        return None

    try:
        with open(SERVICE_ACCOUNT_KEY_PATH, 'r', encoding='utf-8') as f:
            data = json.load(f)
            # Check if this is still the placeholder file
            if "PASTE_YOUR_FIREBASE_PRIVATE_KEY_HERE" in str(data) or data.get("project_id") == "shilpsetu-placeholder-id":
                logger.info("Firebase service account is currently a placeholder. Backend running in placeholder mode.")
                return None

        import firebase_admin
        from firebase_admin import credentials, firestore

        if not firebase_admin._apps:
            cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info(f"Firebase Admin SDK successfully initialized from '{SERVICE_ACCOUNT_KEY_PATH}'.")

        _firestore_db = firestore.client()
        return _firebase_app
    except Exception as e:
        logger.warning(f"Could not initialize Firebase Admin SDK from '{SERVICE_ACCOUNT_KEY_PATH}' ({e}). Falling back to local mode.")
        return None

def get_firestore_client():
    """Returns the Firestore DB client if initialized, or None."""
    global _firestore_db
    return _firestore_db

def get_firebase_app():
    """Returns the initialized Firebase App instance, or None."""
    global _firebase_app
    return _firebase_app
