from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client

users_bp = Blueprint('users', __name__)

# ---------------------------------------------------------------------------
# Mock fallback user store (keyed by uid)
# ---------------------------------------------------------------------------
_MOCK_USERS = {
    "mock_uid_001": {
        "uid": "mock_uid_001",
        "name": "Radha Devi",
        "email": "radha@example.com",
        "role": "artisan",
        "phone": "+91-9876543210",
        "language_preference": "hi",
        "artisan_cluster": "Gorakhpur Terracotta",
        "region": "Gorakhpur, Uttar Pradesh"
    }
}


# ---------------------------------------------------------------------------
# POST /api/users — Create a user profile document after signup
# ---------------------------------------------------------------------------
@users_bp.route('', methods=['POST'])
def create_user():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    required = ['uid', 'email', 'role']
    missing = [f for f in required if f not in data]
    if missing:
        return jsonify({"success": False, "error": f"Missing fields: {missing}"}), 400

    allowed_roles = ['artisan', 'buyer']
    if data.get('role') not in allowed_roles:
        return jsonify({"success": False, "error": f"role must be one of {allowed_roles}"}), 400

    user = {
        "uid":                 data.get("uid"),
        "name":                data.get("name", ""),
        "email":               data.get("email"),
        "role":                data.get("role"),
        "phone":               data.get("phone", ""),
        "language_preference": data.get("language_preference", "en"),
        "artisan_cluster":     data.get("artisan_cluster", ""),
        "region":              data.get("region", ""),
    }

    db = get_firestore_client()
    if db:
        try:
            db.collection('users').document(user["uid"]).set(user)
            return jsonify({"success": True, "source": "firestore", "user": user}), 201
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500

    _MOCK_USERS[user["uid"]] = user
    return jsonify({"success": True, "source": "mock", "user": user}), 201


# ---------------------------------------------------------------------------
# GET /api/users/<uid> — Read user profile
# ---------------------------------------------------------------------------
@users_bp.route('/<uid>', methods=['GET'])
def get_user(uid):
    db = get_firestore_client()
    if db:
        try:
            doc = db.collection('users').document(uid).get()
            if not doc.exists:
                return jsonify({"success": False, "error": "User not found"}), 404
            return jsonify({"success": True, "source": "firestore",
                            "user": doc.to_dict()}), 200
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500

    user = _MOCK_USERS.get(uid)
    if not user:
        return jsonify({"success": False, "error": "User not found"}), 404
    return jsonify({"success": True, "source": "mock", "user": user}), 200


# ---------------------------------------------------------------------------
# PUT /api/users/<uid> — Update user profile
# ---------------------------------------------------------------------------
@users_bp.route('/<uid>', methods=['PUT'])
def update_user(uid):
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    allowed_fields = ['name', 'phone', 'language_preference', 'artisan_cluster', 'region', 'role']
    updates = {k: v for k, v in data.items() if k in allowed_fields}

    if not updates:
        return jsonify({"success": False, "error": "No valid fields to update"}), 400

    db = get_firestore_client()
    if db:
        try:
            ref = db.collection('users').document(uid)
            if not ref.get().exists:
                return jsonify({"success": False, "error": "User not found"}), 404
            ref.update(updates)
            updated = ref.get().to_dict()
            return jsonify({"success": True, "source": "firestore", "user": updated}), 200
        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500

    if uid not in _MOCK_USERS:
        return jsonify({"success": False, "error": "User not found"}), 404
    _MOCK_USERS[uid].update(updates)
    return jsonify({"success": True, "source": "mock", "user": _MOCK_USERS[uid]}), 200
