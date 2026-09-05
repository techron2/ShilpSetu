from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client

orders_bp = Blueprint('orders', __name__)

@orders_bp.route('', methods=['GET'])
def get_artisan_orders():
    """Returns placeholder artisan order list or fetched from Firestore if configured."""
    db = get_firestore_client()
    if db:
        try:
            orders_ref = db.collection('orders').stream()
            orders = [doc.to_dict() | {"id": doc.id} for doc in orders_ref]
            return jsonify({"success": True, "source": "firestore", "orders": orders}), 200
        except Exception:
            pass

    # Sample starter orders for low-digital-literacy visual display
    sample_orders = [
        {
            "order_id": "ORD-7821",
            "item_name": "Terracotta Chai Kulhad Set (6 pcs)",
            "buyer_name": "Priya Sharma (Delhi)",
            "amount": 350,
            "status": "Packed - Pickup Tomorrow",
            "status_code": "ready_for_pickup",
            "date": "2026-09-05"
        },
        {
            "order_id": "ORD-7819",
            "item_name": "Dabu Block Print Stole",
            "buyer_name": "Ananya Roy (Bengaluru)",
            "amount": 890,
            "status": "In Transit via India Post",
            "status_code": "in_transit",
            "date": "2026-09-03"
        }
    ]
    return jsonify({"success": True, "source": "mock", "orders": sample_orders}), 200
