# Phase-Wise Prompts for Google Antigravity — Artisan Market Linkage App

## How to use this document
Antigravity works best when you give it one clear, scoped, high-level goal at
a time (via the **Manager view**, as a new task/agent), rather than one giant
"build the whole app" prompt. Paste each phase's prompt as a **separate task**.
Let the agent finish, review its plan + artifacts (screenshots, walkthrough,
test results), approve or give feedback, then move to the next phase.

Always start your very first prompt (Phase 0) by telling the agent your tech
stack explicitly — otherwise it may pick something else on its own.

---

## PHASE 0 — Project Scaffolding & Repo Setup

### Prompt to paste into Antigravity:
```
I am building a mobile app for a Smart India Hackathon project called an
"AI-Driven Market Linkage and Smart Cataloging App for Marginalized
Artisans." I have no tech background, so set everything up for me and
explain each step in the walkthrough artifact.

Tech stack (use exactly this, do not substitute):
- Frontend: Flutter (Dart), cross-platform mobile app
- Backend: Python Flask REST API
- Database + Auth + Storage: Firebase (Firestore, Firebase Auth, Firebase
  Storage)
- State management in Flutter: Provider
- Version control: Git, with a GitHub repo

Task for this phase:
1. Create a monorepo with two top-level folders: /frontend (Flutter project)
   and /backend (Flask project).
2. Initialize the Flutter project with a bottom navigation bar containing
   4 placeholder tabs: Home, Catalog, Orders, Profile. Use a clean, minimal,
   accessible UI with large tap targets and simple icons (this app is for
   low-digital-literacy users).
3. Initialize the Flask project with a basic app.py, a /routes folder, a
   /services folder, a health-check endpoint GET /api/health that returns
   {"status": "ok"}, and a requirements.txt with flask, flask-cors,
   python-dotenv, firebase-admin.
4. Set up Firebase: generate the firebase_options.dart config placeholder
   and firebase-admin service account placeholder (I will paste in real
   keys later), and add firebase_core, firebase_auth, cloud_firestore,
   firebase_storage to pubspec.yaml.
5. Create a README.md in the root explaining, in plain non-technical
   language, how to run the Flutter app and how to run the Flask server
   locally.
6. Run the Flutter app in a connected emulator/browser and confirm all 4
   tabs render with no errors. Run the Flask server locally and confirm
   GET /api/health returns 200.
7. Initialize git, create a .gitignore for both Flutter and Python, and
   make the first commit.

Show me the final folder structure and a screenshot/walkthrough of the app
running with all 4 tabs visible.
```

### Features built in this phase:
- None of the artisan/buyer-facing features yet — this is pure
  infrastructure: repo, Flutter shell app with navigation, Flask skeleton,
  Firebase wiring, git setup.

---

## PHASE 1 — Authentication + Core Product/Inventory CRUD (Mock-first)

### Prompt to paste into Antigravity:
```
Continue building the artisan marketplace app (Flutter + Flask + Firebase,
same stack as before, in the existing /frontend and /backend folders).

Goal for this phase: build Login/Signup and basic product management, with
frontend and backend built in parallel using mock data first, then wired
together.

Backend tasks:
1. Build Flask endpoints under /api/products:
   - POST /api/products (create product: fields = artisan_id, title,
     description, image_url, price, stock_quantity, category)
   - GET /api/products (list all products, support ?artisan_id= filter)
   - GET /api/products/<id>
   - PUT /api/products/<id>
   - DELETE /api/products/<id>
2. Connect these endpoints to Firestore (collection: "products") using
   firebase-admin.
3. Build /api/users endpoints for basic profile read/update (Firestore
   collection: "users"), separate from Firebase Auth (Auth handles
   login/password, Firestore "users" stores profile info like name,
   role: "artisan" or "buyer", language preference, phone).
4. Write a Postman collection (export it as a JSON file into
   /backend/postman) covering every endpoint above with example
   request/response bodies, and test each one, showing me the results.

Frontend tasks:
1. Build Login and Signup screens wired to real Firebase Authentication
   (email/password). After signup, ask the user to pick a role: "I am an
   Artisan" or "I am a Buyer", and save that to Firestore "users"
   collection.
2. Build a "My Products" screen (for artisan role) showing a list of
   products with image, title, price, stock — initially populated from
   local mock/dummy data (create a MockProductService with 5 sample
   products) so the UI can be tested before the backend is fully wired.
3. Build an "Add Product" form screen (title, description, price, stock,
   category — no AI yet, just a manual form) that calls the mock service.
4. Add a config flag (e.g., ApiConfig.useMock = true) so I can flip
   between MockProductService and a RealProductService that calls the
   Flask API at http://10.0.2.2:5000 (Android emulator) or
   http://localhost:5000.
5. Once the Flask endpoints are confirmed working in Postman, flip
   useMock to false and re-test the same screens against the real backend.
   Show me before/after screenshots.

At the end, confirm: I can sign up as an artisan, log in, add a product
through the form, and see it appear in both the app list and Firestore
console.
```

### Features built in this phase:
- User Signup/Login (artisan & buyer roles)
- Basic Inventory Management (add/view/edit/delete product) — manual, no
  AI yet
- Artisan/Buyer role separation foundation

---

## PHASE 2 — AI Photo Enhancement + Voice-to-Catalog + Multilingual Listing

### Prompt to paste into Antigravity:
```
Continue building the same app (Flutter + Flask + Firebase). This phase
adds the core AI features: photo enhancement, voice-to-catalog, and
multilingual listing generation.

Backend tasks:
1. Add an image enhancement service: install and use the `rembg` library
   for background removal, and OpenCV (cv2) for auto brightness/contrast
   correction and resizing to a standard e-commerce ratio (e.g., 1:1,
   1080x1080). Expose it as POST /api/products/enhance-image, accepting
   an uploaded image file and returning the enhanced image (upload the
   result to Firebase Storage and return its public URL).
2. Add a voice-to-catalog pipeline:
   - POST /api/catalog/voice-to-listing accepts an audio file + a
     language code (e.g., "hi", "mr", "ta").
   - Transcribe it to text using Whisper (use the local/open-source
     whisper library so there's no API cost) or Google Speech-to-Text if
     Whisper isn't feasible.
   - Send the transcript to the Gemini API with a prompt instructing it to
     extract a structured product listing: {title, description, category,
     key_features}.
   - Use Google Translate API to produce both English and Hindi versions
     of the title and description.
   - Return: {title_en, title_hi, description_en, description_hi,
     category, key_features}.
3. Write Postman tests for both endpoints using a sample image and a
   sample short audio clip, and show me the actual output JSON.
4. Add proper error handling (e.g., unclear audio, unsupported language)
   with friendly error messages the frontend can display directly to a
   low-literacy user (short, simple, translated if possible).

Frontend tasks:
1. Build a Camera/Photo Capture screen: take or pick a photo, show a
   loading state ("Enhancing your photo..."), then show a before/after
   comparison view once the enhanced image returns from the backend.
2. Build a Voice Recording screen: a large record button, a visual
   timer/waveform while recording, a "Processing..." state after stopping,
   then a Review screen showing the AI-generated title and description in
   both English and Hindi, with the ability to edit either before saving.
3. Wire both screens into the "Add Product" flow from Phase 1, so the full
   sequence becomes: take photo → enhance → record voice → review
   AI-generated bilingual listing → save product.
4. Keep using the mock/real flag pattern: build these screens against a
   temporary mock response first if the backend isn't ready yet, then
   switch over once the endpoints are live.

At the end, demonstrate the full flow live: photograph a real object,
confirm the background is removed/cleaned, speak a short product
description in Hindi (or English), and confirm a proper bilingual listing
is generated and saved.
```

### Features built in this phase:
- 📸 AI Product Photography (background removal, lighting/contrast fix)
- 🎤 Voice-to-Catalog (speech → structured listing)
- 🌐 Multilingual Listing (regional language → Hindi + English)

---

## PHASE 3 — Smart Pricing + AI Business Assistant

### Prompt to paste into Antigravity:
```
Continue building the same app. This phase adds AI-driven pricing and a
basic AI business assistant chat.

Backend tasks:
1. Build a Scikit-learn price prediction model:
   - Since I have no real historical pricing dataset, generate a
     reasonable synthetic training dataset (a CSV with ~200-300 rows)
     with columns: category, material_cost, size (small/medium/large),
     region, and price — using realistic ranges for Indian handicrafts
     (e.g., textiles ₹300-3000, pottery ₹150-1500, jewelry ₹200-5000).
     Explain your assumptions in the artifact so I can adjust them later.
   - Train a regression model (RandomForestRegressor or similar) on this
     data, save it as price_model.pkl.
   - Expose POST /api/pricing/suggest accepting {category, material_cost,
     size, region} and returning {suggested_price, price_range_min,
     price_range_max, explanation} where explanation is a short plain-
     language reason (e.g., "Based on similar handwoven textiles in your
     region").
2. Build a simple AI Business Assistant endpoint: POST
   /api/assistant/ask accepting {artisan_id, question} (free text, e.g.
   "Why aren't my products selling?" or "What price should I set for
   diwali season?"). Use the Gemini API, giving it context about the
   artisan's own products/sales pulled from Firestore, and return a
   short, actionable, encouraging answer in the artisan's preferred
   language.
3. Test both endpoints in Postman with at least 3 different example
   inputs each and show me the results.

Frontend tasks:
1. Add a "Suggested Price" card to the Add Product flow (after the
   listing is generated): show the AI-suggested price prominently, with
   the price range below it, and let the artisan override it manually if
   they want.
2. Build a simple chat-style "Ask your Business Assistant" screen: a chat
   bubble UI, a text input, and voice input reusing the recording
   component from Phase 2 so low-literacy users can also just speak their
   question.

At the end, confirm: creating a new product shows a sensible AI-suggested
price, and I can ask the assistant a business question and get a helpful
answer back.
```

### Features built in this phase:
- 💰 Smart Pricing (AI-suggested competitive price)
- 🤖 AI Business Assistant (basic Q&A / recommendations)

---

## PHASE 4 — Buyer Side: Search, Matching, RFQ, Orders

### Prompt to paste into Antigravity:
```
Continue building the same app. This phase focuses entirely on the Buyer
experience and connecting buyers to artisans.

Backend tasks:
1. Build GET /api/products/search?query=<text>&category=&max_price= —
   start with simple keyword/category/price-range filtering over the
   Firestore "products" collection (no heavy NLP needed yet — this alone
   satisfies "AI Product Search" for a hackathon prototype; note in the
   artifact how this could be upgraded to embedding-based semantic search
   later).
2. Build POST /api/matching/buyer-supplier: given a buyer's requirement
   {category, quantity, budget, region}, compute cosine similarity
   (Scikit-learn) between the requirement and available products/artisan
   profiles, and return a ranked list of best-matching artisans/products.
3. Build POST /api/rfq: given free-text buyer requirements, use the
   Gemini API to generate a structured RFQ object {category, quantity,
   target_price, deadline, specifications, description}, save it to a
   Firestore "rfqs" collection.
4. Build /api/orders endpoints: POST (create order), GET (list, filter by
   buyer_id or artisan_id), PUT (update status: pending/confirmed/
   shipped/delivered/paid).
5. Test all endpoints in Postman with realistic sample data and show me
   results.

Frontend tasks:
1. Build the Buyer home/search screen: a search bar, category filter
   chips, and a scrollable product grid/list showing image, title, price,
   artisan name/rating.
2. Build a Product Detail screen for buyers: images, bilingual
   description, price, a "Request Quote"/RFQ button, an "Order Now"
   button, and a placeholder "View Digital Passport" button (built fully
   in the next phase).
3. Build an RFQ creation screen: a simple form or a free-text box (buyer
   describes what they need in plain language, e.g. "I need 200 cotton
   sarees for a retail chain by next month") that calls the RFQ endpoint
   and shows the AI-structured result for the buyer to confirm.
4. Build a Supplier/Product comparison screen showing 2-3 matched
   artisans/products side by side (price, capacity, rating).
5. Build an Orders screen for both artisan and buyer views (list with
   status badges), and a basic Chat screen using Firestore's real-time
   listeners directly (no need to route this through Flask).

At the end, demonstrate: a buyer searches for a product category, views
details, submits an RFQ in free text, sees AI-matched suppliers, and
places an order that then appears in the artisan's Orders screen.
```

### Features built in this phase:
- 🔍 AI Product Search
- 🤖 AI Supplier Matching
- 📋 AI RFQ Generator
- 💰 Price & Supplier Comparison
- 📦 Bulk Ordering / Order & Payment Management (basic status flow)
- 💬 Chat/Negotiation with Sellers
- 🚚 Order & Delivery Tracking (status-based, not live GPS)

---

## PHASE 5 — Digital Product Passport, Clusters, Analytics, Sharing, Trust Score

### Prompt to paste into Antigravity:
```
Continue building the same app. This phase adds the differentiator
features that make the app stand out in a hackathon demo.

Backend tasks:
1. Build GET /api/passport/<product_id> returning a public JSON payload
   (artisan story, product story, materials used, region, certification
   if any) suitable for rendering on a simple public web page (no login
   required) — this is what the QR code will link to.
2. Build GET /api/analytics/summary?artisan_id= aggregating: total sales,
   revenue this month vs last month, best-selling product, average
   order value — computed from the "orders" and "products" Firestore
   collections.
3. Build a basic trust score calculation: a weighted average of order
   completion rate + average buyer rating, exposed via
   GET /api/users/<id>/trust-score, and update it whenever an order is
   marked delivered/rated.
4. Build POST /api/promo/generate: given a product_id, use the Gemini API
   to generate a short promotional caption suitable for WhatsApp/social
   sharing, in the artisan's preferred language.
5. Test all endpoints in Postman and show me results.

Frontend tasks:
1. On the Product Detail screen, generate and display a QR code (using
   the qr_flutter package) that links to the public passport page from
   the backend.
2. Build a simple "Virtual Cluster" feature: allow an artisan to
   create/join a cluster (a Firestore document listing member artisan
   IDs and combined production capacity), and show buyers a "cluster"
   badge on products that belong to one, with the combined capacity
   visible.
3. Build an Analytics dashboard screen for artisans using the fl_chart
   package: a simple bar or line chart of sales over time, plus summary
   cards (total revenue, best seller).
4. Add a "Share to WhatsApp" button on the product detail/listing screen
   using the share_plus package, pre-filled with the AI-generated
   caption and the enhanced product image.
5. Show a star-rating / trust-score badge on artisan profiles and in
   buyer search results.

At the end, demonstrate: scanning a product's QR code opens its public
passport page, an artisan dashboard shows real sales charts, and tapping
"Share" opens WhatsApp with a pre-filled AI caption and image.
```

### Features built in this phase:
- 🪪 Digital Product Passport + QR
- 🏭 Virtual Artisan Cluster
- 📊 Sales & Profit Analytics (artisan + buyer purchase history)
- 📱 Social/WhatsApp Sharing with AI-generated captions
- ⭐ Supplier Ratings & Trust Score
- 🎨 Customization Requests (can be added here as a simple form + chat
  message tied to an existing order/RFQ)

---

## PHASE 6 — Full Integration Pass, Testing, and Deployment

### Prompt to paste into Antigravity:
```
This is the final phase before demo day. Do a full pass across the whole
app (Flutter frontend in /frontend, Flask backend in /backend).

Tasks:
1. Go through every screen and confirm ApiConfig.useMock is set to false
   everywhere and every screen is calling the real Flask backend, not
   mock data. List any screens still using mock data.
2. Write basic automated tests:
   - Flutter: widget tests for the Login, Add Product, and Product Search
     screens.
   - Flask: pytest unit tests for the pricing model, the matching
     function, and at least one integration test per route file.
   Run all tests and show me pass/fail results, fixing any failures.
3. Add loading states, error states, and empty states to every screen
   that currently lacks them (important for a polished demo).
4. Prepare the backend for deployment to Render: add a
   render.yaml/Procfile, environment variable handling for all API keys
   (Gemini, Google Cloud, Firebase service account), and confirm it runs
   correctly on Render's free tier.
5. Build a release APK for the Flutter app (flutter build apk) so it can
   be installed on a judge's phone or demo device.
6. Write a DEMO_SCRIPT.md walking through the exact sequence I should
   follow live during the hackathon demo, covering: artisan signup →
   photo capture/enhancement → voice listing → AI price → buyer search →
   RFQ → order → QR passport → analytics — end to end, in the right
   order, so nothing is missed.

Show me the final test results, the deployed backend URL, and confirm the
APK builds successfully.
```

### Features built in this phase:
- No new features — this phase is full integration, automated testing,
  bug-fixing, deployment, and demo-readiness across everything built in
  Phases 0–5.

---

## Quick Reference Table

| Phase | Main Features Delivered |
|---|---|
| 0 | Project scaffold, navigation shell, Firebase wiring |
| 1 | Auth (artisan/buyer), basic product CRUD, inventory list |
| 2 | AI photo enhancement, voice-to-catalog, multilingual listing |
| 3 | Smart pricing, AI business assistant |
| 4 | Buyer search, supplier matching, RFQ generator, orders, chat |
| 5 | Digital passport + QR, clusters, analytics, WhatsApp share, trust score |
| 6 | Full integration, testing, deployment, demo prep |

Give the phases to Antigravity **in order**, one at a time, and review the
artifacts (walkthroughs/screenshots) it produces after each before moving
on — that review step is what keeps the agent's output aligned with what
you actually want, since it can otherwise drift on ambiguous instructions.
