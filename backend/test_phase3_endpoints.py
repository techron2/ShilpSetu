import os
import sys
import json
import requests

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

API_BASE = "http://127.0.0.1:5000"


def test_pricing_suggestions():
    print("\n=======================================================")
    print("TEST SUITE 1: POST /api/pricing/suggest (3 Test Cases)")
    print("=======================================================")
    url = f"{API_BASE}/api/pricing/suggest"

    test_cases = [
        {
            "name": "Case 1: Madhubani Painting (Bihar, Medium, ₹120 material)",
            "payload": {
                "category": "Painting",
                "material_cost": 120,
                "size": "medium",
                "region": "Bihar"
            }
        },
        {
            "name": "Case 2: Terracotta Kulhad Set (Uttar Pradesh, Small, ₹45 material)",
            "payload": {
                "category": "Pottery",
                "material_cost": 45,
                "size": "small",
                "region": "Uttar Pradesh"
            }
        },
        {
            "name": "Case 3: Hand Block Printed Saree (Rajasthan, Large, ₹750 material)",
            "payload": {
                "category": "Textiles",
                "material_cost": 750,
                "size": "large",
                "region": "Rajasthan"
            }
        }
    ]

    for tc in test_cases:
        print(f"\n--- {tc['name']} ---")
        resp = requests.post(url, json=tc['payload'], timeout=15)
        print(f"Status Code: {resp.status_code}")
        data = resp.json()
        print(f"Suggested Price: ₹{data.get('suggested_price')}")
        print(f"Price Range:     ₹{data.get('price_range_min')} - ₹{data.get('price_range_max')}")
        print(f"Explanation:     {data.get('explanation')}")
        assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"
        assert data.get("suggested_price") > 0, "Price should be positive"


def test_business_assistant():
    print("\n=======================================================")
    print("TEST SUITE 2: POST /api/assistant/ask (3 Test Cases)")
    print("=======================================================")
    url = f"{API_BASE}/api/assistant/ask"

    test_cases = [
        {
            "name": "Case 1: Diwali Seasonality Pricing (Hindi)",
            "payload": {
                "artisan_id": "artisan_001",
                "question": "दीवाली के मौसम में मुझे अपने कुल्हड़ और दीयों की कीमत क्या रखनी चाहिए?",
                "language": "hi"
            }
        },
        {
            "name": "Case 2: Sales Troubleshooting (English)",
            "payload": {
                "artisan_id": "artisan_001",
                "question": "Why are my textile stoles selling slowly and how can I attract more online buyers?",
                "language": "en"
            }
        },
        {
            "name": "Case 3: Urban Market Packaging & Presentation (Hindi)",
            "payload": {
                "artisan_id": "artisan_001",
                "question": "शहरी ग्राहकों को आकर्षित करने के लिए मुझे अपने धातु शिल्प (Dhokra craft) की पैकेजिंग में क्या सुधार करना चाहिए?",
                "language": "hi"
            }
        }
    ]

    for tc in test_cases:
        print(f"\n--- {tc['name']} ---")
        print(f"Question: {tc['payload']['question']}")
        resp = requests.post(url, json=tc['payload'], timeout=30)
        print(f"Status Code: {resp.status_code}")
        data = resp.json()
        print(f"Answer:\n{data.get('answer')}")
        print(f"Context used: {data.get('context_summary')}")
        assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"
        assert len(data.get("answer", "")) > 20, "Answer should be substantive"


if __name__ == "__main__":
    test_pricing_suggestions()
    test_business_assistant()
    print("\n=======================================================")
    print("ALL PHASE 3 BACKEND TESTS PASSED SUCCESSFULLY!")
    print("=======================================================")
