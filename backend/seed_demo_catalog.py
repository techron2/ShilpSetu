"""Seed a curated KalaVistar demo marketplace catalog into Firestore.

Creates ~24 products across 6 distinct artisans covering the canonical
category vocabulary, so a fresh/demo database no longer renders an empty
buyer marketplace.

Usage:
    cd backend
    python seed_demo_catalog.py            # live seed (skips existing demo docs)
    python seed_demo_catalog.py --dry-run  # validate dataset, touch nothing
    python seed_demo_catalog.py --update   # overwrite existing demo docs

Safety / idempotency:
    - All demo documents use deterministic IDs (demo_artisan_*, demo_product_*).
    - Default mode never overwrites: existing demo docs are skipped.
    - Nothing is ever deleted; non-demo documents are never touched.
    - Without a valid serviceAccountKey.json the script only validates the
      dataset locally (--dry-run report) and exits non-zero; it never claims
      a fake success.
    - Seeding writes Firestore directly (not via POST /api/products) because
      the create endpoint stores a fixed field subset, while buyer matching,
      passport and trust flows consume enrichment fields (region, rating,
      materials, images, story, artisan_cluster).

Canonical categories (see services/categories.py):
    Textiles, Pottery, Jewellery, Embroidery, Wood Craft, Leather,
    Painting, Metal Craft, Other
"""

import argparse
import os
import sys
from collections import Counter
from datetime import datetime, timezone

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from services.categories import CANONICAL_CATEGORIES, is_canonical_category  # noqa: E402

IMG = "https://images.unsplash.com/{}?auto=format&fit=crop&w=800&q=80"

# ---------------------------------------------------------------------------
# Artisans (6) — deterministic uids, distinct craft/region/story
# ---------------------------------------------------------------------------
ARTISANS = [
    {
        "uid": "demo_artisan_radha",
        "name": "Radha Devi",
        "email": "demo.radha@kalavistar.demo",
        "role": "artisan",
        "phone": "+91-9839001122",
        "language_preference": "hi",
        "artisan_cluster": "Gorakhpur Terracotta Heritage Cluster",
        "region": "Gorakhpur, Uttar Pradesh",
        "story": "Third-generation potter shaping GI-tagged Gorakhpur terracotta on a manual wheel, firing in a traditional wood kiln.",
    },
    {
        "uid": "demo_artisan_ramesh",
        "name": "Ramesh Chhipa",
        "email": "demo.ramesh@kalavistar.demo",
        "role": "artisan",
        "phone": "+91-9829003344",
        "language_preference": "hi",
        "artisan_cluster": "Bagru Dabu Handloom Collective",
        "region": "Bagru, Rajasthan",
        "story": "Master block-printer from Bagru using 200-year-old teak blocks and natural indigo vats for dabu mud-resist fabrics.",
    },
    {
        "uid": "demo_artisan_meera",
        "name": "Meera Kumari",
        "email": "demo.meera@kalavistar.demo",
        "role": "artisan",
        "phone": "+91-9431005566",
        "language_preference": "hi",
        "artisan_cluster": "Mithila Art Collective",
        "region": "Madhubani, Bihar",
        "story": "Mithila artist trained by her grandmother; paints kohbar motifs and stitches sujini embroidery with natural pigments and threads.",
    },
    {
        "uid": "demo_artisan_sukhdev",
        "name": "Sukhdev Sagar",
        "email": "demo.sukhdev@kalavistar.demo",
        "role": "artisan",
        "phone": "+91-9425007788",
        "language_preference": "hi",
        "artisan_cluster": "Bastar Dhokra Tribal Cooperative",
        "region": "Bastar, Chhattisgarh",
        "story": "Dhokra metalsmith practising 4,000-year-old lost-wax casting; every figurine is a single-pour, one-of-one tribal artifact.",
    },
    {
        "uid": "demo_artisan_abdul",
        "name": "Abdul Salim",
        "email": "demo.abdul@kalavistar.demo",
        "role": "artisan",
        "phone": "+91-9837009900",
        "language_preference": "hi",
        "artisan_cluster": "Saharanpur Woodcraft Guild",
        "region": "Saharanpur, Uttar Pradesh",
        "story": "Second-generation woodcarver working seasoned sheesham with hand chisels; builds furniture meant to last decades.",
    },
    {
        "uid": "demo_artisan_kamla",
        "name": "Kamla Soni",
        "email": "demo.kamla@kalavistar.demo",
        "role": "artisan",
        "phone": "+91-9828011223",
        "language_preference": "hi",
        "artisan_cluster": "Johari Bazaar Jewellery Cluster",
        "region": "Jaipur, Rajasthan",
        "story": "Kundan jadau artisan from Johari Bazaar setting uncut polki in traditional ghats, plus Rajasthani leather accessory craft.",
    },
]

# ---------------------------------------------------------------------------
# Products (24) — id, artisan uid, title, description, category, price,
# stock, image, rating, reviews, materials, story. Region/cluster derive
# from the artisan so storefront/matching/passport stay coherent.
# ---------------------------------------------------------------------------
# (artisan, doc_id, title, description, category, price, stock,
#  image_id, rating, reviews, materials, story, gi_tag|None)
_RAW_PRODUCTS = [
    ("demo_artisan_radha", "demo_product_kulhad_01",
     "Handcrafted Terracotta Chai Kulhad Set (6 pcs)",
     "Hand-thrown kulhads from natural river clay, kiln-fired for an earthy aroma. Set of 6, food-safe and biodegradable. शुद्ध मिट्टी के कुल्हड़, चाय का स्वाद बढ़ाएँ।",
     "Pottery", 350, 500, "photo-1615865417491-9941019fbc00", 4.7, 212,
     ["Natural River Clay", "Organic Slip", "Rice Husk Ash"],
     "Shaped by Radha Devi on a manual wheel and fired in the family wood kiln.",
     "Gorakhpur Terracotta (GI)"),
    ("demo_artisan_radha", "demo_product_diya_01",
     "Hand-painted Diwali Diya Set (12 pcs)",
     "Festive clay diyas painted in marigold and turmeric hues; burns 4+ hours per fill. दीवाली के लिए हाथ से रंगे दीये।",
     "Pottery", 299, 1000, "photo-1600003014755-ba31aa59c4b6", 4.6, 187,
     ["Natural Clay", "Mineral Pigments", "Cotton Wicks"],
     "Painted by the Gorakhpur cluster women ahead of the Diwali season.",
     None),
    ("demo_artisan_radha", "demo_product_vase_01",
     "Glazed Terracotta Floor Vase",
     "Tall statement vase with a deep indigo glaze over terracotta; watertight for fresh stems. घर की शोभा बढ़ाने वाला बड़ा फूलदान।",
     "Pottery", 1250, 25, "photo-1578749556568-bc2c40e68b61", 4.8, 96,
     ["Terracotta", "Lead-free Glaze", "Sand Finish"],
     "A signature Gorakhpur Terracotta Heritage Cluster showpiece.",
     None),
    ("demo_artisan_radha", "demo_product_matka_01",
     "Traditional Earthen Water Matka (8L)",
     "Porous clay keeps water naturally cool without electricity; includes wooden lid. बिजली के बिना पानी ठंडा रखने वाला मटका।",
     "Pottery", 850, 60, "photo-1601924994987-69e26d50dc26", 4.5, 74,
     ["Porous River Clay", "Neem-wood Lid"],
     "Thrown thick-walled for slow evaporative cooling, village-style.",
     None),
    ("demo_artisan_ramesh", "demo_product_saree_01",
     "Jamdani Handloom Cotton Saree",
     "Soft breathable jamdani weave with floral butis and a heritage zari-less border; blouse piece included. हाथ से बुनी जमदानी साड़ी।",
     "Textiles", 1450, 150, "photo-1617627143750-d86bc21e42bb", 4.7, 134,
     ["Long-staple Cotton", "Azo-free Dyes"],
     "Woven over nine days on Ramesh Chhipa's pit loom in Bagru.",
     None),
    ("demo_artisan_ramesh", "demo_product_stole_01",
     "Natural Indigo Dabu Block Print Stole",
     "Hand block-printed stole in natural indigo with dabu mud-resist motifs; each piece unique. बगरू की प्रसिद्ध डाबू प्रिंट स्टोल।",
     "Textiles", 890, 200, "photo-1607613009820-a29f7bb81c04", 4.6, 158,
     ["Cotton Voile", "Natural Indigo", "Dabu Mud Resist"],
     "Printed with 200-year-old teak blocks, dyed in indigo vats.",
     None),
    ("demo_artisan_ramesh", "demo_product_dupatta_01",
     "Dabu Block Print Cotton Dupatta",
     "Everyday Rajasthani dabu dupatta in rust and indigo; pre-washed, colourfast. रोज़ पहनने के लिए सूती दुपट्टा।",
     "Textiles", 680, 220, "photo-1605518216938-7c31b7b14ad0", 4.5, 89,
     ["Cotton Mulmul", "Vegetable Dyes"],
     "Bulk-friendly weave from the Bagru collective's looms.",
     None),
    ("demo_artisan_ramesh", "demo_product_runner_01",
     "Handloom Cotton Table Runner (Set of 2)",
     "Colourful handloom runners with tasselled ends; fits 6-seater tables. हाथ से बुने टेबल रनर का जोड़ा।",
     "Textiles", 750, 120, "photo-1528459801416-a9e53bbf4e17", 4.4, 57,
     ["Handloom Cotton", "Tassel Yarn"],
     "Loomed from surplus indigo-dyed yarn, zero-waste batch.",
     None),
    ("demo_artisan_meera", "demo_product_madhubani_01",
     "Madhubani Folk Painting – Tree of Life",
     "Tree-of-life kohbar in natural pigments on handmade paper; signed by the artist. मधुबनी की प्रसिद्ध जीवन-वृक्ष चित्रकला।",
     "Painting", 1200, 12, "photo-1591085686350-798c0f9faa7f", 4.8, 143,
     ["Handmade Paper", "Natural Pigments", "Bamboo Pen"],
     "Painted in the kohbar tradition for weddings and new homes.",
     None),
    ("demo_artisan_meera", "demo_product_abstract_01",
     "Contemporary Heritage Abstract Canvas",
     "Large abstract canvas blending Mithila geometry with modern palettes; gallery-ready. आधुनिक रंगों में मिथिला कला।",
     "Painting", 2400, 8, "photo-1541961017774-22349e4a1262", 4.6, 41,
     ["Cotton Canvas", "Acrylic-Natural Mix"],
     "Meera Kumari's crossover series for urban homes and offices.",
     None),
    ("demo_artisan_meera", "demo_product_frames_01",
     "Framed Mithila Miniatures (Set of 3)",
     "Three framed miniatures – fish, peacock, lotus – ready to hang. तीन फ्रेम वाली मिथिला लघुचित्र।",
     "Painting", 1800, 20, "photo-1513519245088-0e12902e5a38", 4.7, 66,
     ["Handmade Paper", "Mango-wood Frames"],
     "Gift-ready set from the Mithila Art Collective.",
     None),
    ("demo_artisan_meera", "demo_product_sujini_01",
     "Sujini Hand-embroidered Wall Panel",
     "Narrative sujini stitch panel depicting village life; cotton threads on tussar base. सूजिनी कढ़ाई वाला दीवार पैनल।",
     "Embroidery", 950, 30, "photo-1584302179602-e4c3d3fd629d", 4.7, 52,
     ["Tussar Base", "Cotton Embroidery Thread"],
     "Three weeks of evening stitching by Meera Kumari.",
     None),
    ("demo_artisan_meera", "demo_product_kurti_01",
     "Phulkari Hand-embroidered Kurti",
     "Vibrant phulkari yoke on breathable cotton kurti; sizes S–XL. फुलकारी कढ़ाई वाली सूती कुर्ती।",
     "Embroidery", 1350, 45, "photo-1594633312681-425c7b97ccd1", 4.5, 38,
     ["Cotton", "Silk-floss Thread"],
     "Bridging Punjab phulkari with Mithila colour sensibilities.",
     None),
    ("demo_artisan_sukhdev", "demo_product_dhokra_01",
     "Dhokra Brass Elephant Figurine",
     "Lost-wax cast tribal elephant; single-pour, one-of-one texture. ढोकरा पीतल का हाथी।",
     "Metal Craft", 1850, 40, "photo-1599458252573-56ae36120de1", 4.8, 117,
     ["Brass", "Beeswax Mould", "Clay Casing"],
     "Cast by Sukhdev Sagar using the 4,000-year-old lost-wax method.",
     None),
    ("demo_artisan_sukhdev", "demo_product_idol_01",
     "Antique-finish Brass Lakshmi Idol",
     "Hand-finished Lakshmi idol with antique patina for home temples. पीतल की लक्ष्मी मूर्ति।",
     "Metal Craft", 2400, 25, "photo-1610375461246-83df859d849d", 4.7, 83,
     ["Brass Alloy", "Antique Patina"],
     "Finished and blessed in the Bastar cooperative workshop.",
     None),
    ("demo_artisan_sukhdev", "demo_product_bells_01",
     "Hand-cast Dhokra Temple Bells (Pair)",
     "Twin tribal bells with a deep resonant tone for doors and temples. ढोकरा मंदिर घंटियों का जोड़ा।",
     "Metal Craft", 1100, 55, "photo-1565538810643-b5bdb714032a", 4.6, 64,
     ["Brass", "Iron Clapper"],
     "Tuned by ear in the Bastar foundry yard.",
     None),
    ("demo_artisan_sukhdev", "demo_product_hamper_01",
     "Tribal Craft Festive Gift Hamper",
     "Curated hamper: mini dhokra figurine, terracotta diyas and a Mithila card. आदिवासी शिल्प उपहार टोकरी।",
     "Other", 1499, 80, "photo-1549465220-1a8b9238cd48", 4.7, 92,
     ["Brass Miniature", "Clay Diyas", "Gift Box"],
     "Assembled by the cooperative for corporate festive gifting.",
     None),
    ("demo_artisan_abdul", "demo_product_chair_01",
     "Hand-carved Sheesham Armchair",
     "Heirloom armchair in seasoned sheesham with jaali side panels. हाथ से नक्काशीदार शीशम कुर्सी।",
     "Wood Craft", 4200, 15, "photo-1493663284031-b7e3aefcae8e", 4.8, 47,
     ["Seasoned Sheesham", "Natural Polish"],
     "Carved over three weeks in Abdul Salim's Saharanpur workshop.",
     None),
    ("demo_artisan_abdul", "demo_product_desk_01",
     "Solid Wood Study Desk",
     "Sturdy study desk with carved apron and cable notch; flat-pack with tool kit. ठोस लकड़ी की पढ़ाई मेज़।",
     "Wood Craft", 6800, 10, "photo-1524758631624-e2822e304c36", 4.7, 33,
     ["Sheesham", "Mango-wood Drawers"],
     "Built for bulk institutional orders as well as homes.",
     None),
    ("demo_artisan_abdul", "demo_product_lounge_01",
     "Carved Wooden Lounge Chair",
     "Low lounge chair with woven cane back and carved legs. बेंत वाली आराम कुर्सी।",
     "Wood Craft", 3500, 18, "photo-1586023492125-27b2c045efd7", 4.6, 29,
     ["Sheesham", "Cane Weave"],
     "A Saharanpur guild favourite for cafes and studios.",
     None),
    ("demo_artisan_kamla", "demo_product_kundan_01",
     "Kundan Polki Necklace Set",
     "Uncut polki set in gold-plated silver with emerald drops and earrings. कुंदन पोलकी हार सेट।",
     "Jewellery", 3200, 22, "photo-1611652022419-a9419f74343d", 4.8, 76,
     ["Uncut Polki", "Gold-plated Silver", "Emerald Drops"],
     "Set by Kamla Soni in the Johari Bazaar jadau tradition.",
     None),
    ("demo_artisan_kamla", "demo_product_bangles_01",
     "Gold-plated Kundan Bangles (Pair)",
     "Festive kundan bangles, skin-safe plating, hinged for easy wear. कुंदन कंगन का जोड़ा।",
     "Jewellery", 2800, 35, "photo-1611591437281-460bfbe1220a", 4.7, 61,
     ["Brass Core", "Gold Micron Plate", "Kundan Stones"],
     "Wedding-season staple from the Jaipur cluster.",
     None),
    ("demo_artisan_kamla", "demo_product_jhumka_01",
     "Meenakari Jhumka Earrings",
     "Enamelled meenakari jhumkas with pearl drops; lightweight for daily wear. मीनाकारी झुमके।",
     "Jewellery", 1650, 50, "photo-1573408301185-9146fe634ad0", 4.6, 88,
     ["Gold-plated Alloy", "Enamel", "Pearl Drops"],
     "Enamelled over two firings for a deep red-green finish.",
     None),
    ("demo_artisan_kamla", "demo_product_tote_01",
     "Rajasthani Leather Tote with Mirror Work",
     "Vegetable-tanned leather tote with mirror-work panel and cotton lining. चमड़े का राजस्थानी टोट बैग।",
     "Leather", 1950, 42, "photo-1595515106969-1ce29566ff1c", 4.5, 44,
     ["Vegetable-tanned Leather", "Mirror-work Panel", "Cotton Lining"],
     "Cut and stitched by the cluster's leather unit in Jaipur.",
     None),
]


def _artisan_by_uid(uid: str) -> dict:
    for artisan in ARTISANS:
        if artisan["uid"] == uid:
            return artisan
    raise ValueError(f"Unknown artisan uid in dataset: {uid}")


def build_product_docs():
    """Expand raw rows into full Firestore product documents."""
    now = datetime.now(timezone.utc).isoformat()
    docs = []
    for row in _RAW_PRODUCTS:
        (artisan_uid, doc_id, title, description, category, price,
         stock, image_id, rating, reviews, materials, story, gi_tag) = row
        artisan = _artisan_by_uid(artisan_uid)
        image_url = IMG.format(image_id)
        doc = {
            "id": doc_id,
            "artisan_id": artisan_uid,
            "artisan_name": artisan["name"],
            "title": title,
            "description": description,
            "category": category,
            "price": float(price),
            "stock_quantity": int(stock),
            "image_url": image_url,
            "images": [image_url],
            "region": artisan["region"],
            "artisan_cluster": artisan["artisan_cluster"],
            "rating": float(rating),
            "review_count": int(reviews),
            "materials": list(materials),
            "story": story,
            "created_at": now,
        }
        if gi_tag:
            doc["gi_tag"] = gi_tag
        docs.append(doc)
    return docs


# ---------------------------------------------------------------------------
# Validation (runs in every mode, including --dry-run)
# ---------------------------------------------------------------------------
def validate_dataset():
    errors = []
    if len(ARTISANS) != 6:
        errors.append(f"expected 6 artisans, found {len(ARTISANS)}")
    docs = build_product_docs()
    if len(docs) != 24:
        errors.append(f"expected 24 products, found {len(docs)}")

    uids = [a["uid"] for a in ARTISANS]
    if len(set(uids)) != len(uids):
        errors.append("duplicate artisan uids")
    for artisan in ARTISANS:
        for field in ("uid", "name", "email", "role", "region",
                      "artisan_cluster", "story"):
            if not artisan.get(field):
                errors.append(f"artisan {artisan.get('uid')}: missing {field}")
        if artisan.get("role") != "artisan":
            errors.append(f"artisan {artisan.get('uid')}: role must be 'artisan'")

    ids = [d["id"] for d in docs]
    if len(set(ids)) != len(ids):
        errors.append("duplicate product ids")
    images = [d["image_url"] for d in docs]
    if len(set(images)) != len(images):
        errors.append("duplicate product images")
    for doc in docs:
        if not is_canonical_category(doc["category"]):
            errors.append(f"{doc['id']}: non-canonical category {doc['category']!r}")
        if not doc["title"] or not doc["description"]:
            errors.append(f"{doc['id']}: missing title/description")
        if doc["price"] <= 0:
            errors.append(f"{doc['id']}: non-positive price")
        if doc["stock_quantity"] < 0:
            errors.append(f"{doc['id']}: negative stock")
        if not doc["image_url"].startswith("https://images.unsplash.com/"):
            errors.append(f"{doc['id']}: unexpected image host")
        if doc["rating"] < 0 or doc["rating"] > 5:
            errors.append(f"{doc['id']}: rating out of range")
        if doc["artisan_id"] not in uids:
            errors.append(f"{doc['id']}: unknown artisan {doc['artisan_id']}")

    multi = sum(1 for _, n in Counter(d["category"] for d in docs).items() if n > 1)
    if multi < 7:
        errors.append(f"only {multi} categories have >1 product (want >=7)")
    return docs, errors


# ---------------------------------------------------------------------------
# Firestore access
# ---------------------------------------------------------------------------
def _service_key_status():
    """Check the backend service-account key without printing secrets."""
    from config import SERVICE_ACCOUNT_KEY_PATH
    if not os.path.exists(SERVICE_ACCOUNT_KEY_PATH):
        return "missing", SERVICE_ACCOUNT_KEY_PATH
    try:
        with open(SERVICE_ACCOUNT_KEY_PATH, "r", encoding="utf-8") as fh:
            head = fh.read(2000)
    except OSError:
        return "unreadable", SERVICE_ACCOUNT_KEY_PATH
    if "PASTE_YOUR_FIREBASE_PRIVATE_KEY_HERE" in head or "shilpsetu-placeholder-id" in head:
        return "placeholder", SERVICE_ACCOUNT_KEY_PATH
    return "ok", SERVICE_ACCOUNT_KEY_PATH


def get_db():
    """Return a Firestore client, or (None, reason) if unavailable."""
    status, path = _service_key_status()
    if status != "ok":
        return None, f"serviceAccountKey {status} at {path}"
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError as exc:
        return None, f"firebase_admin not installed ({exc})"
    try:
        from config import SERVICE_ACCOUNT_KEY_PATH
        if not firebase_admin._apps:
            firebase_admin.initialize_app(
                credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH))
        return firestore.client(), ""
    except Exception as exc:  # noqa: BLE001
        return None, f"Firestore init failed: {exc}"


def seed_collection(db, collection, docs, id_key, update):
    """Write docs by deterministic ID. Returns (created, skipped, updated)."""
    created, skipped, updated = 0, 0, 0
    col = db.collection(collection)
    for doc in docs:
        ref = col.document(doc[id_key])
        exists = ref.get().exists
        if exists and not update:
            skipped += 1
            continue
        ref.set(doc, merge=bool(update and exists))
        if exists:
            updated += 1
        else:
            created += 1
    return created, skipped, updated


def live_counts(db):
    """Count total + demo docs per collection (never deletes anything)."""
    totals = {}
    for collection in ("products", "users"):
        try:
            all_docs = list(db.collection(collection).stream())
        except Exception as exc:  # noqa: BLE001
            totals[collection] = f"unreadable ({exc})"
            continue
        demo = [d for d in all_docs if d.id.startswith("demo_")]
        totals[collection] = f"{len(all_docs)} total / {len(demo)} demo_*"
    return totals


def print_distribution(docs):
    dist = Counter(d["category"] for d in docs)
    print("Category distribution (seed dataset):")
    for cat in CANONICAL_CATEGORIES:
        if dist.get(cat):
            print(f"  {cat:<12} {dist[cat]:>3}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Seed the curated KalaVistar demo catalog (idempotent).")
    parser.add_argument("--dry-run", action="store_true",
                        help="validate the dataset and exit without touching Firestore")
    parser.add_argument("--update", action="store_true",
                        help="overwrite existing demo_* docs (default: skip them)")
    args = parser.parse_args(argv)

    docs, errors = validate_dataset()
    if errors:
        print("Dataset validation FAILED:")
        for err in errors:
            print(f"  - {err}")
        return 1
    print(f"Dataset OK: {len(docs)} products, {len(ARTISANS)} artisans, "
          f"all canonical categories valid.")
    print_distribution(docs)

    if args.dry_run:
        print("Dry run: Firestore untouched.")
        return 0

    db, reason = get_db()
    if db is None:
        print(f"Cannot seed: {reason}.")
        print("Run with --dry-run to validate locally, or add a valid "
              "backend/serviceAccountKey.json and retry.")
        return 2

    au, su, uu = seed_collection(db, "users", ARTISANS, "uid", args.update)
    ap, sp, up = seed_collection(db, "products", docs, "id", args.update)
    print(f"users:    {au} created, {su} skipped, {uu} updated")
    print(f"products: {ap} created, {sp} skipped, {up} updated")
    for collection, count in live_counts(db).items():
        print(f"  {collection}: {count}")
    print("Acceptance checks:")
    print("  curl 'http://127.0.0.1:5000/api/products/search?limit=50'")
    print("  curl 'http://127.0.0.1:5000/api/products/search?category=Textiles'")
    print("  curl -X POST http://127.0.0.1:5000/api/matching/buyer-supplier "
          "-H 'Content-Type: application/json' "
          "-d '{\"category\":\"Textiles\",\"quantity\":100,\"budget\":150000}'")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
