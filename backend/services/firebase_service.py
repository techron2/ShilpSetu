import os
import json
import logging

logger = logging.getLogger(__name__)

_firebase_app = None
_firestore_db = None

def init_firebase(app=None):
    """Initializes Firebase Admin SDK safely.
    
    If real serviceAccountKey credentials are provided in the environment or file,
    Firebase Admin is initialized. If the credentials file is absent or contains
    the placeholder template, the server gracefully logs a notification and continues
    running in local/mock mode without crashing.
    """
    global _firebase_app, _firestore_db
    
    credentials_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'serviceAccountKey.json')
    backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    full_cred_path = os.path.join(backend_dir, credentials_path) if not os.path.isabs(credentials_path) else credentials_path
    
    if not os.path.exists(full_cred_path):
        logger.info(f"Firebase credentials not found at '{full_cred_path}'. Running with mock/fallback services.")
        return None
        
    try:
        with open(full_cred_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            # Check if this is still the placeholder file
            if "PASTE_YOUR_FIREBASE_PRIVATE_KEY_HERE" in str(data) or data.get("project_id") == "shilpsetu-placeholder-id":
                logger.info("Firebase service account is currently a placeholder. Backend running in placeholder mode.")
                return None
                
        import firebase_admin
        from firebase_admin import credentials, firestore
        
        if not firebase_admin._apps:
            cred = credentials.Certificate(full_cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK successfully initialized.")
            
        _firestore_db = firestore.client()
        return _firebase_app
    except Exception as e:
        logger.warning(f"Could not initialize Firebase Admin SDK ({e}). Falling back to local mode.")
        return None

def get_firestore_client():
    """Returns the Firestore DB client if initialized, or None."""
    global _firestore_db
    return _firestore_db
