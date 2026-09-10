# 🎨 KalaVistar
### *AI-Driven Market Linkage & Smart Cataloging for Marginalized Artisans*
> **Smart India Hackathon Project**

Welcome to **KalaVistar**! This platform empowers traditional and marginalized rural artisans (potters, weavers, handicraft makers) by giving them an accessible mobile app to digitize and sell their craft directly to national and global buyers.

---

## 📂 Project Structure (Monorepo)

Think of this project as having two main parts:
- **`frontend/` (The Mobile App)**: What the artisan sees and touches on their phone or screen. Built with **Flutter (Dart)** and designed with extra-large buttons, clean high-contrast colors, and audio-friendly visual cues for low-digital-literacy users.
- **`backend/` (The Engine / Server)**: What works behind the scenes to fetch data, handle orders, and securely connect to the database. Built with **Python Flask** and **Firebase Admin**.

```text
KalaVistar/
├── backend/                       # Python Flask server
│   ├── app.py                     # Main server entrypoint
│   ├── requirements.txt           # Required Python packages
│   ├── .env.example               # Environment variables template
│   ├── serviceAccountKey.json.placeholder # Firebase keys template
│   ├── routes/                    # API endpoints (/api/health, /api/catalog, /api/orders)
│   └── services/                  # Business logic & Firebase integration
├── frontend/                      # Flutter mobile/web app
│   ├── pubspec.yaml               # App libraries (Firebase & Provider)
│   ├── lib/
│   │   ├── main.dart              # App launch file
│   │   ├── firebase_options.dart  # Firebase configuration placeholder
│   │   ├── providers/             # State management (Navigation)
│   │   ├── screens/               # 4 Main Tabs (Home, Catalog, Orders, Profile)
│   │   └── theme/                 # Accessible Terracotta & Indigo theme
├── .gitignore                     # Prevents sensitive keys from being uploaded
└── README.md                      # This friendly guide!
```

---

## 🚀 Quickstart: How to Run Everything Locally

You don't need any complex technical background! Follow these simple steps in your terminal.

---

### Step 1: Run the Backend Server (Flask)

1. Open a terminal and move into the `backend` folder:
   ```bash
   cd backend
   ```

2. Install the necessary Python packages (you only need to do this once):
   ```bash
   pip install -r requirements.txt
   ```

3. Start the server:
   ```bash
   python app.py
   ```

4. **Verify it's running**:
   Open your browser and visit:
   [http://127.0.0.1:5000/api/health](http://127.0.0.1:5000/api/health)
   You should see:
   ```json
   {"status": "ok"}
   ```

---

### Step 2: Run the Mobile/Web App (Flutter)

1. Open a second terminal window and move into the `frontend` folder:
   ```bash
   cd frontend
   ```

2. Download all the required app dependencies:
   ```bash
   flutter pub get
   ```

3. Start the app on your computer's browser (Chrome or Edge):
   ```bash
   flutter run -d chrome
   ```
   *(Or connect an Android phone with USB debugging turned on and run `flutter run`)*

4. The app will open up with the 4 accessible tabs at the bottom:
   - **🏠 Home**: Daily artisan summary, greeting, and voice assistance shortcut.
   - **📦 Catalog**: Smart camera scanning to photograph and list handcrafted items.
   - **🚚 Orders**: Visual order cards showing pending, packed, and delivered items.
   - **👤 Profile**: Artisan story, region, and language selection.

---

## 🔑 How to Connect Real Firebase Keys (When Ready)

The project currently comes with safe placeholder files so you can develop immediately without any errors. When you are ready to connect your live Firebase project:

### 1. For the Backend (`serviceAccountKey.json`)
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Select your project and click the **Gear Icon (Project settings)** ⚙️ -> **Service accounts**.
3. Click **Generate new private key** and confirm.
4. Rename the downloaded `.json` file to `serviceAccountKey.json` and move it into the `backend/` folder.

### 2. For the Frontend (`firebase_options.dart`)
1. In Firebase Console, register a Web or Android app under **Project settings**.
2. Open `frontend/lib/firebase_options.dart`.
3. Replace the placeholder `apiKey`, `appId`, and `projectId` strings with the values shown in your Firebase Console.

---

## ♿ Accessibility Design for Artisans
- **Large Touch Targets**: Every navigation button and interactive card has a minimum height of `48-56 dp` to make tapping easy for hands accustomed to physical crafts.
- **High-Contrast Terracotta Theme**: Warm Indian handicraft color palette with deep indigo text ensuring readability in varied outdoor/workshop lighting conditions.
- **Visual Status Badges**: Clear icons (box, truck, tick) alongside text so users of varying literacy levels immediately understand order progress.
