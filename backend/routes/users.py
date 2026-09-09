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


# ---------------------------------------------------------------------------
# Trust Score Calculation Helper
# ---------------------------------------------------------------------------
def calculate_trust_score(uid: str, db=None) -> dict:
    """
    Computes a weighted trust score:
    - 50% order completion rate: delivered / (delivered + cancelled)
    - 50% average buyer rating (out of 5.0, default 4.8 for new artisans)
    Updates the score on the user document in Firestore.
    """
    if db is None:
        db = get_firestore_client()

    completion_rate = 1.0
    total_orders = 0
    delivered_count = 0
    cancelled_count = 0
    ratings = []

    if db:
        try:
            orders = db.collection('orders').where('artisan_id', '==', uid).stream()
            for o in orders:
                data = o.to_dict()
                total_orders += 1
                status = data.get('status', '').lower()
                if status == 'delivered':
                    delivered_count += 1
                elif status == 'cancelled':
                    cancelled_count += 1
                
                if 'rating' in data and data['rating'] is not None:
                    try:
                        ratings.append(float(data['rating']))
                    except Exception:
                        pass
        except Exception:
            pass

    finished_orders = delivered_count + cancelled_count
    if finished_orders > 0:
        completion_rate = round(delivered_count / finished_orders, 2)
    elif total_orders > 0:
        completion_rate = 0.95
    else:
        completion_rate = 1.0

    avg_rating = round(sum(ratings) / len(ratings), 1) if ratings else 4.8
    # Weighted calculation: Completion rate (scaled to 5.0) * 0.5 + Avg Rating * 0.5
    trust_score = round((completion_rate * 5.0 * 0.5) + (avg_rating * 0.5), 1)

    if trust_score >= 4.7:
        badge = "🌟 Master Artisan"
    elif trust_score >= 4.3:
        badge = "✅ Verified Artisan"
    elif trust_score >= 4.0:
        badge = "🌱 Rising Artisan"
    else:
        badge = "✨ Certified Craftmaker"

    score_data = {
        "uid": uid,
        "trust_score": trust_score,
        "rating": avg_rating,
        "completion_rate": completion_rate,
        "completion_rate_pct": int(completion_rate * 100),
        "total_orders": total_orders,
        "delivered_orders": delivered_count,
        "badge": badge
    }

    # Persist in Firestore
    if db:
        try:
            ref = db.collection('users').document(uid)
            if ref.get().exists:
                ref.update({
                    "trust_score": trust_score,
                    "rating": avg_rating,
                    "completion_rate": completion_rate,
                    "trust_badge": badge
                })
        except Exception:
            pass

    return score_data


# ---------------------------------------------------------------------------
# GET /api/users/<uid>/trust-score — Get or recalculate artisan trust score
# ---------------------------------------------------------------------------
@users_bp.route('/<uid>/trust-score', methods=['GET'])
def get_user_trust_score(uid):
    score = calculate_trust_score(uid)
    return jsonify({"success": True, "data": score}), 200

