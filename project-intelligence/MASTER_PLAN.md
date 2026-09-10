# MASTER_PLAN — KalaVistar SIH Demo Execution Strategy

> Synthesizes all `project-intelligence/` docs. Read this first, then drill into specifics. Read-only audit; no code changed. Stack: one Flutter app (artisan+buyer) + Flask + Firestore, `ApiConfig.useMock=false`, `baseUrl=http://127.0.0.1:5000`, HEAD `0a9b4e0` voice fix pending hardware test.

## 1. Where we stand (brutal truth)

We have a **broad but hollow marketplace**: Phases 0–5 built an impressive surface (auth, artisan AI wizard, buyer search/RFQ/match/orders/chat, passport-QR, clusters, analytics, share, trust) yet the **live buyer home is empty** on a fresh DB, categories disagree across 7 lists (exact-match filter → silent zero-results), trust badges are hardcoded, the artisan Catalog tab is dead, and every screenshot says the wrong name (ShilpSetu, not KalaVistar). The two strongest assets — **before/after photo pipeline** and **honest voice→bilingual-listing loop** — are real but need catalog + polish to shine. Full evidence: `CURRENT_PRODUCT.md`, `SCREEN_INVENTORY.md`, `CATALOG_EXPANSION_PLAN.md`, `VOICE_CATALOG_AUDIT.md`, `DESIGN_SYSTEM_AUDIT.md`, `BRANDING_MIGRATION.md`.

## 2. Ordered execution (what to do first → last)

1. **FIRST (½ day): freeze categories + rename visible brand + verify runbook.** Canonical 9 (`Textiles, Pottery, Jewellery, Embroidery, Wood Craft, Leather, Painting, Metal Craft, Other`; kill `Jewelry`, normalize `Woodwork/Metalwork`). Flutter-visible ShilpSetu→KalaVistar (login, AppBars, language map, share copy). Confirm `GET /api/health`, enhance, voice-transcript, empty-search baseline. Owners: 1 fast agent; files disjoint from later work.
2. **SECOND (1–2 days): seed + honesty.** New `backend/seed_demo_catalog.py` → 24 products / 6 artisans (Gorakhpur, Kutch, Madhubani, Bastar, Saharanpur, Kundan) with real ratings/regions/stories; data-driven badges + `en_IN` prices; dead Catalog tab fixed; analytics labeled mock-vs-live. This alone makes the demo. Owners: seed+badges+tab can parallelize (disjoint files) after category freeze.
3. **THIRD (2–3 days, 2 tracks): premium marketplace + artisan polish.**
   - Track X (strong UI agent, buyer files only): sort/filter row → gallery + price format → storefront sheet → wishlist → shimmer.
   - Track Y (moderate agent, artisan files only, NO recording-core edits): editable transcript + resubmit → record UX (cancel/60s-cap/retry-keeps-audio/lang-align-6/debug-gated sample) → token file.
4. **FOURTH (2 days): bulk + trust theater.** Cluster capacity on RFQ compare; QR-passport spotlight + KalaVistar share tags; font pass; test refresh + demo script draft.
5. **LAST (only if above green): selective wow.** Curated 3D for 2–3 heroes (GLB rotate/pinch/reset/fullscreen), promo image card, deploy/APK/final script.

## 3. What to postpone / NOT build

Auto 2D→3D, semantic search, payments, RBAC overhaul, schema migration, package/Firebase renames, live-GPS, push infra, dark mode, full retheme, cart-checkout-coupons, microservices — see `DO_NOT_BUILD_NOW.md`. Any proposal matching that list is deferred past SIH regardless of merit.

## 4. Parallel map + collision zones

```
0.1 categories ──┐
0.2 branding-FE ─┼─→ C0 freeze ─→ 1.1 seed ─→ ┬─→ 1.2 badges ─→ C1 ─→ Track X (buyer) ─→ C2 ─→ 3.x ─→ C3 ─→ 4.x
0.3 runbook ─────┘                           ├─→ 1.3 catalog-tab ─┘              Track Y (artisan) ─┘
                                             └─→ 1.4 analytics-honest ─┘         1.5 branding-BE/docs (anytime, disjoint)
```

- ✅ Safe parallel: 1.2 ∥ 1.3 ∥ 1.4 ∥ 1.5 (disjoint files); X ∥ Y (buyer vs artisan ownership); branding ∥ anything (string-only files).
- 🚫 Collision: categories (exact-match `where(category==)` in `routes/products.py:127` — one owner, freeze at C0); `buyer_service.dart`+`clusters.py` (X.3 storefront vs 3.1 bulk — serialize, same owner preferred); `app_theme.dart`+`pubspec.yaml` (tokens → font sequential); recording core + image engine + matching/RFQ/pricing algorithms (FROZEN, no owner).
- File boundaries: buyer home/detail = X exclusive to C2; voice/review = Y exclusive to C2; seed script = NEW file only (never edit routes to seed).

## 5. Dependencies between tasks

- Everything buyer-visible depends on **1.1 seed** (empty DB invalidates all buyer QA).
- Badges (1.2) depend on **0.1 categories + 1.1 rating fields** (else defaults lie again).
- Storefront (2X.3) depends on **1.1 artisan diversity + passport stories** (needs `?artisan_id=` data + `artisan_story`).
- Bulk (3.1) depends on **1.1 multi-artisan same-craft + C2 storefront pattern** (capacity math needs real cluster members).
- 3D (4.1) depends on **C1–C3 green + 2–3 hero products with clean studio images** (no heroes → no 3D).
- Voice hardware test depends on **DEPENDENCY_MAP.md addressing** (`adb reverse` or `10.0.2.2` or LAN IP) + FFmpeg for non-WAV.

## 6. Agent capability per task

- **Fast/cheap (A-class data/strings):** 0.1, 0.2, 0.3, 1.1, 1.2, 1.3, 1.4, 1.5, 2Y.3, 3.2, 3.4 — explicit file lists, no reasoning traps.
- **Straightforward UI (B-class):** 2X.1, 2X.2, 2X.4, 2X.5, 2Y.1, 2Y.2, 3.3 — needs widget care + preserve nav/API contracts.
- **Moderate integration (C-class, careful agents):** 2X.3, 3.1 — touches service + multiple screens; assign single owner, require C2/C3 review.
- **Difficult (D-class, strong model only):** 4.1 curated 3D — new dep + assets + gesture handling; do not assign until catalog/storefront done.
- **Frozen (E-class, nobody):** recording core, image engine internals, matching/RFQ/pricing algorithms, Firebase/package IDs, schema migrations.

## 7. Impact/effort snapshot (top 8)

| Task | I/E/D/R | Class |
|---|---|---|
| Seed 24 + categories | 5/2/5/1 | A |
| Honest badges + en_IN | 5/1/5/1 | A |
| Storefront sheet | 5/2/5/2 | B |
| Before/after hero placement | 5/1/5/1 | A |
| Sort/filter row | 4/2/4/1 | B |
| Editable transcript | 4/2/4/4→2 | B |
| QR-passport spotlight | 4/1/5/1 | A |
| Brand rename visible | 4/1/4/1 | A |

Full scoring in `PREMIUM_OPPORTUNITIES.md` + `IMPLEMENTATION_ROADMAP.md`.

## 8. Checkpoints (integration review REQUIRED)

- **C0 Category freeze:** list in repo + chips/RFQ/pricing/CSV aligned; empty-home screenshot archived.
- **C1 Catalog live:** `search?limit=50`→24, each chip ≥2, matching ≥3 with scores, passport+promo OK on 3 ids, badges real, Catalog tab fixed, brand FE done. Reviewer runs buyer smoke on seeded DB before X/Y start.
- **C2 Dual-demo:** buyer path (search→storefront→RFQ→compare→order→passport) + artisan path (photo→voice→edit-transcript→price→publish→appears in buyer home) recorded back-to-back. Reviewer checks nav, loading/empty/error states, no sample-button confusion.
- **C3 Bulk+trust:** 200-sarees RFQ → cluster match → order; QR scan to `/passport/<id>` on projector; fonts + tests + script draft reviewed.
- **C4 Demo-ready (final state):** cold start → role pick → buyer home has 6+ above-fold cards with real images/prices/ratings → search/filter/sort respond → storefront opens → RFQ structures → compare shows capacity → order lands in artisan Orders + chat works → artisan photo→voice→publish appears live → QR scans to KalaVistar passport → analytics honest → no ShilpSetu visible in UI/passport/share/README-title → voice verified on hardware (or scoped as emulator-only with honest error paths).

## 9. Recommended next implementation phase (do exactly this)

Assign **3 fast agents in parallel**: (i) categories freeze + spec, (ii) branding PR-B1, (iii) runbook verify — then **single seed agent** (1.1) → **3 parallel honesty agents** (badges, catalog-tab, analytics-label + branding-BE/docs). Do not start Track X/Y until C1 passes. Keep voice core untouched; hardware owner runs `VOICE_CATALOG_AUDIT.md §6` checklist separately.

## 10. Document index

`CURRENT_PRODUCT.md` (truth) · `SCREEN_INVENTORY.md` (24 screens/nav) · `MARKETPLACE_GAP_ANALYSIS.md` (G1–G12) · `CATALOG_EXPANSION_PLAN.md` (24-product spec) · `VOICE_CATALOG_AUDIT.md` (HEAD + hardware checklist) · `DESIGN_SYSTEM_AUDIT.md` (tokens path) · `PREMIUM_OPPORTUNITIES.md` (P1–P15 scored) · `BRANDING_MIGRATION.md` (safe vs keep) · `DEPENDENCY_MAP.md` (runbook + traps) · `DO_NOT_BUILD_NOW.md` (guardrails) · `IMPLEMENTATION_ROADMAP.md` (phased owners) · this `MASTER_PLAN.md` (strategy).
