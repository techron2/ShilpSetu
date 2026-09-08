import os
import io
import math
import wave
import struct
from PIL import Image, ImageDraw

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def create_sample_craft_image():
    """Create a sample artisan handicraft image (Terracotta Pot on a patterned workshop background)

    to test rembg background removal and OpenCV contrast enhancement.
    """
    width, height = 600, 600
    # Background: textured workshop background with brown wooden table
    img = Image.new("RGB", (width, height), (220, 210, 195))
    draw = ImageDraw.Draw(img)

    # Draw wooden table surface
    draw.rectangle([0, 400, 600, 600], fill=(139, 90, 43))
    for y in range(410, 600, 20):
        draw.line([0, y, 600, y], fill=(120, 75, 35), width=2)

    # Draw rustic wall background texture
    for x in range(0, 600, 40):
        draw.line([x, 0, x, 400], fill=(205, 195, 180), width=1)

    # Draw artisan handicraft: Terracotta Clay Pot (Mitti ka Matka / Kalash)
    # Pot belly (oval)
    draw.ellipse([180, 220, 420, 460], fill=(184, 80, 48), outline=(130, 45, 20), width=3)
    # Neck
    draw.polygon([(250, 180), (350, 180), (330, 230), (270, 230)], fill=(195, 90, 55), outline=(130, 45, 20))
    # Rim / Lip
    draw.ellipse([240, 170, 360, 190], fill=(210, 105, 65), outline=(130, 45, 20), width=3)
    # Handcrafted tribal geometric patterns (white clay paint)
    for px in range(210, 390, 30):
        draw.line([px, 320, px + 15, 300], fill=(250, 245, 235), width=3)
        draw.line([px + 15, 300, px + 30, 320], fill=(250, 245, 235), width=3)
    draw.line([200, 350, 400, 350], fill=(250, 245, 235), width=3)
    draw.line([205, 360, 395, 360], fill=(250, 245, 235), width=2)

    out_path = os.path.join(BASE_DIR, "sample_craft.jpg")
    img.save(out_path, "JPEG", quality=95)
    print(f"Created sample craft image: {out_path} ({width}x{height})")
    return out_path


def create_sample_audio():
    """Create a sample clean WAV audio file.

    44.1kHz, 16-bit PCM WAV.
    """
    out_path = os.path.join(BASE_DIR, "sample_audio.wav")
    sample_rate = 16000
    duration = 2.0  # seconds
    n_samples = int(sample_rate * duration)

    # Generate a clean acoustic harmonic wave (resembling voice fundamental ~220Hz + harmonics)
    with wave.open(out_path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        frames = bytearray()
        for i in range(n_samples):
            t = i / sample_rate
            # Harmonic blend with decay
            env = math.sin(math.pi * t / duration)
            sample = (
                0.6 * math.sin(2 * math.pi * 220 * t) +
                0.3 * math.sin(2 * math.pi * 440 * t) +
                0.1 * math.sin(2 * math.pi * 880 * t)
            ) * env * 32767 * 0.7
            frames.extend(struct.pack("<h", int(sample)))
        wf.writeframes(frames)

    print(f"Created sample audio file: {out_path} ({sample_rate}Hz, {duration}s)")
    return out_path


if __name__ == "__main__":
    create_sample_craft_image()
    create_sample_audio()
