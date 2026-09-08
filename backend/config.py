import os

# Backend root directory: c:\Users\MY\OneDrive\Desktop\ShilpSetu\backend
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Exact filename and absolute path expected for Firebase Admin SDK private key
SERVICE_ACCOUNT_KEY_FILE = "serviceAccountKey.json"
SERVICE_ACCOUNT_KEY_PATH = os.path.join(BASE_DIR, SERVICE_ACCOUNT_KEY_FILE)

PORT = int(os.getenv("PORT", 5000))
DEBUG = os.getenv("FLASK_ENV", "development") == "development"
