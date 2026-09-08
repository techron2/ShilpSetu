import os
import io
import math
import numpy as np
from PIL import Image, ImageFilter, ImageDraw
import cv2
import rembg

def prototype_studio_enhancement(input_path, output_path, comparison_path):
    print(f"Reading input image: {input_path}")
    orig_img = Image.open(input_path).convert("RGB")
    orig_w, orig_h = orig_img.size

    # Step 1: Background removal via rembg (u2netp)
    print("Running background removal...")
    session = rembg.new_session("u2netp")
    no_bg_rgba = rembg.remove(orig_img, session=session)
    if no_bg_rgba.mode != "RGBA":
        no_bg_rgba = no_bg_rgba.convert("RGBA")

    # Step 2: Auto White Balance & Contrast on Product Foreground (OpenCV)
    print("Applying auto white-balance and CLAHE contrast...")
    np_rgba = np.array(no_bg_rgba)
    rgb = np_rgba[:, :, :3]
    alpha = np_rgba[:, :, 3]

    # Convert RGB to BGR for OpenCV
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

    # 2a. White balance correction (percentile-based Gray World on foreground)
    fg_mask = alpha > 25
    if np.any(fg_mask):
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
        bgr = np.clip(bgr_balanced, 0, 255).astype(np.uint8)

    # 2b. Brightness & Contrast enhancement using CLAHE in LAB space
    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
    l_chan, a_chan, b_chan = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced_l = clahe.apply(l_chan)
    # Natural blend: 85% enhanced, 15% original
    final_l = cv2.addWeighted(enhanced_l, 0.85, l_chan, 0.15, 0)
    enhanced_lab = cv2.merge((final_l, a_chan, b_chan))
    enhanced_bgr = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2BGR)
    enhanced_rgb = cv2.cvtColor(enhanced_bgr, cv2.COLOR_BGR2RGB)

    # Recombine with alpha mask
    enhanced_rgba = np.dstack((enhanced_rgb, alpha))
    craft_pil = Image.fromarray(enhanced_rgba, mode="RGBA")

    # Step 3: Subtle sharpening filter on foreground craft
    print("Applying texture sharpening...")
    craft_rgb = craft_pil.convert("RGB")
    sharpened_rgb = craft_rgb.filter(ImageFilter.UnsharpMask(radius=1.5, percent=120, threshold=2))
    craft_pil = Image.merge("RGBA", (*sharpened_rgb.split(), craft_pil.split()[3]))

    # Step 4: Crop product to bounding box & determine scaling
    bbox = craft_pil.getbbox()
    if bbox:
        craft_cropped = craft_pil.crop(bbox)
    else:
        craft_cropped = craft_pil

    crop_w, crop_h = craft_cropped.size
    target_size = (1080, 1080)
    canvas_w, canvas_h = target_size

    # Fit product cleanly within ~75-80% of canvas with breathing room
    max_dim_w = int(canvas_w * 0.78)
    max_dim_h = int(canvas_h * 0.76)
    scale = min(max_dim_w / crop_w, max_dim_h / crop_h)
    new_w = max(1, int(crop_w * scale))
    new_h = max(1, int(crop_h * scale))
    scaled_craft = craft_cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Position: horizontally centered, vertical position slightly elevated for grounded shadow
    offset_x = (canvas_w - new_w) // 2
    # Leave room for ground shadow underneath
    offset_y = int((canvas_h - new_h) * 0.46)

    # Step 5: Render Clean Studio Background (soft off-white to studio light-gray)
    print("Rendering studio background & shadows...")
    # Radial studio lighting: soft spotlight effect centered behind the product
    bg = Image.new("RGBA", target_size, (255, 255, 255, 255))
    draw = ImageDraw.Draw(bg)

    # Create subtle studio gradient (light radial vignette from #FFFFFF center to #F3F4F6 edges)
    # Using numpy for speed
    Y, X = np.ogrid[:canvas_h, :canvas_w]
    center_x, center_y = canvas_w / 2.0, canvas_h * 0.48
    dist_from_center = np.sqrt((X - center_x) ** 2 + (Y - center_y) ** 2)
    max_dist = math.sqrt((canvas_w / 2) ** 2 + (canvas_h / 2) ** 2)
    norm_dist = np.clip(dist_from_center / max_dist, 0, 1)

    # Center: 255 (pure white), Edges: 244 (soft studio light gray #F4F4F4)
    vignette = (255 - norm_dist * 12).astype(np.uint8)
    bg_np = np.dstack((vignette, vignette, vignette, np.full(target_size, 255, dtype=np.uint8)))
    studio_canvas = Image.fromarray(bg_np, mode="RGBA")

    # Step 6: Create Realistic Drop & Ground Contact Shadows
    # 6a. Ambient Drop Shadow (based on craft silhouette)
    shadow_layer = Image.new("RGBA", target_size, (0, 0, 0, 0))
    craft_alpha = scaled_craft.split()[3]

    # Create soft dark-gray silhouette
    ambient_shadow_mask = craft_alpha.filter(ImageFilter.GaussianBlur(radius=24))
    ambient_shadow_img = Image.new("RGBA", (new_w, new_h), (35, 40, 50, 0))
    # Fill with semi-transparent shadow tone
    ambient_shadow_np = np.zeros((new_h, new_w, 4), dtype=np.uint8)
    ambient_shadow_np[:, :, :3] = (30, 35, 45) # soft cool dark shadow
    ambient_shadow_np[:, :, 3] = (np.array(ambient_shadow_mask) * 0.28).astype(np.uint8)
    ambient_shadow_img = Image.fromarray(ambient_shadow_np, mode="RGBA")

    # Shift ambient shadow slightly down and right (simulating top-left studio key light)
    ambient_x = offset_x + 8
    ambient_y = offset_y + 18
    shadow_layer.paste(ambient_shadow_img, (ambient_x, ambient_y), mask=ambient_shadow_img)

    # 6b. Ground Contact Shadow (tight dark oval right at the base of the product)
    base_y = offset_y + new_h
    shadow_w = int(new_w * 0.85)
    shadow_h = max(18, int(new_h * 0.08))
    contact_shadow = Image.new("RGBA", (shadow_w + 80, shadow_h + 40), (0, 0, 0, 0))
    cs_draw = ImageDraw.Draw(contact_shadow)

    # Draw graduated dark contact oval
    cs_draw.ellipse(
        [40, 20, 40 + shadow_w, 20 + shadow_h],
        fill=(25, 28, 35, 125),
    )
    # Inner denser contact core
    cs_draw.ellipse(
        [40 + int(shadow_w * 0.15), 20 + int(shadow_h * 0.2), 40 + int(shadow_w * 0.85), 20 + int(shadow_h * 0.8)],
        fill=(15, 18, 22, 175),
    )
    # Heavily blur contact shadow for soft realistic falloff
    contact_shadow = contact_shadow.filter(ImageFilter.GaussianBlur(radius=10))

    # Paste contact shadow centered at the base
    cs_x = offset_x + (new_w - (shadow_w + 80)) // 2
    cs_y = base_y - (shadow_h // 2) - 10
    shadow_layer.paste(contact_shadow, (cs_x, cs_y), mask=contact_shadow)

    # Composite: Studio Canvas + Shadow Layer + Scaled Craft Foreground
    studio_canvas = Image.alpha_composite(studio_canvas, shadow_layer)
    studio_canvas.paste(scaled_craft, (offset_x, offset_y), mask=scaled_craft)

    # Convert to high-quality RGB JPEG
    final_studio = studio_canvas.convert("RGB")
    final_studio.save(output_path, "JPEG", quality=95)
    print(f"Saved enhanced studio photo: {output_path}")

    # Step 7: Create Side-by-Side Before/After Comparison Image
    print("Generating side-by-side before/after comparison...")
    comp_w = 2160
    comp_h = 1180
    comp_img = Image.new("RGB", (comp_w, comp_h), (245, 243, 240))
    comp_draw = ImageDraw.Draw(comp_img)

    # Resize raw original to 1080x1080 keeping aspect ratio with parchment padding
    orig_aspect = orig_w / orig_h
    if orig_aspect >= 1.0:
        fit_w = 1080
        fit_h = int(1080 / orig_aspect)
    else:
        fit_h = 1080
        fit_w = int(1080 * orig_aspect)
    orig_fitted = orig_img.resize((fit_w, fit_h), Image.Resampling.LANCZOS)
    raw_canvas = Image.new("RGB", (1080, 1080), (230, 225, 218))
    raw_canvas.paste(orig_fitted, ((1080 - fit_w) // 2, (1080 - fit_h) // 2))

    # Paste Raw Before on Left
    comp_img.paste(raw_canvas, (0, 100))
    # Paste Studio After on Right
    comp_img.paste(final_studio, (1080, 100))

    # Draw Header labels
    # Before Banner (Terracotta / Dark)
    comp_draw.rectangle([0, 0, 1080, 100], fill=(210, 80, 60))
    comp_draw.text((60, 32), "BEFORE: Raw Artisan Photo (Unedited / Cluttered)", fill=(255, 255, 255))

    # After Banner (Studio Green / Indigo)
    comp_draw.rectangle([1080, 0, 2160, 100], fill=(27, 42, 74))
    comp_draw.text((1140, 32), "AFTER: Studio-Quality E-Commerce (1:1 Clean Shadow & CLAHE)", fill=(255, 255, 255))

    # Center Divider Line
    comp_draw.line([(1080, 0), (1080, 1180)], fill=(200, 195, 185), width=3)

    comp_img.save(comparison_path, "JPEG", quality=92)
    print(f"Saved side-by-side comparison image: {comparison_path}")
    return True

if __name__ == "__main__":
    prototype_studio_enhancement(
        "real_craft_input.jpg",
        "static/enhanced/test_studio_output.jpg",
        "static/enhanced/test_side_by_side_comparison.jpg"
    )
