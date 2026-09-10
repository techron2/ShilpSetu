# MARKETPLACE_GAP_ANALYSIS — Buyer Experience vs Premium Standard

> Scope: `frontend/lib/screens/buyer/*`, `screens/main_screen.dart` (buyer shell), `services/buyer_service.dart`, `services/chat_service.dart`, `models/order_model.dart`, `models/rfq_model.dart`, backend `routes/products.py`, `matching.py`, `rfq.py`, `orders.py`, `passport.py`, `clusters.py`.

## 1. What exists and works

- Discover: `buyer_home_screen.dart` — pinned `SliverAppBar` search, animated category chips, result count, spinner, 2-col grid, empty state with Show-all. Data via `BuyerService.searchProducts → GET /api/products/search` (`buyer_service.dart:17-42`, `routes/products.py:102-175` supports `query/category/min-max-price/limit`).
- Detail: `buyer_product_detail_screen.dart` — 280px image app bar, price, bilingual desc slot, quantity stepper, Order Now (`createOrder`), RFQ prefill, compare, chat, passport QR (`qr_flutter:749`), trust/cluster badges, promo caption + `share_plus:143`.
- RFQ → match: `rfq_screen.dart` (free-text + 5 suggestions → `POST /api/rfq`, Gemini + regex fallback) → `supplier_comparison_screen.dart` (top-3 price/capacity/rating + table) backed by `POST /api/matching/buyer-supplier` (TF-IDF cosine, `matching.py:49-188`).
- Orders: `buyer_orders_screen.dart` (REST list + status chips + chat link); artisan mirror `orders_screen.dart` (Firestore stream + REST fallback, status advance).
- Trust: passport JSON/HTML (`routes/passport.py:367-388`, public `/passport/<id>` in `routes/__init__.py:34-37`), trust score (`GET /api/users/<id>/trust-score`, weighted completion+rating, badge 🌟/✅/🌱/✨), cluster badge + capacity (`routes/clusters.py`).
- Chat: `chat_screen.dart` + `chat_service.dart` Firestore-direct `chats/{sortedA_B}/messages` — no Flask dependency.

## 2. Gaps ranked by demo impact

| # | Gap | Evidence | Impact/Effort/Demo/Risk | Class |
|---|---|---|---|---|
| G1 | Empty DB = empty home on first impression | `_emptyState` at `buyer_home_screen.dart:277-306`; no seed in repo | 5/1/5/1 | A |
| G2 | No artisan storefront route (name unclickable, no story/collection page) | Card shows no artisan name; tap → detail only | 5/2/5/2 | B |
| G3 | Trust badges faked (★4.0/Verified/Cluster on every card) | `buyer_home_screen.dart:424-457` unconditional | 5/1/5/1 | A |
| G4 | No sort/filter beyond exact category + text (API price filters unexposed, no rating/region/stock) | `buyer_home_screen.dart:24-29` ignores `min_price/max_price`; `products.py:127` exact match | 4/2/4/2 | B |
| G5 | No wishlist/cart (Order Now only) | `buyer_product_detail_screen.dart:599-612` direct create | 4/3/4/2 | C |
| G6 | Single image, no gallery/zoom; cramped `0.68` grid cell overflows on narrow | `Image.network` only `:356`, `:315`; cluster tag `:447-457` | 4/2/4/2 | B |
| G7 | Price `toStringAsFixed(0)`, no `NumberFormat('en_IN')` | grid `:~460`, detail price | 2/1/3/1 | A |
| G8 | Buyer English-only while artisan Hindi-first | buyer screens EN + `नमस्ते`; artisan HI-first via `LanguageProvider` | 3/2/3/2 | B |
| G9 | Spinner-only loading, no shimmer; no pagination (`limit:50` hard) | `:216-244`, `:41` | 3/2/3/1 | B |
| G10 | Search clear-button dead (`suffixIcon` reads controller without listener) | `:140` | 2/1/2/1 | A |
| G11 | Bulk/cluster-buy depth shallow (capacity shown, no pooled RFQ → multi-artisan order split) | `clusters.py`, `supplier_comparison_screen` | 3/4/4/3 | D |
| G12 | No customization-request thread (Phase 5 claimed as form+chat on order/RFQ) | absent | 2/3/3/2 | C |

## 3. What NOT to fix now

- Semantic/embedding search (explicitly deferred `products.py:89-100`, `matching.py:17-20`) — keyword + curated catalog is enough for SIH.
- Live-GPS delivery tracking — status flow (`pending→confirmed→shipped→delivered→paid`, `orders.py:4-5`) suffices.
- Production payments — out of scope per AGENTS.md.

## 4. Minimal premium path (no rewrites)

1. Seed 20–30 products + fix categories + real ratings (makes G1/G4 vanish).
2. Make badges data-driven (hide when `rating/review_count/cluster` absent) — 1-file fix in `_ProductCard`.
3. Add storefront sheet/route reusing detail widgets (single owner: buyer files).
4. Add sort row (Featured / Price ↑↓ / Rating) mapping to existing `min/max_price` + client sort; expose price filter chips.
5. Gallery: `PageView` of `images[]` (backend already supports `images` in seeds) + hero; `NumberFormat` price.
6. Wishlist local-first (`shared_preferences`, already a dep) before any cart work.
