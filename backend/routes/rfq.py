"""
POST /api/rfq
--------------
Accepts free-text buyer requirements and uses the Gemini API to parse them
into a structured RFQ (Request for Quotation) object, then saves it to
Firestore "rfqs" collection.

Example input:
    "I need 200 cotton sarees for a retail chain by next month, budget around ₹50,000"

Example output (Gemini-structured):
    {
        "category": "Textiles",
        "quantity": 200,
        "target_price": 250,
        "deadline": "2026-10-08",
        "specifications": "100% cotton, saree, retail-quality",
        "description": "200 cotton sarees for a retail chain"
    }
"""
import json
import logging
import os
import re
from datetime import datetime, timezone
from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client

logger = logging.getLogger(__name__)

rfq_bp = Blueprint('rfq', __name__)

_CRAFT_CATEGORIES = [
    "Textiles", "Pottery", "Jewelry", "Woodwork", "Leather",
    "Painting", "Embroidery", "Metalwork", "Stonework", "Basketry", "Other"
]


def _gemini_parse_rfq(requirement_text: str) -> dict:
    """Send the buyer requirement text to Gemini and return a structured dict."""
    from google import genai  # type: ignore

    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY not set in environment")

    client = genai.Client(api_key=api_key)

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    categories_str = ", ".join(_CRAFT_CATEGORIES)

    prompt = f"""You are a procurement specialist for Indian handicrafts. Parse the buyer's requirement below into a structured JSON RFQ (Request for Quotation).

Today's date: {today}
Available categories: {categories_str}

Buyer requirement: "{requirement_text}"

Return ONLY a valid JSON object with exactly these fields:
{{
  "category": "<one of: {categories_str}>",
  "quantity": <integer number of units>,
  "target_price": <float, per-unit price in INR — estimate if not stated>,
  "deadline": "<ISO date string YYYY-MM-DD — estimate if not stated>",
  "specifications": "<comma-separated key specs like material, finish, size>",
  "description": "<clean 1-2 sentence summary of the requirement>"
}}

Rules:
- If quantity is not stated, use 1.
- If deadline is not stated, assume 30 days from today.
- If per-unit price is not stated but total budget is given, divide by quantity.
- If price is completely unknown, estimate based on typical Indian handicraft market rates.
- Return ONLY the JSON object, no markdown, no explanation."""

    response = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=prompt
    )
    raw = response.text.strip()
    # Strip markdown code fences if present
    raw = re.sub(r'^```(?:json)?\s*', '', raw, flags=re.MULTILINE)
    raw = re.sub(r'\s*```$', '', raw, flags=re.MULTILINE)
    raw = raw.strip()
    return json.loads(raw)


def _fallback_parse_rfq(requirement_text: str) -> dict:
    """Simple regex/keyword fallback if Gemini is unavailable."""
    text = requirement_text.lower()
    # Detect quantity: look for numbers near "pieces", "pcs", "units", "sarees", etc.
    qty_match = re.search(r'(\d+)\s*(?:pieces?|pcs?|units?|nos?|items?|pairs?|sets?)', text)
    quantity = int(qty_match.group(1)) if qty_match else 1

    # Detect budget
    budget_match = re.search(r'(?:rs\.?|inr|₹)\s*([\d,]+)', text)
    total_budget = float(budget_match.group(1).replace(',', '')) if budget_match else 0
    target_price = round(total_budget / quantity, 2) if total_budget and quantity else 0.0

    # Detect category
    category = "Other"
    for cat in _CRAFT_CATEGORIES:
        if cat.lower() in text:
            category = cat
            break

    from datetime import timedelta
    deadline = (datetime.now(timezone.utc) + timedelta(days=30)).strftime("%Y-%m-%d")

    return {
        "category": category,
        "quantity": quantity,
        "target_price": target_price,
        "deadline": deadline,
        "specifications": "As specified by buyer",
        "description": requirement_text[:200],
    }


@rfq_bp.route('', methods=['POST'])
def create_rfq():
    """Parse buyer free-text into a structured RFQ and save to Firestore.

    Request body (JSON):
        buyer_id         (str, required)  — Firebase UID of the buyer
        requirement_text (str, required)  — free text description of the requirement
        language         (str, optional)  — 'en' or 'hi' (default 'en')

    Returns:
        The structured RFQ object with its Firestore document ID.
    """
    data = request.get_json(silent=True) or {}
    buyer_id = data.get('buyer_id', '').strip()
    requirement_text = (data.get('requirement_text') or data.get('text') or '').strip()

    if not buyer_id:
        return jsonify({"success": False, "error": "buyer_id is required"}), 400
    if not requirement_text:
        return jsonify({"success": False, "error": "requirement_text is required"}), 400

    # ── Parse via Gemini (with fallback) ─────────────────────────────────────
    structured = None
    ai_used = True
    try:
        structured = _gemini_parse_rfq(requirement_text)
        logger.info(f"Gemini parsed RFQ for buyer {buyer_id}: {structured}")
    except Exception as e:
        logger.warning(f"Gemini RFQ parsing failed ({e}), using fallback")
        ai_used = False
        structured = _fallback_parse_rfq(requirement_text)

    # ── Save to Firestore ─────────────────────────────────────────────────────
    db = get_firestore_client()
    if not db:
        # Return the structured object even without Firestore
        return jsonify({
            "success": True,
            "source": "no_db",
            "ai_structured": ai_used,
            "rfq": {**structured, "id": "offline", "buyer_id": buyer_id,
                    "requirement_text": requirement_text, "status": "open"}
        }), 200

    try:
        now_iso = datetime.now(timezone.utc).isoformat()
        doc_ref = db.collection('rfqs').document()
        rfq_doc = {
            "id":               doc_ref.id,
            "buyer_id":         buyer_id,
            "requirement_text": requirement_text,
            "status":           "open",
            "created_at":       now_iso,
            "ai_parsed":        ai_used,
            **structured,
        }
        doc_ref.set(rfq_doc)

        return jsonify({
            "success": True,
            "source": "firestore",
            "ai_structured": ai_used,
            "rfq": rfq_doc,
        }), 201

    except Exception as e:
        logger.error(f"Error saving RFQ to Firestore: {e}", exc_info=True)
        return jsonify({"success": False, "error": str(e)}), 500


@rfq_bp.route('', methods=['GET'])
def list_rfqs():
    """List RFQs filtered by buyer_id or status."""
    buyer_id = request.args.get('buyer_id', '')
    status   = request.args.get('status', '')

    db = get_firestore_client()
    if not db:
        return jsonify({"success": False, "error": "Firestore not connected"}), 500

    try:
        ref = db.collection('rfqs')
        if buyer_id:
            ref = ref.where('buyer_id', '==', buyer_id)
        if status:
            ref = ref.where('status', '==', status)
        docs = list(ref.stream())
        rfqs = []
        for doc in docs:
            r = doc.to_dict() or {}
            r['id'] = doc.id
            for k, v in list(r.items()):
                if hasattr(v, 'isoformat'):
                    r[k] = v.isoformat()
            rfqs.append(r)
        rfqs.sort(key=lambda x: x.get('created_at', ''), reverse=True)
        return jsonify({"success": True, "rfqs": rfqs}), 200
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
