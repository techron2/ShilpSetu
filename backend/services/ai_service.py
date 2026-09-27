import os
import re
import json
import logging
from services.categories import normalize_category

logger = logging.getLogger(__name__)


def _is_html_error(text: str) -> bool:
    """Check if returned text looks like a scraped HTML error page."""
    if not text:
        return False
    lower = text.lower()
    error_patterns = [
        "error 500",
        "server error",
        "that's an error",
        "<html",
        "<!doctype",
        "<body",
        "<div",
        "404 not found",
        "502 bad gateway",
        "503 service unavailable",
        "google.com/search"
    ]
    if any(pattern in lower for pattern in error_patterns):
        return True
    # If text has html tags like <...>, reject
    if bool(re.search(r"<[^>]+>", text)):
        return True
    return False


def _translate_text(text: str, target_lang: str) -> str:
    """Safely translate text using GoogleTranslator with HTML error rejection."""
    if not text or not text.strip():
        return ""
    try:
        from deep_translator import GoogleTranslator
        for attempt in range(2):
            translated = GoogleTranslator(source="auto", target=target_lang).translate(text)
            if translated and not _is_html_error(translated):
                return translated.strip()
            logger.warning(f"Translation returned an HTML/error response on attempt {attempt + 1}. Retrying...")
        logger.warning(f"Translation to {target_lang} failed validation. Falling back to original text.")
        return text.strip()
    except Exception as e:
        logger.warning(f"Translation to {target_lang} failed ({e}). Returning original text.")
        return text.strip()


def _fallback_artisan_extraction(transcript: str, lang_code: str = "hi") -> dict:
    """Conservatively structure a listing using only the artisan's transcript."""
    t_lower = transcript.lower()

    # Category classification uses explicit transcript words; all other product
    # details remain the artisan's own words rather than inferred attributes.
    if any(w in t_lower for w in ["मधुबनी", "madhubani", "painting", "चित्रकला", "चित्र", "आर्ट", "पेंटिंग"]):
        category = "Painting"
    elif any(w in t_lower for w in ["मिट्टी", "कुल्हड़", "कुल्हड़", "मटका", "घड़ा", "pottery", "clay", "terracotta", "kulhad"]):
        category = "Pottery"
    elif any(w in t_lower for w in ["साड़ी", "दुपट्टा", "कपड़ा", "सिल्क", "प्रिंट", "textile", "cotton", "saree", "stole", "block print"]):
        category = "Textiles"
    elif any(w in t_lower for w in ["पीतल", "धातु", "कांसा", "मूर्ति", "brass", "metal", "dhokra", "idol"]):
        category = "Metal Craft"
    elif any(w in t_lower for w in ["लकड़ी", "काष्ठ", "wood", "wooden", "carving"]):
        category = "Wood Craft"
    elif any(w in t_lower for w in ["आभूषण", "गहना", "jewellery", "jewelry"]):
        category = "Jewellery"
    elif any(w in t_lower for w in ["कढ़ाई", "कशीदाकारी", "embroidery"]):
        category = "Embroidery"
    elif any(w in t_lower for w in ["चमड़ा", "चर्म", "leather"]):
        category = "Leather"
    else:
        category = "Other"

    neutral_titles = {
        "Textiles": ("Artisan Textile Product", "कारीगर का वस्त्र उत्पाद"),
        "Pottery": ("Artisan Pottery Product", "कारीगर का मिट्टी शिल्प उत्पाद"),
        "Jewellery": ("Artisan Jewellery", "कारीगर की आभूषण कला"),
        "Embroidery": ("Artisan Embroidery", "कारीगर की कढ़ाई कला"),
        "Wood Craft": ("Artisan Wood Craft Product", "कारीगर का लकड़ी शिल्प उत्पाद"),
        "Leather": ("Artisan Leather Product", "कारीगर का चमड़ा उत्पाद"),
        "Painting": ("Artisan Painting", "कारीगर की चित्रकला"),
        "Metal Craft": ("Artisan Metal Craft", "कारीगर का धातु शिल्प"),
        "Other": ("Artisan Craft Product", "कारीगर का शिल्प उत्पाद"),
    }
    title_en, title_hi = neutral_titles[category]

    source_text = transcript.strip()
    if lang_code == "en":
        desc_en = source_text
        desc_hi = _translate_text(source_text, "hi")
    elif lang_code == "hi":
        desc_hi = source_text
        desc_en = _translate_text(source_text, "en")
    else:
        desc_en = _translate_text(source_text, "en")
        desc_hi = _translate_text(source_text, "hi")

    return {
        "title": title_en,
        "title_en": title_en,
        "title_hi": title_hi,
        "description": desc_en,
        "description_en": desc_en,
        "description_hi": desc_hi,
        "category": category,
        "key_features": [],
        "ai_structured": False,
    }


def extract_product_listing_gemini(transcript: str, lang_code: str = "hi") -> dict:
    """Extract structured bilingual product listing using Google Gemini API,

    generating both English and Hindi directly in the structured response.
    Falls back to rule-based artisan extractor if the key is missing or calls fail.
    """
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")

    if not api_key:
        logger.info("GEMINI_API_KEY not found in environment. Using standard listing extraction.")
        return _fallback_artisan_extraction(transcript, lang_code)

    try:
        from google import genai
        from google.genai import types

        client = genai.Client(api_key=api_key)

        prompt = f"""
        You are HunarSathi's catalog assistant. An artisan provided this product description:
        "{transcript}"

        Use ONLY facts supported by the artisan's transcript. You may improve grammar,
        structure, clarity, translation, and marketplace readability, but do not add product facts.
        Do not infer or invent material, geographic origin or region, artisan lineage or generations
        of heritage, GI or other certification, authenticity verification, sustainability,
        eco-friendliness, natural or organic composition, production technique, dimensions,
        durability, microwave or food safety, or cultural history unless explicitly stated in the
        transcript. If a detail is missing, omit it. Do not turn a category guess into a product fact.

        Extract a structured bilingual e-commerce product listing:
        1. "title_en": Clear product title in English based only on the transcript.
        2. "title_hi": Clear product title in Hindi based only on the transcript.
        3. "description_en": Accurate English description reflecting only the transcript.
        4. "description_hi": Accurate Hindi description reflecting only the transcript.
        5. "category": EXACTLY one of: "Textiles", "Pottery", "Jewellery", "Embroidery", "Wood Craft", "Leather", "Painting", "Metal Craft", "Other".
        6. "key_features": Zero or more short features directly supported by the transcript. Use an
        empty array when no distinct features are supported; do not invent items to fill a quota.

        Output ONLY valid JSON matching this schema:
        {{
            "title_en": "...",
            "title_hi": "...",
            "description_en": "...",
            "description_hi": "...",
            "category": "...",
            "key_features": ["...", "..."]
        }}
        """

        # Gemini 3.6 Flash is standard; maintain fallback candidates if needed
        models_to_try = ["gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-1.5-flash"]
        response = None
        last_error = None

        for model_name in models_to_try:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json"
                    )
                )
                if response and response.text:
                    break
            except Exception as ex:
                last_error = ex
                logger.warning(f"Model {model_name} failed: {ex}. Trying next model...")

        if not response or not response.text:
            raise RuntimeError(f"All Gemini models failed. Last error: {last_error}")

        resp_text = response.text.strip()
        # Strip markdown code fences if present
        if resp_text.startswith("```"):
            resp_text = re.sub(r"^```(?:json)?", "", resp_text)
            resp_text = re.sub(r"```$", "", resp_text).strip()

        parsed = json.loads(resp_text)
        if not isinstance(parsed, dict):
            raise ValueError("Gemini listing response must be a JSON object")
        title_en = parsed.get("title_en") or parsed.get("title") or ""
        title_hi = parsed.get("title_hi") or ""
        desc_en = parsed.get("description_en") or parsed.get("description") or ""
        desc_hi = parsed.get("description_hi") or ""
        raw_category = parsed.get("category")
        if not all(isinstance(value, str) for value in (title_en, title_hi, desc_en, desc_hi)):
            raise ValueError("Gemini listing fields must be text")
        if (
            not (title_en or title_hi)
            or not (desc_en or desc_hi)
            or not isinstance(raw_category, str)
            or not raw_category.strip()
        ):
            raise ValueError("Gemini listing response did not contain usable listing fields")
        category = normalize_category(raw_category, default="Other")
        raw_features = parsed.get("key_features", [])
        features = (
            [feature.strip() for feature in raw_features if isinstance(feature, str) and feature.strip()]
            if isinstance(raw_features, list)
            else []
        )

        logger.info(f"Gemini structured extraction success: {title_en} [{category}]")
        return {
            "title": title_en,
            "title_en": title_en,
            "title_hi": title_hi,
            "description": desc_en,
            "description_en": desc_en,
            "description_hi": desc_hi,
            "category": category,
            "key_features": features,
            "ai_structured": True,
        }

    except Exception as e:
        logger.warning(f"Gemini API generation failed ({e}). Using standard listing extraction.")
        return _fallback_artisan_extraction(transcript, lang_code)


def process_voice_to_catalog(transcript: str, lang_code: str = "hi") -> dict:
    """Full Voice-to-Catalog pipeline:

    1. Extracts structured fields & generates bilingual titles/descriptions directly via Gemini (Choice B)
    2. Uses HTML-sanitized translation only if bilingual fields are missing
    3. Returns bilingual fields plus ai_structured, which describes listing-field
       extraction only and does not describe speech-to-text.
    """
    if not transcript or not transcript.strip():
        return {
            "success": False,
            "error": "Empty transcript provided",
            "friendly_error": "कोई आवाज़ या विवरण नहीं मिला (No voice description found)"
        }

    # Step 1: Structured extraction with built-in bilingual generation
    extracted = extract_product_listing_gemini(transcript, lang_code)

    title_en = extracted.get("title_en", "")
    title_hi = extracted.get("title_hi", "")
    desc_en = extracted.get("description_en", "")
    desc_hi = extracted.get("description_hi", "")
    category = normalize_category(extracted.get("category", "Other"), default="Other")
    features = extracted.get("key_features", [])

    # Step 2: Safety check - if any language field is unexpectedly empty, fill with safe translation
    if not title_en and title_hi:
        title_en = _translate_text(title_hi, "en")
    if not title_hi and title_en:
        title_hi = _translate_text(title_en, "hi")
    if not desc_en and desc_hi:
        desc_en = _translate_text(desc_hi, "en")
    if not desc_hi and desc_en:
        desc_hi = _translate_text(desc_en, "hi")

    return {
        "success": True,
        "transcript": transcript,
        "title_en": title_en,
        "title_hi": title_hi,
        "description_en": desc_en,
        "description_hi": desc_hi,
        "category": category,
        "key_features": features,
        "ai_structured": extracted.get("ai_structured") is True,
    }


def _fallback_artisan_profile_extraction(transcript: str, lang_code: str = "hi") -> dict:
    """Intelligent rule-based fallback for artisan profile extraction."""
    t_lower = transcript.lower()

    # 1. Name detection
    name = ""
    name_patterns = [
        r"(?:मेरा नाम|my name is|माझे नाव|नाव)\s+([A-Za-z\u0900-\u097F]+(?:\s+[A-Za-z\u0900-\u097F]+)?)",
        r"(?:मैं|i am|मी)\s+([A-Za-z\u0900-\u097F]+(?:\s+[A-Za-z\u0900-\u097F]+)?)\s+(?:हूँ|आहे|here)",
    ]
    for p in name_patterns:
        m = re.search(p, transcript, re.IGNORECASE)
        if m:
            candidate = m.group(1).strip()
            if candidate.lower() not in ["एक", "कारीगर", "artisan", "शिल्पकार", "craftsman"]:
                name = candidate
                break

    # 2. Gender detection
    gender = "Other"
    if any(w in t_lower for w in ["महिला", "स्त्री", "woman", "female", "she", "her", "देवी"]):
        gender = "Female"
    elif any(w in t_lower for w in ["पुरुष", "man", "male", "he", "him", "प्रजापति", "कुमार", "राम", "bhai"]):
        gender = "Male"

    # 3. Marital status detection
    marital_status = "Married"
    if any(w in t_lower for w in ["अविवाहित", "single", "unmarried", "कुंवारा"]):
        marital_status = "Single"
    elif any(w in t_lower for w in ["विवाहित", "married", "शादीशुदा", "लग्नाळू"]):
        marital_status = "Married"

    # 4. Experience detection
    experience_years = 10
    exp_m = re.search(r"(\d+)\s*(?:साल|वर्ष|वर्षे|years|yrs)", transcript, re.IGNORECASE)
    if exp_m:
        try:
            experience_years = int(exp_m.group(1))
        except Exception:
            pass

    # 5. Craft category
    craft = "Handicrafts"
    if any(w in t_lower for w in ["मिट्टी", "कुल्हड़", "pottery", "terracotta", "माती"]):
        craft = "Terracotta Pottery"
    elif any(w in t_lower for w in ["साड़ी", "कपड़ा", "textile", "cotton", "weaving", "वस्त्र"]):
        craft = "Handloom & Textiles"
    elif any(w in t_lower for w in ["चित्र", "मधुबनी", "painting", "art", "चित्रकला"]):
        craft = "Folk Painting"
    elif any(w in t_lower for w in ["धातु", "पीतल", "metal", "dhokra", "कांसा"]):
        craft = "Metal Craft"
    elif any(w in t_lower for w in ["लकड़ी", "wood", "carving", "काष्ठ"]):
        craft = "Wood Carving"

    # 6. Story synthesis
    if len(transcript.strip()) > 40:
        story = transcript.strip()
    else:
        if lang_code == "mr":
            story = f"मी गेल्या {experience_years} वर्षांपासून पारंपारिक {craft} कलेमध्ये समर्पितपणे कार्यरत आहे. माझ्या पूर्वजांकडून मिळालेला हा वारसा मी अखंडपणे पुढे नेत असून, प्रत्येक उत्पादनात अस्सल हस्तकलेचे सौंदर्य जपण्याचा माझा प्रयत्न असतो."
        elif lang_code == "hi":
            story = f"मैं पिछले {experience_years} वर्षों से पारंपरिक {craft} शिल्पकला में समर्पित भाव से कार्यरत हूँ। यह कला मुझे अपने पूर्वजों से विरासत में मिली है, और मैं हर उत्पाद में भारतीय संस्कृति और हस्तशिल्प की प्रामाणिकता संजोने का प्रयास करता हूँ।"
        else:
            story = f"I have been dedicated to traditional {craft} for over {experience_years} years. Inheriting this sacred craft heritage from my ancestors, I pour heart and soul into every handmade piece to keep authentic artisan craftsmanship alive."

    birth_year = max(1950, 2024 - (experience_years + 20))
    dob = f"{birth_year}-01-01"

    return {
        "full_name": name,
        "date_of_birth": dob,
        "phone_number": "",
        "gender": gender,
        "marital_status": marital_status,
        "experience_years": experience_years,
        "craft_category": craft,
        "story": story,
        "artisan_story": story,
    }


def extract_profile_gemini(transcript: str, lang_code: str = "hi") -> dict:
    """Extract structured artisan profile information using Google Gemini API."""
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        logger.info("GEMINI_API_KEY not configured. Using fallback profile extractor.")
        return _fallback_artisan_profile_extraction(transcript, lang_code)

    try:
        from google import genai
        from google.genai import types

        client = genai.Client(api_key=api_key)

        prompt = f"""
        You are HunarSathi AI, an expert cultural biographer and profile assistant empowering traditional Indian rural artisans.
        An artisan spoke this natural audio introduction about themselves, their life, family, and craft:
        "{transcript}"

        Extract structured profile fields with high empathy, accuracy, and dignity:
        1. "full_name": The artisan's real name (e.g. "Rameshwar Prajapati", "Radha Devi") or empty string if not mentioned.
        2. "date_of_birth": Estimated date of birth in YYYY-MM-DD format based on age/experience, or empty string.
        3. "phone_number": Phone number if mentioned, else empty string.
        4. "gender": EXACTLY one of: "Male", "Female", "Other".
        5. "marital_status": EXACTLY one of: "Married", "Single", "Other".
        6. "experience_years": Estimated integer number of years working in their craft (default 10 if unclear).
        7. "craft_category": Their primary craft specialization (e.g. "Terracotta Pottery", "Handloom Weaving", "Madhubani Painting", "Dhokra Metal", "Wood Carving").
        8. "story": A rich, beautifully phrased 3 to 5 sentence first-person artisan story narrative describing their craft journey, heritage lineage, artistic techniques, and dedication to their craft. Formulate this primarily in the language the artisan spoke ({lang_code}).

        Output ONLY valid JSON matching this schema:
        {{
            "full_name": "...",
            "date_of_birth": "YYYY-MM-DD",
            "phone_number": "...",
            "gender": "...",
            "marital_status": "...",
            "experience_years": 10,
            "craft_category": "...",
            "story": "..."
        }}
        """

        models_to_try = ["gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-1.5-flash"]
        response = None
        last_error = None

        for model_name in models_to_try:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json"
                    )
                )
                if response and response.text:
                    break
            except Exception as ex:
                last_error = ex

        if not response or not response.text:
            raise RuntimeError(f"All Gemini models failed: {last_error}")

        resp_text = response.text.strip()
        if resp_text.startswith("```"):
            resp_text = re.sub(r"^```(?:json)?", "", resp_text)
            resp_text = re.sub(r"```$", "", resp_text).strip()

        parsed = json.loads(resp_text)
        story = parsed.get("story") or transcript
        return {
            "full_name": parsed.get("full_name", ""),
            "date_of_birth": parsed.get("date_of_birth", ""),
            "phone_number": parsed.get("phone_number", ""),
            "gender": parsed.get("gender", "Other"),
            "marital_status": parsed.get("marital_status", "Married"),
            "experience_years": int(parsed.get("experience_years", 10)),
            "craft_category": parsed.get("craft_category", "Handicrafts"),
            "story": story,
            "artisan_story": story,
        }

    except Exception as e:
        logger.warning(f"Gemini profile extraction failed ({e}). Using intelligent fallback.")
        return _fallback_artisan_profile_extraction(transcript, lang_code)


def process_voice_to_profile(transcript: str, lang_code: str = "hi") -> dict:
    """Full Voice-to-Profile pipeline: transcribes & extracts structured profile fields."""
    if not transcript or not transcript.strip():
        return {
            "success": False,
            "error": "Empty transcript provided",
            "friendly_error": "कृपया पहले बोलकर अपना परिचय दें (Please speak to record your details)"
        }

    extracted = extract_profile_gemini(transcript, lang_code)
    extracted["success"] = True
    extracted["transcript"] = transcript
    return extracted

