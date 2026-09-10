# CATALOG_EXPANSION_PLAN — From Empty DB to 20–30 Product Demo

> Sources: `frontend/lib/models/product_model.dart`, `services/mock_product_service.dart`, `screens/catalog_screen.dart`, `screens/buyer/buyer_home_screen.dart`, backend `routes/products.py`, `routes/catalog.py`, `matching.py`, `data/handicraft_pricing_data.csv`, `test_phase4_endpoints.py`.

## 1. Current state (counts)

| Source | File | N | Usable? |
|---|---|---|---|
| Frontend mock (dormant, `useMock=false`) | `services/mock_product_service.dart:10-71` (mock_001–005, all `artisan_001`, Unsplash `w=600`) | 5 | Template only |
| Legacy catalog mock (Firestore-null fallback) | `routes/catalog.py:24-47` (prod_001–002) | 2 | No |
| Hardcoded artisan Catalog tab | `screens/catalog_screen.dart:8-45` (icon-only, String price/stock) | 4 display-only | Rewire or delete |
| Backend test fixtures (transient) | `test_phase4_endpoints.py:43-96` (5 POST payloads, `--seed`) | 5 | Starting template |
| Passport/analytics/promo singletons | `routes/passport.py:290-304`, `analytics.py:27-30`, `promo.py:147-148` | 1 each | No |
| Firestore `products` (live truth) | `routes/products.py:67-85` | 0 seeded | **Target** |
| Pricing CSV (not products) | `data/handicraft_pricing_data.csv:1-281` | 280 rows | Reference for price bands |

Effective buyer demo today: `searchProducts(limit:50)` → `[]` → `_emptyState`. 7 distinct Unsplash IDs float around (`mock_*`, `catalog.py:34,45`, `ai_catalog_service.dart:21`, `photo_capture_screen.dart:27`, passport/promo fallbacks). No `picsum`, no local `assets/`, no `cached_network_image` (`pubspec.yaml:31-49`).

## 2. Schema (canonical — do not extend without need)

- Create requires (`routes/products.py:35`): `artisan_id, title, price, stock_quantity`. Optional: `description, image_url, category` (default `Uncategorized`). Stored (`:47-57`): + `id, created_at:ISO`.
- Frontend (`models/product_model.dart:2-51`): `id, artisanId↔artisan_id, title, description, imageUrl↔image_url, price:double, stockQuantity↔stock_quantity, category, createdAt?:String`.
- Seeds also inject (but `Product` ignores): `rating, review_count, region, artisan_cluster, materials, images[], gi_tag, story` (`test_phase4_endpoints.py:47-60`, `matching.py:80-99`, `passport.py:281-337`). Buyer UI then defaults `rating=4.0/reviews=0/region=''` (`buyer_home_screen.dart:318,344-45`).
- Users (`models/user_model.dart`, `routes/users.py:41-50`): `uid,name,email,role,phone(+phone_number dual-write),language_preference,artisan_cluster,region` + trust fields + `cluster_id/cluster_name/cluster_capacity` (cluster-written, absent from `UserModel`).
- Orders/RFQ/Cluster/Passport/Chat shapes: see CURRENT_PRODUCT.md §3; ratings on orders (`tracking_number/url/rating` updatable `orders.py:176-177`) never typed in `OrderModel`.

## 3. Category mess (must fix first)

`routes/products.py:127-128` exact `where(category==)` — drift = zero results.

- Buyer chips (`buyer_home_screen.dart:18-21`): `All,Textiles,Pottery,Jewelry,Embroidery,Woodwork,Leather,Painting,Metalwork`
- RFQ (`routes/rfq.py:33-36`): same + `Stonework,Basketry,Other`
- Pricing valid (`services/pricing_service.py:60` + CSV): `Pottery,Textiles,Painting,Metal Craft,Wood Craft,Jewellery,Accessories,Other`
- Mocks: `Pottery,Textiles,Painting,Accessories,Metal Craft`
- Analytics mock: `Pottery,Textiles,Woodwork`

**Decision needed (single owner):** canonical 9 = `Textiles, Pottery, Jewellery, Embroidery, Wood Craft, Leather, Painting, Metal Craft, Other`. Then: (a) update buyer chips + RFQ list + pricing valid + seeds to match; (b) keep `Jewellery` spelling everywhere (kill `Jewelry`); (c) normalize `Woodwork→Wood Craft`, `Metalwork→Metal Craft`; (d) fold `Stonework/Basketry/Leather/Embroidery` into valid or map to `Other` explicitly.

## 4. 20–30 product plan (1–2 days, class A)

- **Artisans (6):** Gorakhpur terracotta, Kutch textile, Madhubani painting, Bastar metal (Dhokra), Saharanpur wood, Kundan jewellery. Gives matching `region/artisan_cluster` diversity (`matching.py:31-46` needs both).
- **Mix (24):** Pottery 4, Textiles 5, Painting 3, Metal Craft 3, Wood Craft 3, Jewellery 3, Embroidery 2, Other 1. Price from CSV bands (₹300–3000 textiles, ₹150–1500 pottery, ₹200–5000 jewellery per `phases.md:207-209`).
- **Fields per product:** all canonical create fields + `description (2–3 lines, EN + HI line)`, `image_url` (curated Unsplash `w=800`), `region`, `artisan_cluster`, `rating 4.2–4.9`, `review_count 12–220`, `materials[]`, `story` 1 line (feeds passport).
- **Images:** reuse the 7 known-good Unsplash IDs + ~17 new curated `images.unsplash.com?auto=format&fit=crop&w=800&q=80`. Download once, re-upload to Firebase Storage or Flask `static/enhanced/` for demo reliability (hotlinks flaked before; no cache lib installed).
- **Seed script (new, additive):** `backend/seed_demo_catalog.py` looping `POST /api/products` (pattern in `test_phase4_endpoints.py:117-127`) or direct Firestore import; idempotent by `title+artisan_id`; prints category counts. **Do not** edit route logic to seed.
- **Acceptance:** `GET /api/products/search?limit=50` → 24; each category chip → ≥2; `POST /api/matching/buyer-supplier {category,quantity}` → ≥3 matches with scores; passport + promo work for 3 sampled ids; buyer home first screen has ≥6 above-fold cards.

## 5. Storefront wiring (makes catalog feel 3× bigger)

- `users` already carry `name/region/artisan_cluster`; matching returns `artisan:{id,name,region,cluster,rating,review_count}`. Add lightweight `GET /api/products?artisan_id=` reuse (exists `products.py:67-85`) behind artisan-name tap → storefront sheet (avatar initial, story from passport artisan_story, product row, cluster badge, chat button). No new collection needed.
- Fix `UserModel` to include `cluster_id/cluster_name` (read-only add) so cluster badge is real.

## 6. File ownership

- Single owner for seed + category normalization: `backend/seed_demo_catalog.py` (new) + `routes/rfq.py:33-36` + `services/pricing_service.py:60` (frontend) + `buyer_home_screen.dart:18-21` + `product_model.dart` (if rating added). Do not parallelize category edits across agents — exact-match filter makes conflicts silent.
