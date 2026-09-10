# PREMIUM_OPPORTUNITIES — Highest Judge-Visible Wins

> Lens: working demo > beauty > reliability > speed. No enterprise work. Each item scored Impact 1–5 / Effort 1–5 / Demo 1–5 / Risk 1–5, classed A (data/low-risk) → E (arch-sensitive).

## 1. Ranked opportunities (do these first)

| # | Opportunity | Files touched | I/E/D/R | Class | Why it wins |
|---|---|---|---|---|---|
| P1 | Seed 24-product catalog + canonical categories | new `backend/seed_demo_catalog.py`, `routes/rfq.py:33`, `pricing_service.py:60` (FE), `buyer_home_screen.dart:18`, seeds | 5/2/5/1 | A | Turns empty home into marketplace in 30s; unblocks search/match/RFQ demo |
| P2 | Data-driven trust (hide fake badges, real ★/reviews/cluster) | `buyer_home_screen.dart:424-457`, `product_model.dart` (+rating fields), `buyer_product_detail_screen.dart` | 5/1/5/1 | A | Removes most dishonest pixel; judges check this |
| P3 | Before/after photo hero on artisan + detail (already works) | `photo_capture_screen.dart`, `image_service.py`, `static/enhanced/` | 5/1/5/1 | A | Strongest existing AI visual; put it on main demo path |
| P4 | Artisan storefront sheet (avatar, story, collection, chat) | `buyer_home_screen.dart`, `buyer_product_detail_screen.dart`, `buyer_service.dart` (`GET /api/products?artisan_id=` exists) | 5/2/5/2 | B | Makes 6 artisans feel like 60 products; reuses passport story |
| P5 | Sort + price-filter row (Featured/Price/Rating) | `buyer_home_screen.dart:24-29,170-213`, existing `min/max_price` API | 4/2/4/1 | B | Makes search feel premium with zero backend change |
| P6 | Product gallery + `NumberFormat('en_IN')` prices | `buyer_product_detail_screen.dart:308-322`, `_ProductCard` | 4/2/4/1 | B | ₹ formatting + swipe gallery = instant Amazon feel |
| P7 | Fix dead Catalog tab (rewire to MyProducts or remove) | `main_screen.dart:43-48`, `catalog_screen.dart` | 4/1/4/1 | A | Kills #1 judge-confusion dead end |
| P8 | User-facing ShilpSetu → KalaVistar rename (safe list only) | see BRANDING_MIGRATION.md §A | 4/1/4/1 | A | Every screenshot currently says wrong name |
| P9 | Editable transcript + resubmit in review | `listing_review_screen.dart:306-333`, `ai_catalog_service.dart` | 4/2/4/2 | B | Closes voice-loop story; low-literacy win |
| P10 | Wishlist (local-first `shared_preferences`) | buyer home + detail + new provider | 4/2/4/1 | B | Personalization without backend/cart risk |
| P11 | QR passport spotlight (scan → public page) | `routes/passport.py`, `routes/__init__.py:34-37`, detail QR | 4/1/5/1 | A | Best trust theater; already works |
| P12 | Cluster capacity story on bulk RFQ (pooled quantity → combined cap) | `rfq_screen.dart`, `supplier_comparison_screen.dart`, `clusters.py` | 4/3/4/2 | C | Differentiator for bulk-buyer narrative |
| P13 | Analytics honest-mode (label mock vs live) + hero cards | `analytics_screen.dart`, `routes/analytics.py:14-51` | 3/1/4/1 | A | Prevents mock-revenue embarrassment |
| P14 | Shimmer/skeleton for buyer loading | buyer home + detail | 3/2/3/1 | B | Perceived speed without perf work |
| P15 | Curated 3D (2–3 GLB, rotate/pinch/reset/fullscreen) | new viewer + assets (new dep) | 4/4/5/3 | D | Wow only if catalog/storefront already solid; do last |

## 2. Artisan-usability premium (cheap, judge-loved)

- Large-type review screen already good; add transcript-edit + price-apply confirmation chime/text (`listing_review_screen.dart:888-909` exists, just surface it).
- Keep one-tap sample paths but gate behind `kDebugMode` so live demo never taps them accidentally.
- Business-assistant quick prompts in Hindi first (already) + spoken-answer (TTS) later — do not fake mic again.

## 3. What looks premium but is trap

- Auto 2D→3D generation, semantic search upgrade, cart+payments, dark mode, full retheme, microservices — all high effort/risk, low demo marginal return. See DO_NOT_BUILD_NOW.md.
