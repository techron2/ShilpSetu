# DO_NOT_BUILD_NOW — Guardrails for SIH

> If a proposal matches this list, defer it past the demo regardless of technical merit. Per AGENTS.md: preserve working arch, smallest reliable fix, no enterprise scale.

## 1. Never in hackathon scope

- **Automatic 2D-image-to-3D generation.** Explicitly out (prompt direction). Future is curated GLB/GLTF for 2–3 heroes with rotate/pinch/reset/fullscreen only. No `three.js`/`NeRF`/`TripoSR` pipelines, no model-gen services.
- **Separate artisan/buyer apps or backend split.** One Flutter app, role branch in `main_screen.dart`. No microservices, no K8s, no new backend framework, no event bus.
- **Production auth overhaul** (RBAC server, OTP vendor, biometric, audit). `AuthService + users.role` suffices.
- **Payment gateway / settlement / GST invoicing.** `Order Now → status flow` + mock `paid` status is enough theater.
- **Firestore schema migration** (renaming `products/orders/users/rfqs/clusters`, splitting collections, composite-index redesign). Additive fields only (`rating/review_count/region` on products, `cluster_id` on users) with backfill in seed.
- **Package/Firebase renames** (`com.shilpsetu.frontend`, `shilpsetu-37bcd`, buckets, `shilpsetu-gi-provenance` salt, `MainActivity` path). See BRANDING_MIGRATION.md §B.
- **Semantic search / embedding upgrade** (noted as future in `products.py:89-100`, `matching.py:17-20`). Keyword + curated categories demo fine.
- **Live-GPS tracking, push-notification infra, production CDN/storage migration** (Storage dep unused — leave declared).

## 2. Do not rebuild working flows

- Voice recording core (`voice_catalog_screen.dart:59-135` + `recording_file_*` + `catalog.py:54-130` + `speech_service.py`) — HEAD `0a9b4e0` pending hardware test; improve around it (editable transcript, cancel, language align) but do not re-architect.
- Image pipeline dual-engine (`image_service.py:334-443` Gemini → OpenCV/rembg) — tune prompts/canvas, do not replace.
- RFQ regex fallback, pricing heuristic fallback, assistant templated fallback — these are demo insurance, not tech debt.
- `Provider` state, `MaterialPageRoute` nav, Flask blueprints, direct-Firestore chat — no Riverpod/Bloc/go_router/Socket migration.

## 3. Do not inflate roadmap with

Dark mode, full retheme, design-system package, cart+checkout+coupons, multi-warehouse inventory, seller payouts, recommendation engine training, load testing, E2E device farm, app-store release hardening. Each is Effort 4–5 / Risk 3–5 for Demo ≤3.

## 4. Allowed exceptions (smallest reliable fix only)

If a demo journey is broken end-to-end (e.g. buyer home empty, category filter zero-results, passport 404, order create 500 without DB), fix with additive seed, exact-match normalization, null-guard, or honest empty/error state — never a migration.
