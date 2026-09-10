# DESIGN_SYSTEM_AUDIT — Tokens, Cards, and Premium Path

> Source: `frontend/lib/theme/app_theme.dart:1-137`, `widgets/app_back_button.dart`, all buyer/artisan screens, `backend/routes/passport.py:21-25` (web fonts), `pubspec.yaml:66-102`.

## 1. What exists (single-file system)

- `AppTheme.lightTheme` only: Material3, `seedColor primaryTerracotta`, `scaffold bgParchment`. Palette (9 consts `:8-16`): `primaryTerracotta 0xFFB84A39`, `secondaryOchre 0xFFD48B38`, `darkIndigo 0xFF1B2A4A`, `bgParchment 0xFFFAF7F2`, `cardBg FFFFFFFF`, `borderGrey 0xFFE5DFD7`, `successGreen 0xFF2E7D32`, `inTransitBlue 0xFF1976D2`, `warningRed 0xFFD32F2F`.
- Type (5 styles `:91-117`): `headlineMedium 24/w800, titleLarge 20/w700, titleMedium 17/w600, bodyLarge 16/w500, bodyMedium 14/#4A5568`. **No custom font** (section commented `pubspec.yaml:84-102`); passport web uses `Outfit+Rozha One` (not in Flutter).
- Buttons: `Elevated ∞×54/r14/17w700`, `Outlined ∞×50/2px terracotta`. Cards: `white/e1.5/r16/borderGrey/margin 8-16`. AppBar: terracotta/white `20/w700`. BottomNav: white, terracotta selected, `#718096` unselected, e10.
- Reuse: **1 shared widget** (`AppBackButton` 48dp `arrow_back_rounded`, Hindi tooltip). No `AppColors/AppTextStyles/AppSpacing` files (grep 0 hits). No spacing scale.

## 2. Product cards (7 variants, 2 true)

1. Buyer grid `_ProductCard` (`buyer_home_screen.dart:309-486`): 2-col `0.68`, image flex5 + info flex4, 9px ochre category pill, 13/w700 2-line title, unconditional ★4.0/Verified/Cluster, `₹15/w900` terracotta.
2. Artisan list `_ProductCard` (`artisan/my_products_screen.dart:110-277`): horizontal Card, 88×88 image, ochre chip, 18/w800 price + stock, delete icon + dialog.
3. Legacy catalog row (`catalog_screen.dart:169-254`): 60px tinted Icon, Hindi title, String price + green stock pill (no image).
4–7. Supplier (`supplier_comparison_screen.dart:192`), RFQ (`rfq_screen.dart:358`), artisan order (`orders_screen.dart:231`), buyer order (`buyer_orders_screen.dart:150`) — domain rows, not product cards.

## 3. Inconsistencies (safest fix = tokens, not restyle)

- Terracotta forks: theme `B84A39` vs `C25A47` (`buyer_home:82` gradient) vs `D05C49` (`home_screen:27`) vs CSS `C85A32/9E3D1B` (passport).
- Gold forks: `D48B38` vs star `D4AF37`, cluster `F9F1DC/D4AF37` (`buyer_home:449-451`), dialog `8C6E14` (`home_screen:279-280`).
- Grey sprawl: `4A5568/4B5563/6B7280/718096/9CA3AF/6B5E57/5A4D45/2C221E` + `Colors.grey.shade*`.
- Radius sprawl: 4/6/8/10/12/14/16/20/24/30 + 99px pill — theme says 14/16.
- Button overrides: WhatsApp `25D366` (`buyer_detail:626`), successGreen Order (`:609`), darkIndigo analytics (`home:267`), gold-outline cluster, blue-outline compare.
- AppBars: theme bar vs buyer Discover `SliverAppBar 170` gradient+search pill (`buyer_home:74-164`) vs detail `SliverAppBar 280` image (`buyer_detail:308-322`) vs artisan action bar + assistant FAB (`main_screen:84-147`) vs buyer name-pill bar (`:249-308`).

## 4. Safest path to coherent KalaVistar identity (additive only)

1. **Token file (1 PR):** new `lib/theme/app_tokens.dart` — `radius (8/12/16/20)`, `spacing (4/8/12/16/24)`, `AppGrey` ramp, canonical `gold=D4AF37`, `terracotta` gradient pair; no widget edits yet. Owner: theme file only.
2. **Font (1 PR):** add 1 display + 1 body (e.g. Fraunces/Outfit + Inter — matches passport web) via `pubspec.yaml` fonts + `textTheme` mapping; fallback to system if license unclear. Owner: theme + pubspec.
3. **Card convergence (1 PR per card):** buyer grid + artisan list share `ProductImage`, `PriceText (en_IN)`, `TrustRow (data-driven)` partials; leave supplier/RFQ/order rows alone. Owners must not overlap (buyer card vs artisan card = separate PRs, shared partials agreed first).
4. **Button/AppBar pass (1 PR):** map WhatsApp/success/cluster/compare to token variants; keep behavior identical.
5. **States:** shimmer for buyer grid (`_loadAll`), skeleton for detail; keep spinner elsewhere. Owner: buyer files only.
6. **Assets:** add `assets/images/` placeholders + `cached_network_image` dep (new) — improves perceived richness instantly; owner: pubspec + buyer/artisan image widgets.

## 5. What NOT to do

- No full retheme, no dark mode, no design-system package, no auto-2D-to-3D. Curated GLB/GLTF later: selective `model_viewer`-style viewer with rotate/pinch/reset/fullscreen for 2–3 hero products only (needs new dep + asset pipeline — postpone past demo catalog + storefront).
