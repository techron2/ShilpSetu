# IMPLEMENTATION_ROADMAP — Scored, Sequenced, Parallel-Safe

> Scores: Impact 1–5 / Effort 1–5 / Demo 1–5 / Risk 1–5. Classes: A data/low-risk, B straightforward UI, C moderate integration, D difficult, E arch-sensitive. Owners = file boundaries; no two active tasks share a file without checkpoint.

## Phase 0 — Unblock (½ day, sequential, strong agent not needed)

| ID | Task | Files | I/E/D/R | Cls | Agent |
|---|---|---|---|---|---|
| 0.1 | Canonical categories (9) + seed-spec sign-off | `buyer_home_screen.dart:18`, `rfq.py:33`, pricing valid (FE `:60`), CSV | 5/1/5/1 | A | fast |
| 0.2 | Branding PR-B1 Flutter visible strings | login, AppBars, language map, share copy (list in BRANDING_MIGRATION.md §A) | 4/1/4/1 | A | fast |
| 0.3 | Runbook verify (health, enhance, voice-transcript, search-empty) | none (docs) | 4/1/3/1 | A | fast |

Checkpoint C0: category list frozen; screenshots of empty-home baseline.

## Phase 1 — Catalog + Trust (1–2 days, highest ROI)

| ID | Task | Files | I/E/D/R | Cls | Agent |
|---|---|---|---|---|---|
| 1.1 | `backend/seed_demo_catalog.py` (24 products, 6 artisans, idempotent) + run | NEW only + Firestore | 5/2/5/1 | A | fast/cheap |
| 1.2 | Data-driven badges (hide ★/Verified/Cluster when absent; `NumberFormat en_IN`) | `buyer_home_screen.dart:309-486` only | 5/1/5/1 | A | fast |
| 1.3 | Fix dead Catalog tab (rewire artisan Catalog → MyProducts content or remove tab) | `main_screen.dart:43-48`, `catalog_screen.dart` | 4/1/4/1 | A | fast |
| 1.4 | Analytics honest-mode (mock label vs live) | `analytics_screen.dart`, `routes/analytics.py:14-51` | 3/1/4/1 | A | fast |
| 1.5 | Branding PR-B2/B3 (backend public + docs/meta) | `app.py:56`, passport, promo, README/Postman | 4/1/4/1 | A | fast |

Parallel: 1.2 ∥ 1.3 ∥ 1.4 (disjoint files). 1.1 first (others assert on seeded data). 1.5 anytime.
Checkpoint C1: home ≥6 above-fold cards; each chip ≥2; matching ≥3; passport/promo OK on 3 ids. **Integration review required.**

## Phase 2 — Marketplace premium (2–3 days, 2 tracks max)

Track X (buyer discovery, single owner — strong UI agent):

| ID | Task | Files | I/E/D/R | Cls |
|---|---|---|---|---|
| 2X.1 | Sort + price-filter row (reuse `min/max_price`) | `buyer_home_screen.dart` | 4/2/4/1 | B |
| 2X.2 | Gallery (`PageView` images[]) + hero + price format | `buyer_product_detail_screen.dart` | 4/2/4/1 | B |
| 2X.3 | Storefront sheet (story from passport, collection via `?artisan_id=`, chat) | buyer home + detail + `buyer_service.dart` | 5/2/5/2 | B |
| 2X.4 | Wishlist local-first (`shared_preferences`) | buyer home/detail + new provider | 4/2/4/1 | B |
| 2X.5 | Shimmer/skeleton loading | buyer home/detail | 3/2/3/1 | B |

Track Y (artisan polish, single owner — moderate agent, NO recording-core edits):

| ID | Task | Files | I/E/D/R | Cls |
|---|---|---|---|---|
| 2Y.1 | Editable transcript + resubmit in review | `listing_review_screen.dart:306-333`, `ai_catalog_service.dart` | 4/2/4/2 | B |
| 2Y.2 | Record UX: cancel + 60s cap + retry-keeps-audio + lang align (6) + gate sample behind debug | `voice_catalog_screen.dart`, `language_provider.dart` | 4/2/4/2 | B |
| 2Y.3 | Token file (`app_tokens.dart`: radius/spacing/grey/gold) — no widget restyle yet | NEW + `app_theme.dart` ref | 3/1/3/1 | A |

Collision: X owns buyer files; Y owns artisan voice/review files. Shared `buyer_service.dart` (X.3) vs cluster work (Phase 3) — serialize.
Checkpoint C2: buyer demo (search→storefront→RFQ→compare→order→passport) + artisan demo (photo→voice→edit-transcript→price→publish→appears in buyer home). **Integration review required.**

## Phase 3 — Bulk + trust theater (2 days, moderate agents)

| ID | Task | Files | I/E/D/R | Cls |
|---|---|---|---|---|
| 3.1 | Cluster capacity on RFQ compare (pooled qty vs combined cap, join CTA) | `rfq_screen.dart`, `supplier_comparison_screen.dart`, `clusters.py` | 4/3/4/2 | C |
| 3.2 | QR/passport spotlight + share-caption polish (KalaVistar tags) | `routes/passport.py`, `promo.py`, detail QR/share | 4/1/5/1 | A |
| 3.3 | Font pass (1 display + 1 body, fallback-safe) | `pubspec.yaml`, `app_theme.dart` | 3/2/4/1 | B |
| 3.4 | Test refresh (widget labels, `requests`/`gTTS` test-deps note, DEMO_SCRIPT.md draft) | `test/`, new `DEMO_SCRIPT.md` (allowed? docs — put under root only if owner approves; else `project-intelligence/`) | 3/2/3/1 | A |

Checkpoint C3: bulk narrative (200 sarees → 2-cluster match → RFQ → order) + QR scan to public page on projector.

## Phase 4 — Selective wow (only if C1–C3 green)

| ID | Task | Files | I/E/D/R | Cls |
|---|---|---|---|---|
| 4.1 | Curated 3D for 2–3 heroes (GLB, rotate/pinch/reset/fullscreen) | new viewer + assets | 4/4/5/3 | D — strong agent only |
| 4.2 | Promo image card (enhanced image + caption composite for WhatsApp) | detail share path | 3/3/4/2 | C |
| 4.3 | `render.yaml`/deploy + release APK + final DEMO_SCRIPT | new infra files | 3/3/3/2 | C |

## File-ownership map (collision zones)

- Buyer home/detail: Track X exclusive until C2.
- Artisan voice/review: Track Y exclusive until C2.
- Categories: Phase 0 single owner; frozen after C0 (exact-match filter = silent conflicts).
- `buyer_service.dart` + `clusters.py`: X.3 vs 3.1 — serialize, same owner preferred.
- `app_theme.dart`/`pubspec.yaml`: token (2Y.3) → font (3.3) sequential, one owner.
- Branding lists: disjoint from functional files; safe parallel anytime.
- Recording core + image engine + matching/RFQ/pricing algorithms: NO owner (frozen).
