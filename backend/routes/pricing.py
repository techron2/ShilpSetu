import logging
from flask import Blueprint, jsonify, request
from services.pricing_service import suggest_product_price

logger = logging.getLogger(__name__)

pricing_bp = Blueprint('pricing', __name__)


@pricing_bp.route('/suggest', methods=['POST'])
def suggest_price():
    """Predicts optimal fair-trade e-commerce product price based on craft category,

    material cost, craft size tier, and artisan region.
    """
    try:
        data = request.get_json(silent=True) or {}

        category = data.get('category', 'Pottery')
        material_cost = data.get('material_cost')
        if material_cost is not None:
            try:
                material_cost = float(material_cost)
            except (ValueError, TypeError):
                material_cost = None

        size = data.get('size', 'medium')
        region = data.get('region', 'Uttar Pradesh')

        result = suggest_product_price(
            category=category,
            material_cost=material_cost,
            size=size,
            region=region
        )

        return jsonify(result), 200

    except Exception as e:
        logger.error(f"Error in /api/pricing/suggest: {e}", exc_info=True)
        return jsonify({
            "success": False,
            "error": str(e),
            "friendly_error": "मूल्य अनुमान में समस्या आई (Failed to calculate price suggestion)"
        }), 500
