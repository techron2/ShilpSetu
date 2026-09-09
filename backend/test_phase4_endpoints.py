"""
Phase 4 API endpoint tests with realistic sample data.
Seeds Firestore with sample products + artisans, then tests all Phase 4 endpoints.

Usage:
    cd backend
    python test_phase4_endpoints.py [--base-url http://localhost:5000] [--seed]
"""
import sys
import json
import argparse
import requests

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

BASE_URL = "http://localhost:5000"

# ─── Colour helpers ───────────────────────────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def ok(msg):  print(f"  {GREEN}PASS{RESET}  {msg}")
def fail(msg): print(f"  {RED}FAIL{RESET}  {msg}")
def info(msg): print(f"  {CYAN}INFO{RESET}  {msg}")
def section(msg): print(f"\n{BOLD}{YELLOW}{'--'*30}{RESET}\n{BOLD}{msg}{RESET}")


# ─── Seed data ────────────────────────────────────────────────────────────────
SAMPLE_ARTISAN_ID = "test_artisan_phase4"

SAMPLE_PRODUCTS = [
    {
        "artisan_id": SAMPLE_ARTISAN_ID,
        "title": "Handwoven Cotton Saree - Jamdani",
        "description": "Traditional handloom jamdani weave cotton saree with floral motifs. Soft, breathable, ideal for retail chains.",
        "category": "Textiles",
        "price": 1200,
        "stock_quantity": 150,
        "region": "West Bengal",
        "rating": 4.7,
        "review_count": 34,
        "image_url": "",
    },
    {
        "artisan_id": SAMPLE_ARTISAN_ID,
        "title": "Terracotta Chai Kulhad Set (6 pcs)",
        "description": "Hand-thrown terracotta kulhads, food-safe, biodegradable. Perfect for restaurants and gifting.",
        "category": "Pottery",
        "price": 350,
        "stock_quantity": 500,
        "region": "Rajasthan",
        "rating": 4.5,
        "review_count": 89,
        "image_url": "",
    },
    {
        "artisan_id": SAMPLE_ARTISAN_ID,
        "title": "Block Print Cotton Dupatta - Dabu",
        "description": "Rajasthani dabu block print cotton dupatta. Natural dyes, mud resist technique.",
        "category": "Textiles",
        "price": 680,
        "stock_quantity": 200,
        "region": "Rajasthan",
        "rating": 4.3,
        "review_count": 57,
        "image_url": "",
    },
    {
        "artisan_id": SAMPLE_ARTISAN_ID,
        "title": "Silver Tribal Necklace - Dhokra",
        "description": "Dhokra lost-wax cast tribal silver-finish necklace. Handmade, each piece unique.",
        "category": "Jewelry",
        "price": 2200,
        "stock_quantity": 40,
        "region": "Chhattisgarh",
        "rating": 4.8,
        "review_count": 22,
        "image_url": "",
    },
    {
        "artisan_id": SAMPLE_ARTISAN_ID,
        "title": "Hand-embroidered Phulkari Cushion Cover",
        "description": "Punjab phulkari embroidery on cotton cushion cover. Vibrant thread work, 40x40cm.",
        "category": "Embroidery",
        "price": 450,
        "stock_quantity": 80,
        "region": "Punjab",
        "rating": 4.6,
        "review_count": 41,
        "image_url": "",
    },
]

# ─── Test helpers ─────────────────────────────────────────────────────────────

def test_endpoint(label: str, resp: requests.Response, expect_status: int = 200) -> dict:
    data = {}
    try:
        data = resp.json()
    except Exception:
        data = {"raw": resp.text[:300]}

    if resp.status_code == expect_status and data.get("success", data.get("ok", True)):
        ok(f"{label} [{resp.status_code}]")
    else:
        fail(f"{label} [{resp.status_code}] — {data.get('error', data)}")
    return data


def seed_products(product_ids: list):
    section("SEED: Creating sample products in Firestore")
    for p in SAMPLE_PRODUCTS:
        resp = requests.post(f"{BASE_URL}/api/products", json=p, timeout=10)
        data = resp.json()
        if resp.status_code == 201 and data.get("success"):
            pid = data["product"]["id"]
            product_ids.append(pid)
            ok(f"Created product: {p['title'][:45]} → id={pid}")
        else:
            fail(f"Failed to create: {p['title'][:45]} — {data.get('error')}")


# ─── Test suites ──────────────────────────────────────────────────────────────

def test_product_search():
    section("1. GET /api/products/search — Keyword / Category / Price filtering")

    # Keyword search
    r = requests.get(f"{BASE_URL}/api/products/search", params={"query": "cotton saree"}, timeout=10)
    d = test_endpoint("Keyword search: 'cotton saree'", r)
    info(f"  Results: {d.get('count', 0)} products found")

    # Category filter
    r = requests.get(f"{BASE_URL}/api/products/search", params={"category": "Textiles"}, timeout=10)
    d = test_endpoint("Category filter: Textiles", r)
    info(f"  Results: {d.get('count', 0)} products found")

    # Price range filter
    r = requests.get(f"{BASE_URL}/api/products/search", params={"max_price": 500}, timeout=10)
    d = test_endpoint("Price filter: max_price=500", r)
    info(f"  Results: {d.get('count', 0)} products found")

    # Combined
    r = requests.get(f"{BASE_URL}/api/products/search",
                     params={"query": "block print", "category": "Textiles", "max_price": 1000}, timeout=10)
    d = test_endpoint("Combined: 'block print' + Textiles + max Rs.1000", r)
    info(f"  Results: {d.get('count', 0)} products found")
    if d.get("products"):
        info(f"  Top result: {d['products'][0].get('title')}")

    # No results case
    r = requests.get(f"{BASE_URL}/api/products/search", params={"query": "xyznonexistent"}, timeout=10)
    d = test_endpoint("Empty result case: 'xyznonexistent'", r)
    info(f"  Results: {d.get('count', 0)} (expected 0)")


def test_matching(buyer_id: str):
    section("2. POST /api/matching/buyer-supplier — Cosine Similarity Matching")

    payload = {
        "category": "Textiles",
        "quantity": 200,
        "budget": 50000,
        "region": "Rajasthan"
    }
    r = requests.post(f"{BASE_URL}/api/matching/buyer-supplier", json=payload, timeout=15)
    d = test_endpoint("Match: 200 Textiles, ₹50k, Rajasthan", r)

    if d.get("matches"):
        info(f"  {len(d['matches'])} matches returned")
        for m in d["matches"][:3]:
            info(f"    Rank {m['rank']}: {m['product'].get('title', '')[:40]} "
                 f"(score={m['similarity_score']}, artisan={m['artisan'].get('name', '')})")
    else:
        info("  No matches returned (may need products in Firestore)")

    # Test with pottery
    payload2 = {"category": "Pottery", "quantity": 100, "budget": 40000, "region": ""}
    r = requests.post(f"{BASE_URL}/api/matching/buyer-supplier", json=payload2, timeout=15)
    d2 = test_endpoint("Match: 100 Pottery, ₹40k, any region", r)
    if d2.get("matches"):
        info(f"  {len(d2['matches'])} matches returned")


def test_rfq(buyer_id: str) -> str:
    section("3. POST /api/rfq — AI-Structured RFQ Generation")

    rfq_text = "I need 200 cotton sarees for my retail chain by next month, budget around 50000 rupees"
    payload = {"buyer_id": buyer_id, "requirement_text": rfq_text}
    r = requests.post(f"{BASE_URL}/api/rfq", json=payload, timeout=20)
    d = test_endpoint("RFQ: '200 cotton sarees, ₹50k, next month'", r, expect_status=201)

    rfq_id = ""
    if d.get("rfq"):
        rfq = d["rfq"]
        rfq_id = rfq.get("id", "")
        info(f"  AI structured: {d.get('ai_structured')}")
        info(f"  Category: {rfq.get('category')}")
        info(f"  Quantity: {rfq.get('quantity')}")
        info(f"  Target price/unit: ₹{rfq.get('target_price')}")
        info(f"  Deadline: {rfq.get('deadline')}")
        info(f"  Specs: {rfq.get('specifications')}")

    # Second RFQ — pottery
    rfq2 = "Need 50 terracotta diyas for Diwali corporate gifts, handmade, under ₹15000 total"
    r2 = requests.post(f"{BASE_URL}/api/rfq", json={"buyer_id": buyer_id, "requirement_text": rfq2}, timeout=20)
    d2 = test_endpoint("RFQ: 'Diwali terracotta diyas, ₹15k total'", r2, expect_status=201)

    # List RFQs for buyer
    r3 = requests.get(f"{BASE_URL}/api/rfq", params={"buyer_id": buyer_id}, timeout=10)
    d3 = test_endpoint("List RFQs for buyer", r3)
    info(f"  {len(d3.get('rfqs', []))} RFQs found for buyer")

    return rfq_id


def test_orders(buyer_id: str, artisan_id: str, product_ids: list) -> str:
    section("4. /api/orders — Full CRUD")

    product_id = product_ids[0] if product_ids else "test_product_001"

    # POST — Create order
    order_payload = {
        "product_id":       product_id,
        "buyer_id":         buyer_id,
        "artisan_id":       artisan_id,
        "quantity":         10,
        "total_price":      12000.0,
        "delivery_address": "123 MG Road, Bengaluru, Karnataka 560001",
        "buyer_name":       "Priya Sharma",
        "artisan_name":     "Ramesh Kumawat",
        "product_title":    "Handwoven Cotton Saree - Jamdani",
        "notes":            "Please use eco-friendly packaging"
    }
    r = requests.post(f"{BASE_URL}/api/orders", json=order_payload, timeout=10)
    d = test_endpoint("POST /api/orders — Create order", r, expect_status=201)
    order_id = d.get("order", {}).get("id", "")
    info(f"  Created order ID: {order_id}")
    info(f"  Status: {d.get('order', {}).get('status')}")

    if not order_id:
        fail("Could not obtain order_id — skipping remaining order tests")
        return ""

    # GET — List by buyer_id
    r = requests.get(f"{BASE_URL}/api/orders", params={"buyer_id": buyer_id}, timeout=10)
    d = test_endpoint(f"GET /api/orders?buyer_id={buyer_id}", r)
    info(f"  {d.get('count', 0)} orders found for buyer")

    # GET — List by artisan_id
    r = requests.get(f"{BASE_URL}/api/orders", params={"artisan_id": artisan_id}, timeout=10)
    d = test_endpoint(f"GET /api/orders?artisan_id={artisan_id}", r)
    info(f"  {d.get('count', 0)} orders found for artisan")

    # GET — Single order
    r = requests.get(f"{BASE_URL}/api/orders/{order_id}", timeout=10)
    d = test_endpoint(f"GET /api/orders/{order_id}", r)

    # PUT — Confirm
    r = requests.put(f"{BASE_URL}/api/orders/{order_id}", json={"status": "confirmed"}, timeout=10)
    d = test_endpoint("PUT — status: confirmed", r)
    info(f"  New status: {d.get('order', {}).get('status')}")

    # PUT — Shipped
    r = requests.put(f"{BASE_URL}/api/orders/{order_id}",
                     json={"status": "shipped", "tracking_number": "IN1234567890"},
                     timeout=10)
    d = test_endpoint("PUT — status: shipped + tracking_number", r)

    # PUT — Delivered
    r = requests.put(f"{BASE_URL}/api/orders/{order_id}", json={"status": "delivered"}, timeout=10)
    test_endpoint("PUT — status: delivered", r)

    # PUT — Invalid status
    r = requests.put(f"{BASE_URL}/api/orders/{order_id}", json={"status": "flying"}, timeout=10)
    if r.status_code == 400:
        ok("PUT — invalid status correctly rejected (400)")
    else:
        fail(f"PUT — invalid status should return 400, got {r.status_code}")

    return order_id


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Phase 4 API tests")
    parser.add_argument("--base-url", default="http://localhost:5000")
    parser.add_argument("--seed", action="store_true", help="Seed sample products first")
    parser.add_argument("--buyer-id",   default="test_buyer_phase4")
    parser.add_argument("--artisan-id", default=SAMPLE_ARTISAN_ID)
    args = parser.parse_args()

    global BASE_URL
    BASE_URL = args.base_url.rstrip("/")

    print(f"\n{BOLD}ShilpSetu Phase 4 API Tests{RESET}")
    print(f"Target: {CYAN}{BASE_URL}{RESET}\n")

    # Health check
    try:
        r = requests.get(f"{BASE_URL}/api/health", timeout=5)
        if r.status_code == 200:
            ok(f"Backend reachable at {BASE_URL}")
        else:
            fail(f"Backend health check failed: {r.status_code}")
    except Exception as e:
        fail(f"Cannot reach backend: {e}")
        sys.exit(1)

    product_ids = []
    if args.seed:
        seed_products(product_ids)
    else:
        info("Skipping seed (use --seed to insert sample products)")

    test_product_search()
    test_matching(args.buyer_id)
    rfq_id = test_rfq(args.buyer_id)
    order_id = test_orders(args.buyer_id, args.artisan_id, product_ids)

    section("SUMMARY")
    info(f"Buyer ID used:   {args.buyer_id}")
    info(f"Artisan ID used: {args.artisan_id}")
    if product_ids:
        info(f"Products seeded: {len(product_ids)}")
    if rfq_id:
        info(f"RFQ created:     {rfq_id}")
    if order_id:
        info(f"Order created:   {order_id}")
    print(f"\n{GREEN}{BOLD}Phase 4 test run complete.{RESET}\n")


if __name__ == "__main__":
    main()
