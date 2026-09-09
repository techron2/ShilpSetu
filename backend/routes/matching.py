"""
POST /api/matching/buyer-supplier
----------------------------------
Given a buyer's requirement {category, quantity, budget, region},
compute cosine similarity between the requirement and all available
products/artisan profiles to return a ranked list of best-matching artisans.

Algorithm:
  1. Fetch all products from Firestore.
  2. Fetch artisan user profiles (role=artisan) from Firestore.
  3. Build a combined "feature string" per product from title, description,
     category, region, and artisan cluster fields.
  4. Build a query string from the buyer requirement.
  5. TF-IDF vectorise all strings together.
  6. Cosine-similarity rank, return top-5 with scores.

Upgrade path:
  Replace TF-IDF with Gemini text-embedding-004 vectors for true semantic
  similarity. The rest of the pipeline (cosine similarity, ranking) stays
  identical.
"""
import logging
from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client

logger = logging.getLogger(__name__)

matching_bp = Blueprint('matching', __name__)


def _build_feature_string(product: dict, artisan_profile: dict | None) -> str:
    """Combine product + artisan fields into a single feature string."""
    parts = [
        product.get('title', ''),
        product.get('description', ''),
        product.get('category', ''),
        product.get('region', ''),
        product.get('artisan_cluster', ''),
    ]
    if artisan_profile:
        parts += [
            artisan_profile.get('artisan_cluster', ''),
            artisan_profile.get('region', ''),
            artisan_profile.get('name', ''),
        ]
    return ' '.join(filter(None, parts)).lower()


@matching_bp.route('/buyer-supplier', methods=['POST'])
def match_buyer_supplier():
    """Rank artisans/products against a buyer requirement via cosine similarity.

    Request body (JSON):
        category  (str)  — craft category, e.g. "Textiles"
        quantity  (int)  — number of units needed
        budget    (float)— max total budget in INR
        region    (str)  — preferred region/state, e.g. "Rajasthan"

    Returns:
        ranked list of up to 5 best-matching artisans with their top product.
    """
    data = request.get_json(silent=True) or {}
    category = data.get('category', '')
    quantity = data.get('quantity', 1)
    budget   = data.get('budget', 0)
    region   = data.get('region', '')

    if not any([category, region]):
        return jsonify({
            "success": False,
            "error": "Provide at least one of: category, region"
        }), 400

    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore not connected"}), 500

    try:
        # ── 1. Fetch products ───────────────────────────────────────────────
        products_docs = list(db.collection('products').stream())
        products = []
        for doc in products_docs:
            p = doc.to_dict() or {}
            p['id'] = doc.id
            # Serialize timestamps
            for k, v in list(p.items()):
                if hasattr(v, 'isoformat'):
                    p[k] = v.isoformat()
            products.append(p)

        if not products:
            return jsonify({
                "success": True,
                "matches": [],
                "message": "No products available yet. Add some products first."
            }), 200

        # ── 2. Fetch artisan profiles ────────────────────────────────────────
        artisan_docs = list(db.collection('users').where('role', '==', 'artisan').stream())
        artisans_by_id = {}
        for doc in artisan_docs:
            a = doc.to_dict() or {}
            artisans_by_id[doc.id] = a

        # ── 3. Build feature strings ─────────────────────────────────────────
        feature_strings = []
        for p in products:
            artisan_profile = artisans_by_id.get(p.get('artisan_id', ''))
            feature_strings.append(_build_feature_string(p, artisan_profile))

        # Buyer query string
        unit_price = float(budget) / max(int(quantity), 1) if budget else 0
        query_string = f"{category} {region} quantity {quantity} price {unit_price:.0f}".lower().strip()

        # ── 4. TF-IDF vectorisation + cosine similarity ──────────────────────
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.metrics.pairwise import cosine_similarity
        import numpy as np

        all_strings = feature_strings + [query_string]
        vectorizer = TfidfVectorizer(ngram_range=(1, 2), min_df=1)
        tfidf_matrix = vectorizer.fit_transform(all_strings)

        query_vec = tfidf_matrix[-1]           # last row = buyer query
        product_vecs = tfidf_matrix[:-1]       # all product rows

        scores = cosine_similarity(query_vec, product_vecs).flatten()

        # ── 5. Price-budget filter + ranking ─────────────────────────────────
        ranked_indices = np.argsort(scores)[::-1]   # descending

        matches = []
        seen_artisans = set()
        for idx in ranked_indices:
            if len(matches) >= 5:
                break

            p = products[idx]
            score = float(scores[idx])

            # Optional budget filter: skip products whose per-unit price exceeds
            # the buyer's per-unit budget by more than 50%
            if unit_price > 0:
                product_price = float(p.get('price', 0))
                if product_price > unit_price * 1.5:
                    continue

            artisan_id = p.get('artisan_id', '')
            artisan = artisans_by_id.get(artisan_id, {})

            match_obj = {
                "rank": len(matches) + 1,
                "similarity_score": round(score, 4),
                "product": p,
                "artisan": {
                    "id":             artisan_id,
                    "name":           artisan.get('name', 'Unknown Artisan'),
                    "region":         artisan.get('region', p.get('region', '')),
                    "artisan_cluster": artisan.get('artisan_cluster', ''),
                    "rating":         artisan.get('rating', p.get('rating', 4.2)),
                    "review_count":   artisan.get('review_count', p.get('review_count', 0)),
                    "email":          artisan.get('email', ''),
                }
            }
            matches.append(match_obj)
            seen_artisans.add(artisan_id)

        return jsonify({
            "success": True,
            "requirement": {
                "category": category,
                "quantity": quantity,
                "budget":   budget,
                "region":   region,
            },
            "total_products_evaluated": len(products),
            "matches": matches,
        }), 200

    except ImportError:
        logger.error("scikit-learn not installed. Run: pip install scikit-learn")
        return jsonify({
            "success": False,
            "error": "scikit-learn is required for matching. Run: pip install scikit-learn"
        }), 500
    except Exception as e:
        logger.error(f"Error in /api/matching/buyer-supplier: {e}", exc_info=True)
        return jsonify({"success": False, "error": str(e)}), 500
