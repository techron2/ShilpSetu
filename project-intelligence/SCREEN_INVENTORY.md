# SCREEN_INVENTORY — Every Screen, Route, and Nav Edge

> Verified via `frontend/lib/screens/**/*.dart` (24 files) + `lib/main.dart`. No `go_router`, no named routes. All navigation is `Navigator.push(MaterialPageRoute)` / `pop` / `IndexedStack`.

## 0. App shell

- `lib/main.dart:15-46` — `main()` → Firebase init → `MyApp` (`typedef ShilpSetuApp=MyApp:46`) → `MultiProvider[NavigationProvider, AppAuthProvider, ProductProvider, LanguageProvider]` → `MaterialApp(title:'ShilpSetu - Artisan App', theme:AppTheme.lightTheme, home:AuthGate)`.
- `lib/main.dart:55-90 AuthGate` — `StreamBuilder(authStateChanges)` → waiting spinner → authed `MainScreen`, else `AuthWrapper`. On auth: `popUntil(isFirst)`, `NavigationProvider.setIndex(0)`, `LanguageProvider.syncFromProfile`.
- `lib/main.dart:93-119 AuthWrapper` — `AnimatedSwitcher` login ↔ signup (no route stacking).
- `lib/screens/main_screen.dart` — role branch on `AppAuthProvider.userModel.isBuyer`:
  - `_ArtisanMainScreen`: `IndexedStack[HomeScreen, CatalogScreen, OrdersScreen, ProfileScreen]` + `BottomNav[Home, Catalog, Orders, Profile]` + `PopScope(double-back-exit)` + terracotta `AppBar` + 3 actions (Analytics, Cluster dialog, Assistant) + `FAB.extended(AI व्यापार सहायक)`.
  - `_BuyerMainScreen`: local `int _currentIndex` (NOT `NavigationProvider`) + `IndexedStack[BuyerHomeScreen, RfqScreen, BuyerOrdersScreen, ProfileScreen]` + `BottomNav[Discover, RFQ, Orders, Profile]` + name-chip AppBar (null on Discover — owns `SliverAppBar`).

## 1. Auth (4)

| File | Class | In → Out |
|---|---|---|
| `screens/auth/login_screen.dart` | `LoginScreen` | Email + phone/OTP demo (`findUserByPhoneNumber`); success `pushAndRemoveUntil(MainScreen)` ×3; → `ForgotPasswordScreen`; `onSwitchToSignUp` callback; hardcoded `'ShilpSetu'` logo `:131` |
| `screens/auth/signup_screen.dart` | `SignupScreen`, `_RoleCard` | 2-step form → role picker (default artisan, saved `users.role`); success `pushAndRemoveUntil(MainScreen)`; `onSwitchToLogin` |
| `screens/auth/forgot_password_screen.dart` | `ForgotPasswordScreen` | `sendPasswordResetEmail` → `pop` |
| `screens/auth/language_selection_screen.dart` | `LanguageSelectionScreen` (6 langs) | **ORPHAN** — imported but never pushed from login/signup; only self-links to `SignupScreen` |

## 2. Shared tabs (4)

| File | Class | Notes |
|---|---|---|
| `screens/home_screen.dart` | `HomeScreen` (artisan dashboard) | Greeting, quick actions → `MyProductsScreen`, `AnalyticsScreen`, `BusinessAssistantScreen` ×3 |
| `screens/catalog_screen.dart` | `CatalogScreen` | **DEAD/DIVERGENT**: 4 hardcoded `_catalogItems` (icon + Hindi string price/stock, `:8-45`), → `PhotoCaptureScreen` only. Real inventory is `MyProductsScreen`. Must rewire or remove before demo |
| `screens/orders_screen.dart` | `OrdersScreen`, `_RestFallbackOrders`, `_ArtisanOrderCard` | Firestore `orders.where(artisan_id).orderBy(created_at)` stream + REST fallback; → `ChatScreen`; status advance + chat buttons |
| `screens/profile_screen.dart` | `ProfileScreen` | Shared; null-user fallback persona (Radha Devi / Gorakhpur cluster); sign-out → `AuthGate` ×2 |

## 3. Artisan creation wizard (4 + review)

| File | Step | Notes |
|---|---|---|
| `screens/artisan/photo_capture_screen.dart` | 1. Photo | `image_picker` camera/gallery + `AiCatalogService.enhanceImage`; before/after view; one-tap sample (`_kSampleCraftUrl` Unsplash `:27`); → `VoiceCatalogScreen(imageUrl)` |
| `screens/artisan/voice_catalog_screen.dart` | 2. Voice | `record` WAV 16kHz mono → `AiCatalogService.voiceToListing`; language dropdown (hi/en/mr/ta); timer + static bars; one-tap `sampleTranscript` test path `:147`; → `ListingReviewScreen` (see VOICE_CATALOG_AUDIT.md) |
| `screens/artisan/listing_review_screen.dart` | 3. Review | Bilingual title/desc tabs (editable), category dropdown, removable feature chips, transcript banner (read-only), `PricingService.suggestPrice` card + apply; publish via `ProductProvider.addProduct` → `popUntil(isFirst)` |
| `screens/artisan/add_product_screen.dart` | Manual alt | `productToEdit==null?create:edit` form; `pop(true)`; → `PhotoCaptureScreen`; category const list |
| `screens/artisan/my_products_screen.dart` | Inventory | `ProductProvider.fetchProducts` (fallback id `artisan_001`); add/edit → `AddProductScreen`, detail → `ProductDetailScreen`; `_ProductCard` horizontal 88×88 + delete dialog; `_EmptyView/_ErrorView` |
| `screens/artisan/product_detail_screen.dart` | Detail | Props `productId, initialProduct?`; HI/EN tabs; edit → `AddProductScreen`, delete → double `pop` |
| `screens/artisan/business_assistant_screen.dart` | Assistant | Chat to `AssistantService.askAssistant`; quick HI/EN prompts; mic button is **simulated** (`_simulateVoiceRecording:142` bottom-sheet chips, no STT) |

## 4. Buyer (6)

| File | Class | Notes |
|---|---|---|
| `screens/buyer/buyer_home_screen.dart` | `BuyerHomeScreen`, `_ProductCard` | `SliverAppBar` search + animated category chips (`All,Textiles,Pottery,Jewelry,Embroidery,Woodwork,Leather,Painting,Metalwork` `:18`) + result count + 2-col grid (`childAspectRatio 0.68`); → `BuyerProductDetailScreen(product:Map)`. Empty → `_emptyState` + Show-all |
| `screens/buyer/buyer_product_detail_screen.dart` | `BuyerProductDetailScreen`, `_QuantityButton` | Props `product:Map`; `SliverAppBar` 280 image; trust/cluster badges; passport QR (`QrImageView`); promo caption + `share_plus`; order via `BuyerService.createOrder`; → `ChatScreen/RfqScreen/SupplierComparisonScreen` |
| `screens/buyer/rfq_screen.dart` | `RfqScreen`, `_RfqCard` | Prop `prefilledProduct?`; 5 suggestion chips; free-text → `createRfq` (Gemini) → structured review → `SupplierComparisonScreen(matches, requirement)` |
| `screens/buyer/supplier_comparison_screen.dart` | `SupplierComparisonScreen`, `_SupplierCard`, `_ComparisonTable` | Props `matches, requirement`; top-3 side-by-side (price/capacity/rating); → detail/chat |
| `screens/buyer/buyer_orders_screen.dart` | `BuyerOrdersScreen`, `_OrderCard` | REST `getOrders(buyerId)` + status chips; → `ChatScreen` |
| `screens/buyer/chat_screen.dart` | `ChatScreen`, `_MessageBubble` | Props `currentUserId/Name, otherUserId/Name, isCurrentUserArtisan`; Firestore stream via `ChatService` (shared artisan+buyer) |

## 5. Cluster + Analytics (2)

| File | Type | Notes |
|---|---|---|
| `screens/cluster/virtual_cluster_dialog.dart` | `showModalBottomSheet`, NOT a route | Create/join/view via `BuyerService.createCluster/joinCluster/getClusterByArtisan` |
| `screens/analytics/analytics_screen.dart` | `AnalyticsScreen(optional artisanId)` | `fl_chart` trend + `getAnalyticsSummary/getTrustScore`; fallback id `artisan_demo_01` |

## 6. Navigation gaps / collision notes

- Two bottom-nav systems share theme but not state (`NavigationProvider` artisan-only vs buyer local index) — safe to style jointly, risky to unify state in one PR.
- `LanguageSelectionScreen` orphan: wiring it into signup is a small isolated task (`signup_screen.dart` owner).
- `CatalogScreen` vs `MyProductsScreen` duplication is the #1 judge-confusion risk; fix owns `main_screen.dart:43-48` + `catalog_screen.dart`.
- No artisan storefront route exists (buyer card tap → detail only). Adding one touches `buyer_home_screen.dart`, `buyer_product_detail_screen.dart`, `buyer_service.dart` — keep as single-owner task.
- No wishlist/cart routes; Order Now is direct-create (`buyer_product_detail_screen.dart:599-612`). Do not bolt cart onto orders screens in parallel with order-status work.
