import os
import io
import math
import uuid
import logging
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
import cv2
import rembg
from services.firebase_service import get_firebase_app

logger = logging.getLogger(__name__)

# Ensure local static directory exists for fallback serving
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATIC_DIR = os.path.join(BASE_DIR, "static")
ENHANCED_DIR = os.path.join(STATIC_DIR, "enhanced")
os.makedirs(ENHANCED_DIR, exist_ok=True)

_rembg_session = None


def _get_rembg_session():
    """Initializes or returns cached lightweight rembg session (u2netp)."""
    global _rembg_session
    if _rembg_session is None:
        try:
            _rembg_session = rembg.new_session("u2netp")
            logger.info("rembg u2netp session initialized successfully.")
        except Exception as e:
            logger.warning(f"Could not load u2netp session ({e}), falling back to default.")
            _rembg_session = rembg.new_session()
    return _rembg_session


def _auto_white_balance(bgr: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Auto white-balance correction using percentile-based Gray World on foreground pixels."""
    fg_mask = alpha > 25
    if not np.any(fg_mask):
        return bgr

    bgr_balanced = bgr.copy().astype(np.float32)
    for c in range(3):
        chan = bgr_balanced[:, :, c]
        fg_vals = chan[fg_mask]
        if len(fg_vals) > 0:
            p_low = np.percentile(fg_vals, 1)
            p_high = np.percentile(fg_vals, 99)
            if p_high > p_low:
                chan = np.clip((chan - p_low) * (255.0 / (p_high - p_low)), 0, 255)
                bgr_balanced[:, :, c] = chan
    return np.clip(bgr_balanced, 0, 255).astype(np.uint8)


def _enhance_contrast_brightness(bgr: np.ndarray) -> np.ndarray:
    """Auto brightness and contrast adjustment using CLAHE on L-channel in LAB color space."""
    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
    l_chan, a_chan, b_chan = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced_l = clahe.apply(l_chan)
    # Natural blend: 85% enhanced, 15% original to maintain smooth tonal gradation
    final_l = cv2.addWeighted(enhanced_l, 0.85, l_chan, 0.15, 0)
    enhanced_lab = cv2.merge((final_l, a_chan, b_chan))
    enhanced_bgr = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2BGR)
    return cv2.cvtColor(enhanced_bgr, cv2.COLOR_BGR2RGB)


def _apply_sharpening(craft_pil: Image.Image) -> Image.Image:
    """Apply subtle unsharp mask to bring out authentic handicraft textures."""
    rgb = craft_pil.convert("RGB")
    alpha = craft_pil.split()[3]
    sharpened_rgb = rgb.filter(ImageFilter.UnsharpMask(radius=1.5, percent=120, threshold=2))
    return Image.merge("RGBA", (*sharpened_rgb.split(), alpha))


def _create_studio_background(target_size=(1080, 1080)) -> Image.Image:
    """Renders a clean studio e-commerce background with a subtle soft radial light vignette."""
    canvas_w, canvas_h = target_size
    Y, X = np.ogrid[:canvas_h, :canvas_w]
    center_x = canvas_w / 2.0
    center_y = canvas_h * 0.48
    dist_from_center = np.sqrt((X - center_x) ** 2 + (Y - center_y) ** 2)
    max_dist = math.sqrt((canvas_w / 2) ** 2 + (canvas_h / 2) ** 2)
    norm_dist = np.clip(dist_from_center / max_dist, 0, 1)

    # Center: 255 (clean white), Edges: 243 (soft studio light gray)
    vignette = (255 - norm_dist * 12).astype(np.uint8)
    bg_np = np.dstack((vignette, vignette, vignette, np.full(target_size, 255, dtype=np.uint8)))
    return Image.fromarray(bg_np, mode="RGBA")


def _render_studio_shadows(
    scaled_craft: Image.Image,
    target_size: tuple,
    offset_x: int,
    offset_y: int,
    new_w: int,
    new_h: int
) -> Image.Image:
    """Generates dual studio shadows:
    1. Ambient drop shadow matching craft silhouette
    2. Elliptical contact shadow anchoring the product base
    """
    shadow_layer = Image.new("RGBA", target_size, (0, 0, 0, 0))
    craft_alpha = scaled_craft.split()[3]

    # 1. Ambient Drop Shadow (soft diffused silhouette)
    ambient_mask = craft_alpha.filter(ImageFilter.GaussianBlur(radius=24))
    ambient_np = np.zeros((new_h, new_w, 4), dtype=np.uint8)
    ambient_np[:, :, :3] = (30, 35, 45)  # cool dark studio tone
    ambient_np[:, :, 3] = (np.array(ambient_mask) * 0.28).astype(np.uint8)
    ambient_img = Image.fromarray(ambient_np, mode="RGBA")

    # Shift ambient shadow slightly down and right (studio key light from top-left)
    shadow_layer.paste(ambient_img, (offset_x + 8, offset_y + 18), mask=ambient_img)

    # 2. Ground Contact Shadow (anchoring oval underneath the product base)
    base_y = offset_y + new_h
    shadow_w = int(new_w * 0.85)
    shadow_h = max(18, int(new_h * 0.08))
    pad = 40
    contact_shadow = Image.new("RGBA", (shadow_w + pad * 2, shadow_h + pad), (0, 0, 0, 0))
    cs_draw = ImageDraw.Draw(contact_shadow)

    # Outer soft contact spread
    cs_draw.ellipse(
        [pad, pad // 2, pad + shadow_w, pad // 2 + shadow_h],
        fill=(25, 28, 35, 125)
    )
    # Inner dense contact core
    cs_draw.ellipse(
        [
            pad + int(shadow_w * 0.15),
            pad // 2 + int(shadow_h * 0.2),
            pad + int(shadow_w * 0.85),
            pad // 2 + int(shadow_h * 0.8)
        ],
        fill=(15, 18, 22, 175)
    )
    contact_shadow = contact_shadow.filter(ImageFilter.GaussianBlur(radius=10))

    cs_x = offset_x + (new_w - (shadow_w + pad * 2)) // 2
    cs_y = base_y - (shadow_h // 2) - 10
    shadow_layer.paste(contact_shadow, (cs_x, cs_y), mask=contact_shadow)

    return shadow_layer


def _generate_comparison_image(
    orig_img: Image.Image,
    final_studio_img: Image.Image,
    comparison_save_path: str,
    after_label: str = "AFTER: Studio-Quality E-Commerce (1:1 Studio + Ground Shadow)"
):
    """Generates a side-by-side (2160x1180) before/after comparison banner."""
    try:
        orig_w, orig_h = orig_img.size
        comp_w, comp_h = 2160, 1180
        comp_img = Image.new("RGB", (comp_w, comp_h), (245, 243, 240))
        comp_draw = ImageDraw.Draw(comp_img)

        # Fit original into 1080x1080 canvas
        orig_aspect = orig_w / orig_h
        if orig_aspect >= 1.0:
            fit_w = 1080
            fit_h = int(1080 / orig_aspect)
        else:
            fit_h = 1080
            fit_w = int(1080 * orig_aspect)
        orig_fitted = orig_img.resize((fit_w, fit_h), Image.Resampling.LANCZOS)
        raw_canvas = Image.new("RGB", (1080, 1080), (232, 228, 222))
        raw_canvas.paste(orig_fitted, ((1080 - fit_w) // 2, (1080 - fit_h) // 2))

        # Paste left & right
        comp_img.paste(raw_canvas, (0, 100))
        comp_img.paste(final_studio_img, (1080, 100))

        # Header Banners
        comp_draw.rectangle([0, 0, 1080, 100], fill=(210, 80, 60))
        comp_draw.text((60, 35), "BEFORE: Raw Artisan Photo (Unedited)", fill=(255, 255, 255))

        comp_draw.rectangle([1080, 0, 2160, 100], fill=(27, 42, 74))
        comp_draw.text((1140, 35), after_label, fill=(255, 255, 255))

        # Divider
        comp_draw.line([(1080, 0), (1080, 1180)], fill=(200, 195, 185), width=3)
        comp_img.save(comparison_save_path, "JPEG", quality=92)
    except Exception as comp_err:
        logger.warning(f"Could not generate comparison image: {comp_err}")


def _enhance_with_gemini_image(image_bytes: bytes, target_size=(1080, 1080)) -> Image.Image | None:
    """Uses Google Gemini multimodal image model to generate true studio-grade product photos.

    Instructions:
    - Retains actual product geometry, color, materials and handicraft details unchanged
    - Seamless clean studio backdrop (soft white or light gray gradient)
    - Realistic studio lighting, highlights, and contact shadows
    - High-resolution, square 1:1 format

    Gracefully returns None if quota is exceeded or API call fails.
    """
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        logger.info("GEMINI_API_KEY not found. Skipping Gemini image generation.")
        return None

    prompt = (
        "Professional commercial e-commerce product photograph retoucher:\n"
        "1. ACCURACY: Keep the actual handicraft product (shape, silhouette, colors, natural materials, "
        "handmade textures, painted motifs, and physical details) completely accurate, faithful, and unchanged. "
        "Do NOT invent, distort, or alter the product itself.\n"
        "2. BACKDROP: Replace the background with a clean, professional studio e-commerce backdrop "
        "(seamless soft white to light gray gradient cyclorama).\n"
        "3. LIGHTING & SHADOWS: Apply soft, diffused commercial studio lighting with realistic directional highlights "
        "and authentic grounding contact shadows directly beneath the product base as if photographed with a DSLR.\n"
        "4. FORMAT: Output a high-resolution, centered square (1:1) image suitable for an online catalog listing."
    )

    models_to_try = [
        "gemini-2.5-flash-image",
        "gemini-3.1-flash-image",
        "gemini-3-pro-image",
        "gemini-3.1-flash-lite-image"
    ]

    try:
        from google import genai
        from google.genai import types

        client = genai.Client(api_key=api_key)

        for model_name in models_to_try:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=[
                        types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
                        prompt
                    ],
                    config=types.GenerateContentConfig(
                        response_modalities=["IMAGE"],
                        image_config=types.ImageConfig(
                            aspect_ratio="1:1"
                        )
                    )
                )

                if response and response.candidates:
                    for cand in response.candidates:
                        if cand.content and cand.content.parts:
                            for part in cand.content.parts:
                                if part.inline_data and part.inline_data.data:
                                    img_data = part.inline_data.data
                                    gemini_pil = Image.open(io.BytesIO(img_data)).convert("RGB")
                                    gemini_pil = gemini_pil.resize(target_size, Image.Resampling.LANCZOS)
                                    logger.info(f"Gemini image generation succeeded using {model_name}.")
                                    return gemini_pil

            except Exception as model_err:
                logger.warning(f"Gemini model {model_name} image generation failed: {model_err}")
                continue

        logger.info("All Gemini image models were unavailable. Falling back to OpenCV pipeline.")
        return None

    except Exception as e:
        logger.warning(f"Gemini image enhancement error ({e}). Falling back to OpenCV pipeline.")
        return None


def _enhance_with_opencv(orig_img: Image.Image, target_size=(1080, 1080)) -> Image.Image:
    """Performs rule-based OpenCV + rembg studio enhancement pipeline."""
    # Step 1: Background Removal
    session = _get_rembg_session()
    no_bg_rgba = rembg.remove(orig_img, session=session)
    if no_bg_rgba.mode != "RGBA":
        no_bg_rgba = no_bg_rgba.convert("RGBA")

    # Step 2: Color Correction & Contrast on Product (OpenCV)
    np_rgba = np.array(no_bg_rgba)
    rgb = np_rgba[:, :, :3]
    alpha = np_rgba[:, :, 3]
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

    # Auto white balance
    bgr_balanced = _auto_white_balance(bgr, alpha)

    # CLAHE contrast & brightness enhancement
    enhanced_rgb = _enhance_contrast_brightness(bgr_balanced)

    enhanced_rgba = np.dstack((enhanced_rgb, alpha))
    craft_pil = Image.fromarray(enhanced_rgba, mode="RGBA")

    # Step 3: Texture Detail Sharpening
    craft_pil = _apply_sharpening(craft_pil)

    # Step 4: Bounding Box Crop & Scale
    bbox = craft_pil.getbbox()
    if bbox:
        craft_cropped = craft_pil.crop(bbox)
    else:
        craft_cropped = craft_pil

    crop_w, crop_h = craft_cropped.size
    canvas_w, canvas_h = target_size

    # Fit craft comfortably within ~78% width, ~76% height to leave margins
    max_dim_w = int(canvas_w * 0.78)
    max_dim_h = int(canvas_h * 0.76)
    scale = min(max_dim_w / crop_w, max_dim_h / crop_h)
    new_w = max(1, int(crop_w * scale))
    new_h = max(1, int(crop_h * scale))

    scaled_craft = craft_cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Horizontal center, slightly elevated vertically to anchor shadow
    offset_x = (canvas_w - new_w) // 2
    offset_y = int((canvas_h - new_h) * 0.46)

    # Step 5: Studio Background & Ground Shadow
    studio_canvas = _create_studio_background(target_size)
    shadow_layer = _render_studio_shadows(
        scaled_craft, target_size, offset_x, offset_y, new_w, new_h
    )

    # Composite: Studio Canvas + Shadows + Scaled Craft Foreground
    studio_canvas = Image.alpha_composite(studio_canvas, shadow_layer)
    studio_canvas.paste(scaled_craft, (offset_x, offset_y), mask=scaled_craft)

    return studio_canvas.convert("RGB")


def enhance_product_image(image_bytes: bytes, target_size=(1080, 1080), prefer_gemini: bool = True) -> dict:
    """Enhances raw artisan craft photograph into a studio-quality e-commerce product image:

    Primary: Google Gemini multimodal studio generation (true DSLR lighting, organic depth)
    Fallback: rembg + OpenCV CLAHE + auto white balance + dual contact shadow
    """
    try:
        orig_img = Image.open(io.BytesIO(image_bytes))
        if orig_img.mode != "RGB":
            orig_img = orig_img.convert("RGB")
        orig_w, orig_h = orig_img.size
        logger.info(f"Enhancing image to studio quality: original {orig_w}x{orig_h}")

        final_studio = None
        engine_used = "opencv_fallback"
        features_applied = []

        # 1. Attempt Gemini Studio Enhancement first if requested
        if prefer_gemini:
            gemini_img = _enhance_with_gemini_image(image_bytes, target_size)
            if gemini_img is not None:
                final_studio = gemini_img
                engine_used = "gemini_studio"
                features_applied = [
                    "gemini_multimodal_studio_retouching",
                    "dslr_diffused_studio_lighting",
                    "organic_grounding_contact_shadows",
                    "seamless_cyclorama_backdrop",
                    "square_1080x1080_centered_framing"
                ]

        # 2. Fall back gracefully to OpenCV + rembg pipeline if Gemini was unavailable or skipped
        if final_studio is None:
            final_studio = _enhance_with_opencv(orig_img, target_size)
            engine_used = "opencv_fallback"
            features_applied = [
                "rembg_background_removal",
                "opencv_auto_white_balance",
                "opencv_clahe_contrast_enhancement",
                "texture_unsharp_mask_sharpening",
                "studio_light_vignette_background",
                "realistic_ambient_drop_shadow",
                "ground_contact_shadow",
                "square_1080x1080_centered_framing"
            ]

        out_buf = io.BytesIO()
        final_studio.save(out_buf, format="JPEG", quality=95)
        final_bytes = out_buf.getvalue()

        # Step 3: Save Image & Generate Side-by-Side Comparison
        uid = uuid.uuid4().hex[:12]
        filename = f"studio_{uid}.jpg"
        comp_filename = f"comparison_{uid}.jpg"

        public_url = None
        comp_url = None

        # Attempt Firebase Storage upload
        firebase_app = get_firebase_app()
        if firebase_app:
            try:
                from firebase_admin import storage
                bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET")
                bucket = storage.bucket(bucket_name, app=firebase_app)
                blob = bucket.blob(f"products/{filename}")
                blob.upload_from_string(final_bytes, content_type="image/jpeg")
                blob.make_public()
                public_url = blob.public_url
                logger.info(f"Enhanced studio image uploaded to Firebase Storage: {public_url}")
            except Exception as fb_err:
                logger.warning(f"Firebase Storage upload failed ({fb_err}), falling back to local static storage.")

        # Local static storage (guaranteed)
        local_path = os.path.join(ENHANCED_DIR, filename)
        with open(local_path, "wb") as f:
            f.write(final_bytes)

        local_comp_path = os.path.join(ENHANCED_DIR, comp_filename)
        label = (
            "AFTER: Gemini AI Studio E-Commerce (DSLR Lighting & Organic Depth)"
            if engine_used == "gemini_studio"
            else "AFTER: OpenCV + Rembg Studio E-Commerce (1:1 Studio + Ground Shadow)"
        )
        _generate_comparison_image(orig_img, final_studio, local_comp_path, after_label=label)

        # Save raw original image as well so artisan can choose original version
        raw_filename = f"raw_{uid}.jpg"
        raw_local_path = os.path.join(ENHANCED_DIR, raw_filename)
        with open(raw_local_path, "wb") as f:
            f.write(image_bytes)

        orig_public_url = None
        if firebase_app:
            try:
                from firebase_admin import storage
                bucket_name = os.getenv("FIREBASE_STORAGE_BUCKET")
                bucket = storage.bucket(bucket_name, app=firebase_app)
                blob = bucket.blob(f"products/{raw_filename}")
                blob.upload_from_string(image_bytes, content_type="image/jpeg")
                blob.make_public()
                orig_public_url = blob.public_url
            except Exception as fb_err:
                logger.warning(f"Firebase Storage upload of raw image failed: {fb_err}")

        port = int(os.getenv("PORT", 5000))
        if not public_url:
            public_url = f"http://127.0.0.1:{port}/static/enhanced/{filename}"

        if not orig_public_url:
            orig_public_url = f"http://127.0.0.1:{port}/static/enhanced/{raw_filename}"

        comp_url = f"http://127.0.0.1:{port}/static/enhanced/{comp_filename}"

        return {
            "success": True,
            "engine": engine_used,
            "image_url": public_url,
            "original_image_url": orig_public_url,
            "comparison_url": comp_url,
            "filename": filename,
            "comparison_filename": comp_filename,
            "original_dimensions": [orig_w, orig_h],
            "enhanced_dimensions": list(target_size),
            "features_applied": features_applied
        }

    except Exception as e:
        logger.error(f"Studio enhancement error: {e}", exc_info=True)
        return {
            "success": False,
            "error": f"Image enhancement failed: {str(e)}"
        }
