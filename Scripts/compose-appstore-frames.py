#!/usr/bin/env python3
"""Compose App Store marketing frames from raw simulator screenshots.

Usage: compose-appstore-frames.py <raw_dir> <out_dir>

<raw_dir> holds raw captures named NN_<key>.png (any resolution, portrait).
For every capture and every target size below, a framed marketing image is
written to <out_dir>/<size>/NN_<key>.png: dark background with a green glow,
headline + subline, and the screenshot inside a drawn device frame. An
unframed copy at the exact store size goes to <out_dir>/<size>_plain/.
Requires Pillow. Fonts: SF Pro (macOS) with Helvetica/DejaVu fallbacks.
"""
import os
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

SIZES = {
    "6.9-inch_1320x2868": (1320, 2868),
    "6.5-inch_1284x2778": (1284, 2778),
}

HEADLINES = {
    "cast": ("Your videos.\nYour car screen.", "Playlists, IPTV and local files, ready when you park."),
    "cardisplay": ("Made for the\ncar display", "A big, beautiful player for passengers and parked breaks."),
    "drive": ("Every drive,\nbeautifully tracked", "Speed, distance and a smooth-driving score."),
    "widgets": ("Make the dash\nyours", "Car widgets, live wallpapers and stickers."),
    "sounds": ("Sounds for\nevery arrival", "Welcome chimes and engine sounds, triggered automatically."),
    "paywall": ("Pay once.\nKeep it forever.", "No subscriptions. One purchase unlocks DashCast Pro."),
    "me": ("Your garage,\nyour stats", "Pick your car and see every mile."),
}
FOOTNOTE = "For passengers & parked use only. Never watch while driving."

GREEN = (43, 240, 127)
BG_TOP = (18, 22, 26)
BG_BOTTOM = (4, 5, 6)


def load_font(size, bold=True):
    candidates = [
        ("/System/Library/Fonts/SFNS.ttf", "Bold" if bold else "Regular"),
        ("/System/Library/Fonts/SFNSDisplay.ttf", None),
        ("/System/Library/Fonts/Helvetica.ttc", None),
        ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold
         else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", None),
    ]
    for path, variation in candidates:
        if not os.path.exists(path):
            continue
        try:
            font = ImageFont.truetype(path, size, index=1 if (path.endswith(".ttc") and bold) else 0)
            if variation:
                try:
                    font.set_variation_by_name(variation)
                except Exception:
                    pass
            return font
        except Exception:
            continue
    return ImageFont.load_default(size)


def background(w, h):
    bg = Image.new("RGB", (w, h))
    px = ImageDraw.Draw(bg)
    for y in range(h):
        t = y / (h - 1)
        px.line([(0, y), (w, y)], fill=tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)))
    glow = Image.new("RGB", (w, h), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r = int(w * 0.55)
    cx, cy = w // 2, int(h * 0.56)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(14, 120, 62))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.22))
    return ImageChops.add(bg, glow)


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def device(shot, screen_w):
    """Return an RGBA device frame (titanium bezel + island) containing `shot`."""
    sw = screen_w
    sh = int(round(sw * shot.height / shot.width))
    screen = shot.convert("RGB").resize((sw, sh), Image.LANCZOS)
    bezel = int(sw * 0.035)
    W, H = sw + 2 * bezel, sh + 2 * bezel
    r_out = int(sw * 0.15)
    r_in = r_out - bezel

    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=r_out, fill=(58, 62, 66, 255))
    edge = max(3, bezel // 6)
    d.rounded_rectangle([edge, edge, W - 1 - edge, H - 1 - edge], radius=r_out - edge, fill=(10, 11, 12, 255))
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=r_out, outline=(120, 126, 130, 255), width=max(2, edge // 2))

    frame.paste(screen, (bezel, bezel), rounded_mask((sw, sh), r_in))

    # Dynamic Island
    iw, ih = int(sw * 0.29), int(sw * 0.085)
    ix, iy = (W - iw) // 2, bezel + int(sw * 0.03)
    d.rounded_rectangle([ix, iy, ix + iw, iy + ih], radius=ih // 2, fill=(0, 0, 0, 255))
    return frame


def wrap_center(draw, text, font, cx, y, fill, spacing):
    for line in text.split("\n"):
        bbox = draw.textbbox((0, 0), line, font=font)
        draw.text((cx - (bbox[2] - bbox[0]) / 2 - bbox[0], y), line, font=font, fill=fill)
        y += (bbox[3] - bbox[1]) + spacing
    return y


def fit_lines(draw, text, font_size, max_w, bold=True):
    """Shrink font until every line fits max_w; for sublines, word-wrap into 2 lines."""
    while font_size > 20:
        font = load_font(font_size, bold)
        if all(draw.textlength(l, font=font) <= max_w for l in text.split("\n")):
            return font, text
        if not bold and "\n" not in text:
            words = text.split()
            best = None
            for i in range(1, len(words)):
                a, b = " ".join(words[:i]), " ".join(words[i:])
                m = max(draw.textlength(a, font=font), draw.textlength(b, font=font))
                if best is None or m < best[0]:
                    best = (m, a + "\n" + b)
            if best and best[0] <= max_w:
                return font, best[1]
        font_size -= 4
    return load_font(font_size, bold), text


def compose(shot_path, key, size):
    w, h = size
    canvas = background(w, h).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    headline, sub = HEADLINES.get(key, (key.title(), ""))
    margin = int(w * 0.08)

    y = int(h * 0.055)
    hfont, headline = fit_lines(d, headline, int(w * 0.088), w - 2 * margin)
    y = wrap_center(d, headline, hfont, w / 2, y, (255, 255, 255), int(w * 0.012))
    y += int(w * 0.022)
    if sub:
        sfont, sub = fit_lines(d, sub, int(w * 0.036), w - 2 * margin, bold=False)
        y = wrap_center(d, sub, sfont, w / 2, y, (160, 170, 178), int(w * 0.01))

    # green accent bar under text
    bar_w = int(w * 0.09)
    d.rounded_rectangle([w / 2 - bar_w / 2, y + 14, w / 2 + bar_w / 2, y + 22], radius=4, fill=GREEN + (255,))
    top = y + int(h * 0.03)

    foot_font = load_font(int(w * 0.022), bold=False)
    foot_h = int(h * 0.05)
    avail_h = h - top - foot_h - int(h * 0.015)

    shot = Image.open(shot_path)
    screen_w = int(w * 0.76)
    frame = device(shot, screen_w)
    if frame.height > avail_h:
        frame = device(shot, int(screen_w * avail_h / frame.height))

    # soft green shadow behind the device
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    fx = (w - frame.width) // 2
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([fx + 20, top + 40, fx + frame.width - 20, top + frame.height],
                         radius=int(frame.width * 0.15), fill=GREEN + (70,))
    shadow = shadow.filter(ImageFilter.GaussianBlur(w * 0.04))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(frame, (fx, top))

    fb = d.textbbox((0, 0), FOOTNOTE, font=foot_font)
    d.text(((w - (fb[2] - fb[0])) / 2, h - foot_h + (foot_h - (fb[3] - fb[1])) / 2 - fb[1] - int(h * 0.01)),
           FOOTNOTE, font=foot_font, fill=(120, 130, 138))
    return canvas.convert("RGB")


def main():
    raw_dir, out_dir = sys.argv[1], sys.argv[2]
    shots = sorted(f for f in os.listdir(raw_dir) if f.lower().endswith(".png"))
    if not shots:
        sys.exit(f"no screenshots in {raw_dir}")
    for label, size in SIZES.items():
        os.makedirs(os.path.join(out_dir, label), exist_ok=True)
        for f in shots:
            key = os.path.splitext(f)[0].split("_", 1)[-1].lower()
            img = compose(os.path.join(raw_dir, f), key, size)
            assert img.size == size, (img.size, size)
            dest = os.path.join(out_dir, label, f)
            img.save(dest, optimize=True)
            print(f"{dest} {img.size[0]}x{img.size[1]}")

            # Plain (unframed) screenshot at the exact store size: cover-scale + centre crop.
            plain_dir = os.path.join(out_dir, label + "_plain")
            os.makedirs(plain_dir, exist_ok=True)
            raw = Image.open(os.path.join(raw_dir, f)).convert("RGB")
            scale = max(size[0] / raw.width, size[1] / raw.height)
            rs = raw.resize((round(raw.width * scale), round(raw.height * scale)), Image.LANCZOS)
            left, top = (rs.width - size[0]) // 2, (rs.height - size[1]) // 2
            rs.crop((left, top, left + size[0], top + size[1])).save(os.path.join(plain_dir, f), optimize=True)


if __name__ == "__main__":
    main()
