# BRANDING_MIGRATION — ShilpSetu → KalaVistar Without Breaking Infra

> Method: case-insensitive grep excluding `.git/` (~66 ShilpSetu hits, 0 KalaVistar in code; only `AGENTS.md` + `.serena/project.yml` say KalaVistar). Per AGENTS.md: rename user-visible strings, keep technical identifiers.

## A. Safe user-facing rename candidates (do now, class A, I4/E1/D4/R1)

- `README.md:1,5,16` title + welcome + tree (`ShilpSetu/` → `KalaVistar/`).
- `frontend/lib/main.dart:36` OS title `'ShilpSetu - Artisan App'` → `'KalaVistar - Artisan Marketplace'`; add `KalaVistarApp` alias alongside `ShilpSetuApp:46` (keep typedef for compat).
- `frontend/lib/screens/auth/login_screen.dart:131` logo `'ShilpSetu'` → KalaVistar (respect `LanguageProvider`).
- `frontend/lib/providers/language_provider.dart` EN + 5 native strings: `:176 app_title`, `:189 login_title`, `:206 role_sub` + `hi:96 शिल्पसेतु`, `gu:256 શિલ્પસેતુ`, `mr:318 शिल्पसेतू`, `bn:380 শিল্পসেতু`, `ta:442 சிற்பசேது` (+ `:109,126,286,348,410,472` login/role variants). Needs native-speaker check: `कलाविस्तार` + transliterations.
- `frontend/lib/screens/main_screen.dart:51` `"शिल्पसेतु • होम"`, `:215` `"ShilpSetu • Discover"` AppBars.
- `frontend/lib/screens/home_screen.dart:71` fallback `'ShilpSetu Artisan'`.
- Buyer/artisan copy: `buyer_product_detail_screen.dart:81,84` share + hashtags, `my_products_screen.dart:300`, `add_product_screen.dart:152`, `business_assistant_screen.dart:61,253,428` persona.
- Backend public surfaces: `routes/passport.py:18,198,260` QR page title/body, `routes/promo.py:48,67,100,111,112` copy + `#ShilpSetu` → `#KalaVistar #VocalForLocal`, `app.py:56` `GET /` `"app":"ShilpSetu Backend API"`, `services/ai_service.py:135` + `assistant_service.py:226,295` persona prompts (safe reword, changes tone only).
- Docs/tests: `backend/postman/ShilpSetu_*.json` names, `test_phase4:304` + `test_phase5:51` prints, `AndroidManifest.xml:4 label="frontend"`, `ios/Runner/Info.plist:10,18 Frontend`, `pubspec.yaml:1 name:frontend` → `kalavistar` (requires updating `package:frontend/...` import in `test/recording_file_test.dart:5` together — do atomically or skip).
- Comments only (lowest priority): `.gitignore:2`, `api_config.dart:1`, `app_theme.dart:3`, `app_back_button.dart:3`, `models/*:1`, `routes/orders.py:2`, `test/widget_test.dart:5`.

## B. Technical identifiers — MUST KEEP (breakage risk)

- Android: `android/app/build.gradle.kts:8 namespace`, `:19 applicationId `com.shilpsetu.frontend``, `MainActivity.kt:1 package + folder path`, `Runner.rc:92,96 CompanyName` (binary identity side).
- Apple/Linux/Windows IDs: `ios/Runner.xcodeproj/project.pbxproj:386,567,589` + Tests `:402,419,434`, `macos/...:398,412,426` + `AppInfo.xcconfig:11,14`, `linux/CMakeLists.txt:10 APPLICATION_ID`.
- Firebase: `firebase_options.dart:30,40,50,60 projectId 'shilpsetu-37bcd'` + authDomain/storageBucket/appId/apiKey; `.env.example:10 STORAGE_BUCKET`, `serviceAccountKey.json.placeholder:4,7,12`, `firebase_service.py:33 placeholder-id guard`. New project = new keys + Firestore migration — never in a branding PR.
- Runtime: `app.py:16 logger "shilpsetu_backend"`, `routes/passport.py:270 salt "shilpsetu-gi-provenance"` (changing invalidates issued QRs), Postman `_postman_id`s, `config.py:3` stale local-path comment.

## Migration plan (3 PRs, single owner each)

1. **PR-B1 Flutter visible** (login, AppBars, language map, home fallback, share copy). Verify: cold start, login/signup, artisan+buyer shells, Hindi locale.
2. **PR-B2 Backend public** (`app.py` root, passport HTML, promo hashtags, AI persona strings). Verify: `GET /`, `/passport/<id>` HTML, promo generate hi+en, voice listing tone.
3. **PR-B3 Docs/meta** (README, Postman names, test prints, manifest labels). Verify: no import break (`package:frontend` atomically if renamed), `flutter analyze`.
