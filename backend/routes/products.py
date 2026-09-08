from datetime import datetime, timezone
from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client

products_bp = Blueprint('products', __name__)


def _serialize_doc(doc):
    """Serialize a Firestore DocumentSnapshot into a clean JSON-ready dictionary."""
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
# POST /api/products — Create a product in Firestore
# ---------------------------------------------------------------------------
@products_bp.route('', methods=['POST'])
def create_product():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    required = ['artisan_id', 'title', 'price', 'stock_quantity']
    missing = [f for f in required if f not in data]
    if missing:
        return jsonify({"success": False, "error": f"Missing fields: {missing}"}), 400

    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore database is not connected. Check backend serviceAccountKey.json"}), 500

    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        doc_ref = db.collection('products').document()
        product = {
            "id":             doc_ref.id,
            "artisan_id":     data.get("artisan_id"),
            "title":          data.get("title"),
            "description":    data.get("description", ""),
            "image_url":      data.get("image_url", ""),
            "price":          float(data.get("price", 0)),
            "stock_quantity": int(data.get("stock_quantity", 0)),
            "category":       data.get("category", "Uncategorized"),
            "created_at":     now_iso,
        }
        doc_ref.set(product)
        return jsonify({"success": True, "source": "firestore", "product": product}), 201
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# GET /api/products — List all products from Firestore (optionally filter by artisan_id)
# ---------------------------------------------------------------------------
@products_bp.route('', methods=['GET'])
def list_products():
    artisan_id = request.args.get('artisan_id')

    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore database is not connected. Check backend serviceAccountKey.json"}), 500

    try:
        query = db.collection('products')
        if artisan_id:
            query = query.where('artisan_id', '==', artisan_id)
        docs = query.stream()
        products = [_serialize_doc(doc) for doc in docs]
        # Sort by created_at descending (newest first)
        products.sort(key=lambda p: str(p.get("created_at", "")), reverse=True)
        return jsonify({"success": True, "source": "firestore", "products": products}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# POST /api/products/enhance-image — Auto background removal + OpenCV contrast + 1:1 resize
# ---------------------------------------------------------------------------
@products_bp.route('/enhance-image', methods=['POST'])
def enhance_image_endpoint():
    file = request.files.get('image') or request.files.get('file')
    if not file:
        return jsonify({
            "success": False,
            "error": "No image file provided in form-data ('image' or 'file')",
            "friendly_error": "कृपया उत्पाद की फोटो चुनें (Please select a product photo)"
        }), 400

    try:
        image_bytes = file.read()
        if len(image_bytes) == 0:
            return jsonify({
                "success": False,
                "error": "Empty file received",
                "friendly_error": "फोटो खाली है, कृपया दूसरी फोटो चुनें (File is empty, please select another)"
            }), 400

        from services.image_service import enhance_product_image
        result = enhance_product_image(image_bytes)
        status_code = 200 if result.get("success") else 500
        return jsonify(result), status_code
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# GET /api/products/<id> — Get single product from Firestore
# ---------------------------------------------------------------------------
@products_bp.route('/<product_id>', methods=['GET'])
def get_product(product_id):
    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore database is not connected. Check backend serviceAccountKey.json"}), 500

    try:
        doc = db.collection('products').document(product_id).get()
        if not doc.exists:
            return jsonify({"success": False, "error": "Product not found"}), 404
        return jsonify({"success": True, "source": "firestore", "product": _serialize_doc(doc)}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# PUT /api/products/<id> — Update a product in Firestore
# ---------------------------------------------------------------------------
@products_bp.route('/<product_id>', methods=['PUT'])
def update_product(product_id):
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"success": False, "error": "Request body must be JSON"}), 400

    allowed_fields = ['title', 'description', 'image_url', 'price', 'stock_quantity', 'category']
    updates = {k: v for k, v in data.items() if k in allowed_fields}

    if not updates:
        return jsonify({"success": False, "error": "No valid fields to update"}), 400

    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore database is not connected. Check backend serviceAccountKey.json"}), 500

    try:
        doc_ref = db.collection('products').document(product_id)
        if not doc_ref.get().exists:
            return jsonify({"success": False, "error": "Product not found"}), 404
        doc_ref.update(updates)
        updated_doc = doc_ref.get()
        return jsonify({"success": True, "source": "firestore", "product": _serialize_doc(updated_doc)}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# DELETE /api/products/<id> — Delete a product from Firestore
# ---------------------------------------------------------------------------
@products_bp.route('/<product_id>', methods=['DELETE'])
def delete_product(product_id):
    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore database is not connected. Check backend serviceAccountKey.json"}), 500

    try:
        doc_ref = db.collection('products').document(product_id)
        if not doc_ref.get().exists:
            return jsonify({"success": False, "error": "Product not found"}), 404
        doc_ref.delete()
        return jsonify({"success": True, "message": f"Product {product_id} deleted"}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
