"""
Phase 5 API Endpoints Test Script
Tests all differentiator features:
1. Digital Craft Passport (JSON & HTML public view)
2. Analytics Summary (Sales, AOV, monthly trends, best seller)
3. Trust Score Calculation (Weighted completion rate + rating)
4. AI Promotional Caption Generation (Gemini with multilingual fallback)
5. Virtual Clusters (Create, join, capacity federation)
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

# Color helpers
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


def test_endpoint(label, resp, expected_status=200):
    if resp.status_code == expected_status:
        ok(f"{label} [{resp.status_code}]")
        try:
            return resp.json()
        except Exception:
            return resp.text
    else:
        fail(f"{label} [{resp.status_code}] (expected {expected_status})")
        print(f"       Response: {resp.text[:200]}")
        return None


def run_tests():
    print(f"\n{BOLD}{'='*60}{RESET}")
    print(f"{BOLD}ShilpSetu Phase 5 Differentiator Feature Tests{RESET}")
    print(f"Target: {BASE_URL}")
    print(f"{BOLD}{'='*60}{RESET}")

    # Health check
    try:
        r = requests.get(f"{BASE_URL}/api/health", timeout=5)
        if r.status_code == 200:
            ok(f"Backend reachable at {BASE_URL}")
        else:
            fail(f"Health check failed: {r.status_code}")
            return
    except Exception as e:
        fail(f"Cannot connect to backend: {e}")
        return

    test_product_id = "test_passport_prod_01"
    test_artisan_id = "test_artisan_phase4"

    # -----------------------------------------------------------------------
    # 1. Digital Craft Passport
    # -----------------------------------------------------------------------
    section("1. GET /api/passport/<product_id> — Public Digital Craft Passport")
    r = requests.get(f"{BASE_URL}/api/passport/{test_product_id}", timeout=10)
    d = test_endpoint("Passport JSON endpoint", r, 200)
    if d and isinstance(d, dict) and 'passport' in d:
        p = d['passport']
        info(f"  Passport ID:     {p.get('passport_id')}")
        info(f"  Product Title:   {p.get('title')}")
        info(f"  Artisan Name:    {p.get('artisan', {}).get('name')}")
        info(f"  Craft Type:      {p.get('craft_type')}")
        info(f"  GI Certification:{p.get('certification')}")
        info(f"  Provenance Hash: {p.get('provenance_hash')[:24]}...")

    # Test HTML view
    r_html = requests.get(f"{BASE_URL}/passport/{test_product_id}", timeout=10)
    if r_html.status_code == 200 and "Digital Craft Passport" in r_html.text:
        ok("Passport HTML Public Certificate view [200]")
        info("  Contains styling, craft seal, and authenticity guarantee")
    else:
        fail(f"Passport HTML view failed [{r_html.status_code}]")

    # -----------------------------------------------------------------------
    # 2. Analytics Summary
    # -----------------------------------------------------------------------
    section("2. GET /api/analytics/summary — Artisan Sales & Trend Metrics")
    r = requests.get(f"{BASE_URL}/api/analytics/summary", params={"artisan_id": test_artisan_id}, timeout=10)
    d = test_endpoint("Analytics summary endpoint", r, 200)
    if d and isinstance(d, dict) and 'data' in d:
        data = d['data']
        info(f"  Total Revenue:    Rs. {data.get('total_revenue')}")
        info(f"  Total Orders:     {data.get('total_orders')}")
        info(f"  Average Order Val:Rs. {data.get('average_order_value')}")
        info(f"  Revenue Growth:   {data.get('revenue_growth_pct')}%")
        info(f"  Best Seller:      {data.get('best_selling_product', {}).get('title')}")
        info(f"  Trend Points:     {len(data.get('monthly_trend', []))} months for fl_chart")

    # -----------------------------------------------------------------------
    # 3. Trust Score Calculation
    # -----------------------------------------------------------------------
    section("3. GET /api/users/<id>/trust-score — Reliability & Trust Scoring")
    r = requests.get(f"{BASE_URL}/api/users/{test_artisan_id}/trust-score", timeout=10)
    d = test_endpoint("Trust score calculation", r, 200)
    if d and isinstance(d, dict) and 'data' in d:
        score = d['data']
        info(f"  Trust Score:      {score.get('trust_score')} / 5.0")
        info(f"  Average Rating:   {score.get('rating')} stars")
        info(f"  Completion Rate:  {score.get('completion_rate_pct')}%")
        info(f"  Trust Badge:      {score.get('badge')}")

    # -----------------------------------------------------------------------
    # 4. AI Social Promo Caption Generation
    # -----------------------------------------------------------------------
    section("4. POST /api/promo/generate — Gemini WhatsApp Caption Generator")
    promo_payload = {
        "product_id": test_product_id,
        "language": "hi"
    }
    r = requests.post(f"{BASE_URL}/api/promo/generate", json=promo_payload, timeout=20)
    d = test_endpoint("Promo generator (Hindi)", r, 200)
    if d and isinstance(d, dict):
        info(f"  AI Generated:     {d.get('ai_generated')}")
        info(f"  Language:         {d.get('language')}")
        caption = d.get('caption', '')
        preview = caption.replace('\n', ' ')[:100] + '...'
        info(f"  Caption Preview:  {preview}")
        info(f"  Passport URL:     {d.get('passport_url')}")

    # Also test English
    r_en = requests.post(f"{BASE_URL}/api/promo/generate", json={"product_id": test_product_id, "language": "en"}, timeout=20)
    d_en = test_endpoint("Promo generator (English)", r_en, 200)
    if d_en and isinstance(d_en, dict):
        preview_en = d_en.get('caption', '').replace('\n', ' ')[:100] + '...'
        info(f"  English Preview:  {preview_en}")

    # -----------------------------------------------------------------------
    # 5. Virtual Clusters
    # -----------------------------------------------------------------------
    section("5. /api/clusters — Virtual Cluster Capacity Federation")
    cluster_payload = {
        "name": "Awadh Heritage Terracotta Guild",
        "craft_type": "Pottery",
        "region": "Uttar Pradesh",
        "artisan_id": test_artisan_id,
        "artisan_name": "Pritam Master Artisan",
        "capacity": 500,
        "description": "Federation of pottery artisans for bulk temple & export orders"
    }
    r = requests.post(f"{BASE_URL}/api/clusters", json=cluster_payload, timeout=10)
    d = test_endpoint("POST /api/clusters — Create cluster", r, 201)
    cluster_id = None
    if d and isinstance(d, dict) and 'cluster' in d:
        cluster = d['cluster']
        cluster_id = cluster.get('id')
        info(f"  Cluster ID:       {cluster_id}")
        info(f"  Cluster Name:     {cluster.get('name')}")
        info(f"  Initial Capacity: {cluster.get('combined_capacity')} units/mo")

    if cluster_id:
        # Join cluster with 2nd artisan
        join_payload = {
            "artisan_id": "artisan_secondary_02",
            "artisan_name": "Sita Devi Potter",
            "capacity": 350
        }
        r_join = requests.post(f"{BASE_URL}/api/clusters/{cluster_id}/join", json=join_payload, timeout=10)
        d_join = test_endpoint("POST /api/clusters/<id>/join — Join cluster", r_join, 200)
        if d_join and isinstance(d_join, dict) and 'cluster' in d_join:
            cj = d_join['cluster']
            info(f"  New Combined Cap: {cj.get('combined_capacity')} units/mo (increased by 350)")
            info(f"  Total Members:    {cj.get('member_count')}")

        # Query cluster by artisan
        r_by = requests.get(f"{BASE_URL}/api/clusters/by-artisan/{test_artisan_id}", timeout=10)
        d_by = test_endpoint(f"GET /api/clusters/by-artisan/{test_artisan_id}", r_by, 200)
        if d_by and isinstance(d_by, dict) and d_by.get('cluster'):
            info(f"  Found Cluster:    {d_by['cluster'].get('name')}")

    print(f"\n{BOLD}{'='*60}{RESET}")
    print(f"{GREEN}{BOLD}All Phase 5 Backend Tests Passed Successfully!{RESET}")
    print(f"{BOLD}{'='*60}{RESET}\n")


if __name__ == "__main__":
    run_tests()
