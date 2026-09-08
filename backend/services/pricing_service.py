import os
import logging
import joblib
import pandas as pd

logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_PATH = os.path.join(BASE_DIR, "services", "price_model.pkl")

_cached_model = None


def get_price_model():
    """Loads or retrieves the cached scikit-learn pricing pipeline."""
    global _cached_model
    if _cached_model is None:
        if os.path.exists(MODEL_PATH):
            try:
                _cached_model = joblib.load(MODEL_PATH)
                logger.info(f"Loaded pricing model from {MODEL_PATH}")
            except Exception as e:
                logger.error(f"Failed to load price model ({e})")
                _cached_model = None
        else:
            logger.warning(f"Price model file not found at {MODEL_PATH}")
    return _cached_model


def _generate_explanation(category: str, material_cost: float, size: str, region: str, price: int) -> str:
    """Generates a plain-language, culturally grounded explanation for the suggested price."""
    category_names_hi = {
        "Pottery": "मिट्टी के शिल्प (Pottery)",
        "Textiles": "हथकरघा वस्त्र (Textiles)",
        "Painting": "पारंपरिक चित्रकला (Painting)",
        "Metal Craft": "धातु शिल्प (Metal Craft)",
        "Wood Craft": "काष्ठ शिल्प (Wood Craft)",
        "Jewellery": "हस्तनिर्मित आभूषण (Jewellery)",
        "Accessories": "सहायक वस्तुएं (Accessories)",
        "Other": "हस्तशिल्प उत्पाद"
    }
    cat_hi = category_names_hi.get(category, f"{category} शिल्प")

    size_label = {"small": "छोटे (Small)", "medium": "मध्यम (Medium)", "large": "बड़े (Large)"}.get(size, size)

    return (
        f"{region} में {cat_hi} के {size_label} आकार, ₹{int(material_cost)} की सामग्री लागत "
        f"और कुशल कारीगरी के समय के आधार पर ₹{price} का निष्पक्ष मूल्य निर्धारित किया गया है। "
        f"(Based on similar {size} handcrafted {category} in {region} with ₹{int(material_cost)} material cost and fair artisan labor margins.)"
    )


def suggest_product_price(
    category: str = "Pottery",
    material_cost: float = None,
    size: str = "medium",
    region: str = "Uttar Pradesh"
) -> dict:
    """Predicts fair-trade e-commerce product price and returns price range + explanation."""
    valid_categories = ["Pottery", "Textiles", "Painting", "Metal Craft", "Wood Craft", "Jewellery", "Accessories", "Other"]
    if category not in valid_categories:
        category = "Other"

    size = str(size).lower().strip()
    if size not in ["small", "medium", "large"]:
        size = "medium"

    region = str(region).strip() if region else "Uttar Pradesh"

    # Default realistic material cost if artisan did not provide one
    if material_cost is None or material_cost <= 0:
        default_costs = {
            "Pottery": 60.0,
            "Textiles": 280.0,
            "Painting": 140.0,
            "Metal Craft": 450.0,
            "Wood Craft": 250.0,
            "Jewellery": 160.0,
            "Accessories": 120.0,
            "Other": 150.0
        }
        material_cost = default_costs.get(category, 150.0)

    model = get_price_model()

    if model is not None:
        try:
            # Prepare input dataframe matching model columns
            input_df = pd.DataFrame([{
                "category": category if category != "Other" else "Pottery",
                "material_cost": float(material_cost),
                "size": size,
                "region": region
            }])

            predicted_raw = model.predict(input_df)[0]
            suggested_price = int(round(predicted_raw / 10.0) * 10)
        except Exception as e:
            logger.warning(f"Model prediction error ({e}), using rule-based calculation.")
            suggested_price = int(round(material_cost * 3.2 / 10.0) * 10)
    else:
        # Graceful fallback heuristic if model file isn't present
        multipliers = {
            "Painting": 4.5,
            "Pottery": 3.6,
            "Jewellery": 3.8,
            "Metal Craft": 3.0,
            "Wood Craft": 3.0,
            "Textiles": 2.8,
            "Accessories": 2.5,
            "Other": 2.8
        }
        mult = multipliers.get(category, 2.8)
        size_mult = {"small": 0.9, "medium": 1.3, "large": 2.0}.get(size, 1.3)
        suggested_price = int(round((material_cost * mult * size_mult) / 10.0) * 10)

    # Floor at 1.3x material cost to protect artisan livelihood
    suggested_price = max(int(material_cost * 1.3), suggested_price)

    # Calculate optimal price range
    min_price = max(int(material_cost * 1.25), int(round(suggested_price * 0.86 / 10.0) * 10))
    max_price = int(round(suggested_price * 1.18 / 10.0) * 10)

    explanation = _generate_explanation(category, material_cost, size, region, suggested_price)

    return {
        "success": True,
        "suggested_price": suggested_price,
        "price_range_min": min_price,
        "price_range_max": max_price,
        "currency": "INR",
        "category": category,
        "size": size,
        "region": region,
        "material_cost": material_cost,
        "explanation": explanation
    }
