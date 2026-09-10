# CURRENT_PRODUCT — What KalaVistar Actually Is Today

> Read-only audit 2026-09-10. All paths relative to repo root. No code changed.

## 1. One-line truth

KalaVistar (repo still branded **ShilpSetu** in code) is a **working Flutter + Flask + Firebase monorepo** with a surprisingly complete Phase 0–5 feature surface (auth, artisan CRUD, AI photo/voice/pricing/assistant, buyer search/matching/RFQ/orders/chat, passport/QR/clusters/analytics/share/trust) but an **empty live catalog**, inconsistent categories, and buyer discovery that looks functional only when Firestore is seeded. See `phases.md:406-416`, `README.md:1-94` (outdated — claims only 4 artisan tabs).

## 2. Repo shape (verified)

```
KalaVistar/
  AGENTS.md                          # agent rules (KalaVistar branding, preserve arch)
  README.md:1-117                    # stale: ShilpSetu title, 4-tab artisan-only quickstart
  phases.md:1-421                    # Phase 0-6 build prompts; Phases 0-5 done, Phase 6 partial
  frontend/                          # Flutter, package name `frontend` (pubspec.yaml:1)
    lib/main.dart:15-46              # Firebase init + MultiProvider + MaterialApp(title:'ShilpSetu - Artisan App')
    lib/firebase_options.dart        # project `shilpsetu-37bcd` (all platforms same key)
    lib/config/api_config.dart:10,14 # useMock=false, baseUrl=http://127.0.0.1:5000
    lib/theme/app_theme.dart         # single ThemeData (terracotta/ochre/indigo/parchment)
    lib/models/ (4)                  # user_model, product_model, order_model, rfq_model
    lib/providers/ (4)               # auth, product, navigation (artisan only), language (6 langs)
    lib/services/ (11+3)             # auth, mock/real product + factory, buyer, assistant,
                                     # ai_catalog, chat (Firestore-direct), pricing, recording_file*
    lib/screens/ (24)                # main_screen shell + home/catalog/orders/profile +
                                     # auth(4) + artisan(7) + buyer(6) + cluster dialog + analytics
    lib/widgets/app_back_button.dart # only shared widget
  backend/
    app.py:28-70                     # create_app(), CORS *, /static/enhanced, init_firebase, 13 blueprints, port 5000
    config.py:1-11                   # hardcoded serviceAccountKey.json path (ignores .env var name)
    requirements.txt:1-15            # flask, firebase-admin, rembg, opencv-headless, SpeechRecognition,
                                     # deep-translator, google-genai, pydub, sklearn, pandas, joblib
    routes/ (13 + __init__.py)       # health, catalog, products, pricing, assistant, matching,
                                     # rfq, passport, analytics, promo, users, orders, clusters
    services/ (7)                    # firebase, ai (Gemini listing), speech (Google STT+pydub),
                                     # image (Gemini-image → OpenCV/rembg), assistant, pricing (RF model)
    data/handicraft_pricing_data.csv # 280-row synthetic pricing set
    services/price_model.pkl         # trained RandomForest (train_price_model.py:143-153)
    static/enhanced/ (~100 JPGs)     # enhancement outputs, NOT catalog seed
    test_phase{2,3,4,5}_endpoints.py # live-server requests scripts (not pytest)
    sample_craft.jpg / sample_audio.wav / test_hindi_speech.* # test fixtures
```

Counts: `frontend/lib/**/*.dart` ≈ 51 files, `backend/**/*.py` = 32 files, `frontend/test/*.dart` = 4 files, `frontend/assets/` = 0 files (no assets block in `pubspec.yaml:73-76`).

## 3. What genuinely works (with fallbacks)

| Flow | Frontend entry | Backend | Fallback if key/DB missing | Verdict |
|---|---|---|---|---|
| Auth email + role | `screens/auth/login_screen.dart`, `signup_screen.dart` → `providers/auth_provider.dart` → `services/auth_service.dart` (users coll) | Firebase Auth + Firestore `users` | none (needs Firebase) | Works if Firebase configured |
| Artisan CRUD | `screens/artisan/my_products_screen.dart`, `add_product_screen.dart` → `providers/product_provider.dart` → `services/real_product_service.dart` | `routes/products.py:29-272` (Firestore `products`) | `mock_product_service.dart` (5 items, dormant — `useMock=false`) | Works |
| Photo enhance | `screens/artisan/photo_capture_screen.dart` → `services/ai_catalog_service.dart:13` | `POST /api/products/enhance-image` → `services/image_service.py:334` (Gemini-image → OpenCV/rembg) | OpenCV path always works; saves `static/enhanced/studio_*.jpg` + `comparison_*.jpg`, served by `app.py:41-43` | Works, best demo visual |
| Voice-to-listing | `screens/artisan/voice_catalog_screen.dart` → `listing_review_screen.dart` | `POST /api/catalog/voice-to-listing` (`routes/catalog.py:54-130`) → `services/speech_service.py:143` (Google STT) → `services/ai_service.py:212` (Gemini bilingual) | Rule-based keyword extraction (`ai_service.py:53-113`); STT failure now honest 422 (HEAD `0a9b4e0`) | Works; needs physical-device mic test |
| Pricing | `listing_review_screen.dart:119` → `services/pricing_service.dart` | `POST /api/pricing/suggest` → `services/pricing_service.py` (RF model + 1.3× floor) | Heuristic table | Works |
| Assistant | `screens/artisan/business_assistant_screen.dart` → `services/assistant_service.dart` | `POST /api/assistant/ask` → `services/assistant_service.py:242` (Gemini + Firestore context) | Templated craft×region×intent answers | Works |
| Buyer search | `screens/buyer/buyer_home_screen.dart:39` → `services/buyer_service.dart:17` | `GET /api/products/search` (`routes/products.py:102-175`, substring + exact category) | none (empty list → `_emptyState`) | Works only if DB seeded |
| Matching | `screens/buyer/rfq_screen.dart` → `supplier_comparison_screen.dart` | `POST /api/matching/buyer-supplier` (`routes/matching.py:49-188`, TF-IDF cosine) | none | Works if products exist |
| RFQ | same | `POST /api/rfq` (`routes/rfq.py:120-187`, Gemini → regex fallback) | regex fallback + `source:no_db` offline id | Works |
| Orders | `screens/buyer/buyer_orders_screen.dart`, `screens/orders_screen.dart` (artisan stream + REST fallback) | `routes/orders.py:42-237` + trust recalc on status update | none | Works |
| Chat | `screens/buyer/chat_screen.dart` → `services/chat_service.dart` (Firestore `chats/{a_b}/messages` direct) | none (no Flask) | n/a | Works if Firestore rules allow |
| Passport/QR | `screens/buyer/buyer_product_detail_screen.dart:749` (`qr_flutter`) | `GET /api/passport/<id>` + `GET /passport/<id>` (`routes/passport.py`, `routes/__init__.py:34-37`) | mock passport defaults | Works, strong trust story |
| Clusters | `screens/cluster/virtual_cluster_dialog.dart` | `routes/clusters.py:33-261` (+ denormalized `users.cluster_id`) | `_MOCK_CLUSTERS` | Works |
| Analytics | `screens/analytics/analytics_screen.dart` (`fl_chart`) | `GET /api/analytics/summary` (`routes/analytics.py`) | mock baseline (₹84500/36 orders) — misleading if mistaken for real | Works; mock can fool demo |
| Promo/share | detail screen `share_plus` | `POST /api/promo/generate` (`routes/promo.py`, Gemini → template) | template | Works |

## 4. What is partial / mock / fragile

- **Empty live catalog.** `BuyerHomeScreen._loadAll → searchProducts(limit:50)` returns `[]` on fresh Firestore → judges see `_emptyState` (`buyer_home_screen.dart:277-306`). The 5-item `MockProductService` (`mock_product_service.dart:10-71`) and 4-item hardcoded `catalog_screen.dart:8-45` are unreachable/dead. Only seed path is `test_phase4_endpoints.py:38-127 --seed` (5 transient products).
- **Category chaos.** 7+ divergent lists (buyer chips vs `_CRAFT_CATEGORIES` vs pricing valid list vs CSV vs mocks — see CATALOG_EXPANSION_PLAN.md). `routes/products.py:127-128` exact-match `where(category==)` means one spelling drift = zero results.
- **Silent schema gaps.** `rating/review_count/region/artisan_name` injected by test seeds but absent from `Product` (`models/product_model.dart:2-51`); buyer UI defaults `rating=4.0`, `Verified/Cluster` badges render unconditionally (`buyer_home_screen.dart:424-457`).
- **Dead artisan Catalog tab.** Shell routes artisan `Catalog → catalog_screen.dart` (icon-only Hindi strings) while real inventory lives in `my_products_screen.dart` (reachable only via Home button). Judge confusion risk.
- **Orphan language picker.** `language_selection_screen.dart` imported but never pushed from login/signup flow.
- **Stale tests.** `test/widget_test.dart` expects old tab labels; backend tests are `requests` scripts needing live server + `requests`/`gTTS` (both missing from `requirements.txt`).
- **No deployment/demo artifacts.** `render.yaml`, `Procfile`, `DEMO_SCRIPT.md` all missing (Phase 6 unstarted). `frontend/README.md` is stock template; root `README.md` outdated.
- **Storage declared, unused.** `firebase_storage:^13.5.0` in `pubspec.yaml:42` but zero imports in `lib/`; images served from Flask `static/enhanced/` or hotlinked Unsplash.

## 5. What should be preserved

- One-Flutter-app two-role shell (`screens/main_screen.dart` + `AuthGate` in `main.dart:55-90`); `Provider` state; `ApiConfig` central URLs; Flask blueprint layout (`routes/__init__.py:17-31`); Firestore collections (`products/orders/users/rfqs/clusters`); all Gemini-with-fallback patterns; image before/after pipeline; honest-422 voice contract from HEAD; passport public route (QR deep link).

## 6. Biggest demo risks (summary)

1. Empty DB → empty buyer home (no wow in first 30s).
2. Category mismatch → search/RFQ/matching return nothing live.
3. Fake trust badges + mock analytics mistaken for real data.
4. Voice fix (`0a9b4e0`) unverified on hardware; iOS mic key missing.
5. `127.0.0.1:5000` base URL breaks on emulator/device without ADB/LAN change.
