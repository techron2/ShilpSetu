"""
Analytics Summary Routes
Aggregates sales metrics, monthly trends, AOV, and best-selling products for artisans.
Used to render summary cards and fl_chart visualizations.
Returns genuine zero data for new artisans with 0 orders/products (never fake/dummy figures).
"""
from flask import Blueprint, jsonify, request
from services.firebase_service import get_firestore_client
from datetime import datetime, timezone
from collections import defaultdict

analytics_bp = Blueprint('analytics', __name__)

# ---------------------------------------------------------------------------
# Revenue recognition policy (SIH operational sales metric, not GAAP).
#
# Order lifecycle: pending → confirmed → shipped → out_for_delivery →
# delivered → paid, plus cancelled. Payments are COD-only (see payments.py),
# with no failed/refunded payment state, so recognition is status-based:
#   revenue  = confirmed, shipped, out_for_delivery, delivered, paid
#   pipeline = pending, cancelled (never revenue)
# Unknown statuses count toward total_orders/status_counts but never revenue.
# ---------------------------------------------------------------------------
KNOWN_ORDER_STATUSES = [
    "pending",
    "confirmed",
    "shipped",
    "out_for_delivery",
    "delivered",
    "paid",
    "cancelled",
]

REVENUE_ORDER_STATUSES = frozenset({
    "confirmed",
    "shipped",
    "out_for_delivery",
    "delivered",
    "paid",
})

COMPLETED_ORDER_STATUSES = frozenset({"delivered", "paid"})


def _normalize_order_status(order) -> str:
    """Lower-cased status string; '' when missing."""
    try:
        return str((order or {}).get('status', '') or '').strip().lower()
    except Exception:
        return ''


def _is_revenue_order(order) -> bool:
    """True only for recognized commercial order value (never pending/cancelled/unknown)."""
    return _normalize_order_status(order) in REVENUE_ORDER_STATUSES


def _safe_order_price(order) -> float:
    """Conservative monetary value; invalid/missing → 0.0 (never fabricated)."""
    try:
        return float((order or {}).get('total_price', 0.0) or 0.0)
    except (TypeError, ValueError):
        return 0.0


def _safe_order_quantity(order) -> int:
    """Conservative quantity; invalid/missing → 0."""
    try:
        return int(float((order or {}).get('quantity', 0) or 0))
    except (TypeError, ValueError):
        return 0


def _parse_order_created(order):
    """Parsed aware datetime or None; malformed values never crash or invent placement."""
    cat = (order or {}).get('created_at')
    if isinstance(cat, str):
        try:
            return datetime.fromisoformat(cat.replace('Z', '+00:00'))
        except Exception:
            return None
    elif isinstance(cat, datetime):
        return cat
    return None


def _get_zero_analytics(artisan_id: str) -> dict:
    """Genuine zero/empty analytics for an artisan with no recorded sales yet."""
    now = datetime.now(timezone.utc)
    months_order = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    current_idx = now.month - 1
    trend_months = [months_order[(current_idx - 5 + i) % 12] for i in range(6)]

    return {
        "artisan_id": artisan_id,
        "total_revenue": 0.0,
        "total_orders": 0,
        "completed_orders": 0,
        "average_order_value": 0.0,
        "revenue_this_month": 0.0,
        "revenue_last_month": 0.0,
        "revenue_growth_pct": 0.0,
        "best_selling_product": {
            "id": "",
            "title": "No sales yet",
            "units_sold": 0,
            "revenue": 0.0
        },
        "order_status_counts": {
            "pending": 0,
            "confirmed": 0,
            "shipped": 0,
            "out_for_delivery": 0,
            "delivered": 0,
            "paid": 0,
            "cancelled": 0
        },
        "monthly_trend": [
            {"month": m, "revenue": 0.0, "orders": 0} for m in trend_months
        ],
        "category_breakdown": []
    }


@analytics_bp.route('/summary', methods=['GET'])
def get_analytics_summary():
    """
    GET /api/analytics/summary?artisan_id=<id>
    Aggregates orders and product metrics from Firestore for the given artisan.
    Returns 100% genuine zero numbers for new users without orders.
    """
    artisan_id = request.args.get('artisan_id', '').strip()
    if not artisan_id:
        return jsonify({"success": False, "error": "artisan_id query param is required"}), 400

    db = get_firestore_client()
    if not db:
        return jsonify({"success": True, "source": "zero_fallback", "data": _get_zero_analytics(artisan_id)}), 200

    try:
        # Fetch artisan's orders
        orders_query = db.collection('orders').where('artisan_id', '==', artisan_id).stream()
        orders = []
        for doc in orders_query:
            d = doc.to_dict()
            d['id'] = doc.id
            orders.append(d)

        if not orders:
            # Genuine zero baseline for new artisans without orders
            return jsonify({"success": True, "source": "firestore", "data": _get_zero_analytics(artisan_id)}), 200

        total_orders = len(orders)
        total_revenue = 0.0
        recognized_orders = 0
        status_counts = defaultdict(int)
        for known in KNOWN_ORDER_STATUSES:
            status_counts[known] += 0
        product_sales = defaultdict(lambda: {"units": 0, "revenue": 0.0, "title": ""})

        # Track monthly revenue (recognized orders only, keyed by year+month)
        now = datetime.now(timezone.utc)
        current_month = now.month
        current_year = now.year
        prev_month = 12 if current_month == 1 else current_month - 1
        prev_year = current_year - 1 if current_month == 1 else current_year

        rev_this_month = 0.0
        rev_last_month = 0.0
        monthly_buckets = defaultdict(lambda: {"revenue": 0.0, "orders": 0})

        for o in orders:
            status = _normalize_order_status(o) or 'pending'
            status_counts[status] += 1
            price = _safe_order_price(o)
            qty = _safe_order_quantity(o)
            pid = str(o.get('product_id', 'unknown') or 'unknown')
            ptitle = o.get('product_title') or o.get('item_name') or f"Product {pid[:6]}"

            # Only revenue-recognized commercial orders (single predicate).
            if _is_revenue_order(o):
                total_revenue += price
                recognized_orders += 1
                product_sales[pid]["units"] += qty
                product_sales[pid]["revenue"] += price
                if not product_sales[pid]["title"]:
                    product_sales[pid]["title"] = ptitle

            # Monthly placement for recognized orders only; malformed dates skipped.
            if _is_revenue_order(o):
                created_dt = _parse_order_created(o)
                if created_dt:
                    if created_dt.tzinfo is None:
                        created_dt = created_dt.replace(tzinfo=timezone.utc)
                    bucket_key = (created_dt.year, created_dt.month)
                    monthly_buckets[bucket_key]["revenue"] += price
                    monthly_buckets[bucket_key]["orders"] += 1

                    if created_dt.year == current_year and created_dt.month == current_month:
                        rev_this_month += price
                    elif created_dt.year == prev_year and created_dt.month == prev_month:
                        rev_last_month += price

        growth_pct = 0.0
        if rev_last_month > 0:
            growth_pct = round(((rev_this_month - rev_last_month) / rev_last_month) * 100, 1)
        elif rev_this_month > 0:
            growth_pct = 100.0

        aov = round(total_revenue / recognized_orders, 1) if recognized_orders > 0 else 0.0

        # Best selling product
        best_pid = None
        best_info = {"id": "", "title": "No sales yet", "units_sold": 0, "revenue": 0.0}
        if product_sales:
            best_pid = max(product_sales.keys(), key=lambda k: product_sales[k]["revenue"])
            b = product_sales[best_pid]
            if b["units"] > 0:
                best_info = {
                    "id": best_pid,
                    "title": b["title"] or "Handcrafted Item",
                    "units_sold": b["units"],
                    "revenue": round(b["revenue"], 1)
                }

        # Format monthly trend for the rolling last 6 calendar months.
        # Buckets are keyed by (year, month) so Jan 2025 never merges into Jan 2026;
        # display labels remain 'Jan'..'Dec' for the chart. Recognized orders only.
        months_order = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        trend_keys = []
        y, m = current_year, current_month
        for _ in range(6):
            trend_keys.append((y, m))
            m -= 1
            if m == 0:
                m = 12
                y -= 1
        trend_keys.reverse()
        monthly_trend = []
        for (y, m) in trend_keys:
            b = monthly_buckets.get((y, m), {"revenue": 0.0, "orders": 0})
            monthly_trend.append({
                "month": months_order[m - 1],
                "revenue": round(b["revenue"], 1),
                "orders": b["orders"]
            })

        completed_orders = int(status_counts.get('delivered', 0) + status_counts.get('paid', 0))
        data = {
            "artisan_id": artisan_id,
            "total_revenue": round(total_revenue, 1),
            "total_orders": total_orders,
            "completed_orders": completed_orders,
            "average_order_value": aov,
            "revenue_this_month": round(rev_this_month, 1),
            "revenue_last_month": round(rev_last_month, 1),
            "revenue_growth_pct": growth_pct,
            "best_selling_product": best_info,
            "order_status_counts": dict(status_counts),
            "monthly_trend": monthly_trend,
            "category_breakdown": []
        }
        return jsonify({"success": True, "source": "firestore", "data": data}), 200

    except Exception as e:
        # Fallback to genuine zero response on error
        return jsonify({"success": True, "source": "zero_fallback", "data": _get_zero_analytics(artisan_id), "note": str(e)}), 200
