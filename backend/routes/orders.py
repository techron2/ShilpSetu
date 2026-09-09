"""
/api/orders — Full CRUD for ShilpSetu order management.

Status lifecycle:
    pending → confirmed → shipped → delivered → paid

Endpoints:
    POST   /api/orders              — create a new order
    GET    /api/orders              — list orders (filter by buyer_id, artisan_id, status)
    GET    /api/orders/<id>         — get single order
    PUT    /api/orders/<id>         — update order status or fields
"""
import logging
from datetime import datetime, timezone
from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client

logger = logging.getLogger(__name__)

orders_bp = Blueprint('orders', __name__)

VALID_STATUSES = {"pending", "confirmed", "shipped", "delivered", "paid", "cancelled"}


def _serialize_order(doc) -> dict:
    if hasattr(doc, 'to_dict'):
        data = doc.to_dict() or {}
        data['id'] = doc.id
    elif isinstance(doc, dict):
        data = dict(doc)
    else:
        return doc
    for k, v in list(data.items()):
        if hasattr(v, 'isoformat'):
            data[k] = v.isoformat()
    return data


# ---------------------------------------------------------------------------
# POST /api/orders — Create a new order
# ---------------------------------------------------------------------------
@orders_bp.route('', methods=['POST'])
def create_order():
    """Create a new order.

    Request body (JSON):
        product_id       (str, required)
        buyer_id         (str, required)
        artisan_id       (str, required)
        quantity         (int, required)
        total_price      (float, required)
        delivery_address (str, optional)
        buyer_name       (str, optional)
        artisan_name     (str, optional)
        product_title    (str, optional)
        notes            (str, optional)
    """
    data = request.get_json(silent=True) or {}
    required = ['product_id', 'buyer_id', 'artisan_id', 'quantity', 'total_price']
    missing = [f for f in required if f not in data]
    if missing:
        return jsonify({"success": False, "error": f"Missing fields: {missing}"}), 400

    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore not connected"}), 500

    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        doc_ref = db.collection('orders').document()
        order = {
            "id":               doc_ref.id,
            "product_id":       data['product_id'],
            "buyer_id":         data['buyer_id'],
            "artisan_id":       data['artisan_id'],
            "quantity":         int(data['quantity']),
            "total_price":      float(data['total_price']),
            "status":           "pending",
            "delivery_address": data.get('delivery_address', ''),
            "buyer_name":       data.get('buyer_name', ''),
            "artisan_name":     data.get('artisan_name', ''),
            "product_title":    data.get('product_title', ''),
            "notes":            data.get('notes', ''),
            "created_at":       now_iso,
            "updated_at":       now_iso,
            "rfq_id":           data.get('rfq_id', ''),
        }
        doc_ref.set(order)
        logger.info(f"Created order {doc_ref.id} for buyer={data['buyer_id']}")
        return jsonify({"success": True, "source": "firestore", "order": order}), 201

    except Exception as e:
        logger.error(f"Error creating order: {e}", exc_info=True)
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# GET /api/orders — List orders with optional filters
# ---------------------------------------------------------------------------
@orders_bp.route('', methods=['GET'])
def list_orders():
    """List orders, optionally filtered by buyer_id, artisan_id, or status."""
    buyer_id   = request.args.get('buyer_id', '')
    artisan_id = request.args.get('artisan_id', '')
    status     = request.args.get('status', '')
    limit      = request.args.get('limit', default=50, type=int)

    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore not connected"}), 500

    try:
        ref = db.collection('orders')
        # Firestore supports only one inequality filter per query without composite index;
        # We apply multiple equality filters (safe) and sort in Python.
        if buyer_id:
            ref = ref.where('buyer_id', '==', buyer_id)
        elif artisan_id:
            ref = ref.where('artisan_id', '==', artisan_id)

        docs = list(ref.stream())
        orders = [_serialize_order(doc) for doc in docs]

        # Python-side status filter (avoids composite index requirement)
        if status and status in VALID_STATUSES:
            orders = [o for o in orders if o.get('status') == status]

        # Sort by created_at descending
        orders.sort(key=lambda o: o.get('created_at', ''), reverse=True)
        orders = orders[:limit]

        return jsonify({
            "success": True,
            "source": "firestore",
            "count": len(orders),
            "orders": orders
        }), 200

    except Exception as e:
        logger.error(f"Error listing orders: {e}", exc_info=True)
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# GET /api/orders/<id> — Get a single order
# ---------------------------------------------------------------------------
@orders_bp.route('/<order_id>', methods=['GET'])
def get_order(order_id):
    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore not connected"}), 500
    try:
        doc = db.collection('orders').document(order_id).get()
        if not doc.exists:
            return jsonify({"success": False, "error": "Order not found"}), 404
        return jsonify({"success": True, "order": _serialize_order(doc)}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# PUT /api/orders/<id> — Update order status or fields
# ---------------------------------------------------------------------------
@orders_bp.route('/<order_id>', methods=['PUT'])
def update_order(order_id):
    """Update an order's status or other allowed fields.

    Request body (JSON):
        status           (str, optional) — one of VALID_STATUSES
        delivery_address (str, optional)
        notes            (str, optional)
        tracking_number  (str, optional)
        tracking_url     (str, optional)
    """
    data = request.get_json(silent=True) or {}
    allowed = ['status', 'delivery_address', 'notes', 'tracking_number', 'tracking_url',
               'artisan_name', 'buyer_name', 'product_title', 'rating']
    updates = {k: v for k, v in data.items() if k in allowed}

    if not updates:
        return jsonify({"success": False, "error": "No valid fields to update"}), 400

    if 'status' in updates and updates['status'] not in VALID_STATUSES:
        return jsonify({
            "success": False,
            "error": f"Invalid status. Must be one of: {sorted(VALID_STATUSES)}"
        }), 400

    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore not connected"}), 500

    try:
        doc_ref = db.collection('orders').document(order_id)
        snap = doc_ref.get()
        if not snap.exists:
            return jsonify({"success": False, "error": "Order not found"}), 404

        order_data = snap.to_dict()
        artisan_id = order_data.get('artisan_id')

        updates['updated_at'] = datetime.now(timezone.utc).isoformat()
        doc_ref.update(updates)
        updated = _serialize_order(doc_ref.get())

        # Recalculate trust score if status is delivered/cancelled or rating was updated
        if artisan_id and ('status' in updates or 'rating' in updates):
            try:
                from .users import calculate_trust_score
                calculate_trust_score(artisan_id, db=db)
            except Exception as te:
                logger.warning(f"Could not recalculate trust score for {artisan_id}: {te}")

        logger.info(f"Updated order {order_id}: {updates}")
        return jsonify({"success": True, "source": "firestore", "order": updated}), 200

    except Exception as e:
        logger.error(f"Error updating order {order_id}: {e}", exc_info=True)
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# DELETE /api/orders/<id> — Cancel / delete order
# ---------------------------------------------------------------------------
@orders_bp.route('/<order_id>', methods=['DELETE'])
def delete_order(order_id):
    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore not connected"}), 500
    try:
        doc_ref = db.collection('orders').document(order_id)
        if not doc_ref.get().exists:
            return jsonify({"success": False, "error": "Order not found"}), 404
        doc_ref.delete()
        return jsonify({"success": True, "message": f"Order {order_id} deleted"}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
