from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client

catalog_bp = Blueprint('catalog', __name__)

@catalog_bp.route('', methods=['GET'])
def get_artisan_catalog():
    """Returns placeholder artisan catalog items or fetched from Firestore if configured."""
    db = get_firestore_client()
    if db:
        try:
            # When real Firebase is connected, fetch from 'products' collection
            products_ref = db.collection('products').stream()
            products = [doc.to_dict() | {"id": doc.id} for doc in products_ref]
            return jsonify({"success": True, "source": "firestore", "products": products}), 200
        except Exception as e:
            # Graceful fallback if collection or rules are not yet initialized
            pass
            
    # Default initial artisan handicraft catalog mock data
    sample_products = [
        {
            "id": "prod_001",
            "title": "Handcrafted Terracotta Chai Kulhad Set",
            "artisan": "Radha Devi",
            "craft_type": "Clay Pottery",
            "region": "Gorakhpur, Uttar Pradesh",
            "price": 350,
            "currency": "INR",
            "stock": 18,
            "image_url": "https://images.unsplash.com/photo-1615865417491-9941019fbc00?w=600"
        },
        {
            "id": "prod_002",
            "title": "Natural Indigo Dabu Block Print Stole",
            "artisan": "Ramesh Chhipa",
            "craft_type": "Textile Weaving",
            "region": "Bagru, Rajasthan",
            "price": 890,
            "currency": "INR",
            "stock": 12,
            "image_url": "https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=600"
        }
    ]
    return jsonify({"success": True, "source": "mock", "products": sample_products}), 200
