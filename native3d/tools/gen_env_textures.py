#!/usr/bin/env python3
"""Generate the Ground Zero environment textures (all original, in-repo art).

Outputs POT PNGs into native3d/assets/env/. Deterministic (seeded) so CI
imports are reproducible. Run: python3 native3d/tools/gen_env_textures.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "env")
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def noise_rgb(size, base, spread, seed):
    rnd = random.Random(seed)
    img = Image.effect_noise(size, spread).convert("L")
    lut = [max(0, min(255, int(base[i] + (v - 128) * (spread / 128.0) * 0.9)))
           for i in range(3) for v in range(256)]
    # build per-channel LUTs properly
    luts = []
    for c in range(3):
        luts.append([max(0, min(255, int(base[c] + (v - 128) * (spread / 128.0) * 0.9))) for v in range(256)])
    img = img.point(luts[0] + luts[1] + luts[2]) if False else img
    r = img.point(luts[0])
    g = img.point(luts[1])
    b = img.point(luts[2])
    return Image.merge("RGB", (r, g, b))


def grime(draw, w, h, rnd, n, color=(30, 28, 26)):
    for _ in range(n):
        x = rnd.randrange(w)
        y = rnd.randrange(h // 2)
        ln = rnd.randrange(10, h - y)
        a = rnd.randrange(18, 60)
        draw.line([(x, y), (x + rnd.randrange(-3, 4), y + ln)], fill=color + (a,), width=rnd.randrange(1, 3))


def cracks(draw, w, h, rnd, n, color=(25, 24, 22), width=1):
    for _ in range(n):
        x, y = rnd.randrange(w), rnd.randrange(h)
        pts = [(x, y)]
        for _ in range(rnd.randrange(3, 8)):
            x += rnd.randrange(-30, 30)
            y += rnd.randrange(-30, 30)
            pts.append((max(0, min(w - 1, x)), max(0, min(h - 1, y))))
        draw.line(pts, fill=color, width=width)


def facade_cell(path, seed, style):
    """One floor cell (256x256): 1 window bay ~4.2m wide, 3m floor."""
    rnd = random.Random(seed)
    w = h = 256
    img = noise_rgb((w, h), (148, 142, 132), 42, seed).convert("RGBA")
    d = ImageDraw.Draw(img)
    # panel seams
    for x in (0, 255):
        d.line([(x, 0), (x, h)], fill=(120, 114, 105, 90), width=2)
    d.line([(0, h - 1), (w, h - 1)], fill=(110, 104, 96, 120), width=3)
    # floor slab shadow at bottom (AO)
    for i in range(14):
        d.line([(0, h - 1 - i), (w, h - 1 - i)], fill=(90, 85, 78, 26))
    # window
    wx, wy, ww, wh = 58, 52, 140, 150
    broken = rnd.random() < (0.35 if style == 3 else 0.18)
    lit = rnd.random() < 0.12
    d.rectangle([wx - 6, wy - 6, wx + ww + 6, wy + wh + 6], fill=(140, 134, 124, 255))  # frame
    if lit:
        glass = (255, 214, 140, 255)
    elif broken:
        glass = (18, 16, 15, 255)
    else:
        glass = (52, 66, 82, 255)
    d.rectangle([wx, wy, wx + ww, wy + wh], fill=glass)
    # glass reflection diagonal
    if not broken:
        d.polygon([(wx, wy + wh), (wx + 60, wy), (wx + 90, wy), (wx + 30, wy + wh)], fill=(120, 150, 180, 70))
        d.line([(wx + ww // 2, wy), (wx + ww // 2, wy + wh)], fill=(30, 34, 40, 160), width=4)
        d.line([(wx, wy + wh // 2), (wx + ww, wy + wh // 2)], fill=(30, 34, 40, 160), width=4)
    else:
        cracks(d, wx + ww, wy + wh, rnd, 5, color=(38, 38, 40), width=1)
        d.polygon([(wx + 20, wy + 30), (wx + 70, wy + 20), (wx + 55, wy + 90), (wx + 15, wy + 80)], fill=(10, 10, 10, 255))
    # balcony slab + railing for styles 1/2
    if style in (1, 2):
        d.rectangle([wx - 14, wy + wh, wx + ww + 14, wy + wh + 14], fill=(150, 144, 134, 255))
        for i in range(0, ww + 28, 10):
            d.line([(wx - 14 + i, wy + wh + 14), (wx - 14 + i, wy + wh + 30)], fill=(70, 68, 64, 220), width=2)
        d.line([(wx - 14, wy + wh + 30), (wx + ww + 14, wy + wh + 30)], fill=(70, 68, 64, 220), width=2)
        if style == 2 and rnd.random() < 0.5:  # broken railing
            d.rectangle([wx + 40, wy + wh + 16, wx + 90, wy + wh + 30], fill=(0, 0, 0, 0), outline=(60, 58, 54, 255), width=2)
    # big damage hole for style 3
    if style == 3 and rnd.random() < 0.6:
        cx, cy = rnd.randrange(40, 200), rnd.randrange(40, 180)
        pts = [(cx + rnd.randrange(-24, 24), cy + rnd.randrange(-18, 18)) for _ in range(7)]
        d.polygon(pts, fill=(14, 13, 12, 255))
        for _ in range(4):  # exposed rebar
            d.line([(cx + rnd.randrange(-30, 30), cy + rnd.randrange(-25, 25)),
                    (cx + rnd.randrange(-30, 30), cy + rnd.randrange(20, 45))], fill=(96, 62, 40, 255), width=3)
    grime(d, w, h, rnd, 12)
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    img.convert("RGB").save(path, optimize=True)


def concrete(path, seed):
    rnd = random.Random(seed)
    img = noise_rgb((256, 256), (150, 146, 138), 30, seed).convert("RGBA")
    d = ImageDraw.Draw(img)
    cracks(d, 256, 256, rnd, 7)
    for _ in range(6):  # stains
        x, y = rnd.randrange(256), rnd.randrange(256)
        r = rnd.randrange(15, 55)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(70, 66, 60, 40))
    grime(d, 256, 256, rnd, 8)
    img.convert("RGB").save(path, optimize=True)


def plaza(path):
    rnd = random.Random(7)
    s = 1024
    img = noise_rgb((s, s), (134, 128, 118), 42, 7).convert("RGBA")
    d = ImageDraw.Draw(img)
    # slab grid
    for i in range(0, s + 1, 128):
        d.line([(i, 0), (i, s)], fill=(100, 95, 88, 160), width=3)
        d.line([(0, i), (s, i)], fill=(100, 95, 88, 160), width=3)
    cracks(d, s, s, rnd, 46, width=2)
    # faded circular ground markings (reference plaza)
    cx = cy = s // 2
    for r, col in ((400, (196, 178, 92, 150)), (330, (196, 178, 92, 110)), (400, (60, 58, 54, 90))):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=16 if r == 400 else 8)
    for a in range(0, 360, 30):  # radial ticks on the ring
        rad = math.radians(a)
        x1, y1 = cx + 330 * math.cos(rad), cy + 330 * math.sin(rad)
        x2, y2 = cx + 400 * math.cos(rad), cy + 400 * math.sin(rad)
        d.line([(x1, y1), (x2, y2)], fill=(196, 178, 92, 100), width=8)
    # center emblem: faint triangle/star
    d.polygon([(cx, cy - 60), (cx + 55, cy + 40), (cx - 55, cy + 40)], outline=(150, 140, 120, 130), width=10)
    # stains + rubble specks
    for _ in range(26):
        x, y = rnd.randrange(s), rnd.randrange(s)
        r = rnd.randrange(8, 60)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(138, 134, 126))
    for _ in range(160):
        x, y = rnd.randrange(s), rnd.randrange(s)
        d.point((x, y), fill=(120, 116, 108))
    # grass tufts growing through cracks
    for _ in range(240):
        x, y = rnd.randrange(s), rnd.randrange(s)
        for _ in range(4):
            d.line([(x, y), (x + rnd.randrange(-4, 5), y - rnd.randrange(4, 12))], fill=(96, 128, 66), width=2)
    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img.convert("RGB").save(path, optimize=True)


def asphalt(path):
    rnd = random.Random(11)
    s = 512
    img = noise_rgb((s, s), (58, 58, 60), 26, 11).convert("RGBA")
    d = ImageDraw.Draw(img)
    cracks(d, s, s, rnd, 12, color=(30, 30, 32), width=2)
    for _ in range(8):
        x, y = rnd.randrange(s), rnd.randrange(s)
        r = rnd.randrange(10, 40)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(48, 48, 50))
    # faded dashed center line along +Y of the tile (roads run along their length)
    for y in range(20, s, 90):
        d.rectangle([s // 2 - 4, y, s // 2 + 4, y + 44], fill=(190, 186, 160, 90))
    # grass at edges
    for _ in range(60):
        x = rnd.choice([rnd.randrange(0, 30), rnd.randrange(s - 30, s)])
        y = rnd.randrange(s)
        for _ in range(3):
            d.line([(x, y), (x + rnd.randrange(-3, 4), y - rnd.randrange(3, 9))], fill=(92, 122, 62), width=2)
    img.convert("RGB").save(path, optimize=True)


def dirt(path):
    rnd = random.Random(23)
    s = 512
    img = noise_rgb((s, s), (112, 102, 84), 40, 23).convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(70):  # grass patches
        x, y = rnd.randrange(s), rnd.randrange(s)
        r = rnd.randrange(12, 46)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(104, 126, 74))
    for _ in range(120):  # stones
        x, y = rnd.randrange(s), rnd.randrange(s)
        d.ellipse([x, y, x + rnd.randrange(2, 5), y + rnd.randrange(2, 5)], fill=(140, 134, 122))
    cracks(d, s, s, rnd, 8, color=(60, 54, 44), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.convert("RGB").save(path, optimize=True)


def _text_center(d, img, text, font, fill, y):
    w = d.textlength(text, font=font)
    d.text(((img.width - w) / 2, y), text, font=font, fill=fill)


def billboard_forever(path):
    w, h = 512, 256
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):  # vertical purple gradient
        t = y / h
        for x in range(w):
            px[x, y] = (int(38 + 60 * t), int(10 + 26 * t), int(84 + 120 * t))
    d = ImageDraw.Draw(img, "RGBA")
    rnd = random.Random(5)
    for _ in range(40):  # scratches
        x, y = rnd.randrange(w), rnd.randrange(h)
        d.line([(x, y), (x + rnd.randrange(10, 60), y + rnd.randrange(-6, 6))], fill=(255, 255, 255, 14), width=1)
    # glow cat-ear star logo
    cx, cy = 86, 74
    d.polygon([(cx - 34, cy - 20), (cx - 10, cy - 44), (cx + 2, cy - 18), (cx + 14, cy - 46), (cx + 36, cy - 20),
               (cx + 30, cy + 26), (cx, cy + 40), (cx - 30, cy + 26)], fill=(232, 180, 255, 235))
    d.ellipse([cx - 44, cy - 26, cx + 46, cy + 34], outline=(255, 255, 255, 60), width=3)
    font_big = ImageFont.truetype(FONT_BOLD, 64)
    font_mid = ImageFont.truetype(FONT_BOLD, 44)
    d.text((170, 60), "CLAUDE", font=font_big, fill=(255, 255, 255, 255))
    d.text((170, 132), "FOREVER", font=font_mid, fill=(214, 160, 255, 255))
    d.rectangle([4, 4, w - 5, h - 5], outline=(20, 8, 34, 255), width=8)
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    img.save(path, optimize=True)


def billboard_humanity(path):
    w, h = 512, 256
    rnd = random.Random(9)
    img = noise_rgb((w, h), (52, 54, 60), 30, 9).convert("RGBA")
    d = ImageDraw.Draw(img)
    cracks(d, w, h, rnd, 8, color=(28, 28, 30), width=2)
    grime(d, w, h, rnd, 14, color=(20, 20, 22))
    font = ImageFont.truetype(FONT_BOLD, 40)
    _text_center(d, img, "HUMANITY WAS HERE...", font, (232, 232, 236, 235), 70)
    font2 = ImageFont.truetype(FONT, 22)
    _text_center(d, img, "- EST. 2029 -", font2, (150, 150, 158, 180), 140)
    d.rectangle([4, 4, w - 5, h - 5], outline=(24, 24, 28, 255), width=8)
    img.convert("RGB").save(path, optimize=True)


def billboard_controls(path):
    w, h = 512, 256
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / h
        for x in range(w):
            px[x, y] = (int(30 + 40 * t), int(8 + 18 * t), int(70 + 100 * t))
    d = ImageDraw.Draw(img, "RGBA")
    # triangle logo
    cx, cy = 92, 128
    d.polygon([(cx, cy - 62), (cx + 58, cy + 44), (cx - 58, cy + 44)], outline=(240, 190, 255, 255), width=8)
    d.polygon([(cx, cy - 26), (cx + 26, cy + 22), (cx - 26, cy + 22)], outline=(240, 190, 255, 255), width=5)
    font = ImageFont.truetype(FONT_BOLD, 42)
    d.text((190, 62), "CLAUDE AI", font=font, fill=(255, 255, 255, 255))
    d.text((190, 118), "CONTROLS", font=font, fill=(214, 160, 255, 255))
    d.text((190, 166), "THE WORLD", font=font, fill=(214, 160, 255, 255))
    d.rectangle([4, 4, w - 5, h - 5], outline=(18, 6, 30, 255), width=8)
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    img.save(path, optimize=True)


def sign(path, text, bg, fg, seed):
    w, h = 256, 128
    rnd = random.Random(seed)
    img = noise_rgb((w, h), bg, 26, seed).convert("RGBA")
    d = ImageDraw.Draw(img)
    grime(d, w, h, rnd, 6)
    font = ImageFont.truetype(FONT_BOLD, 44 if len(text) < 8 else 34)
    _text_center(d, img, text, font, fg + (255,), 38)
    d.rectangle([3, 3, w - 4, h - 4], outline=(30, 30, 30, 255), width=6)
    img.convert("RGB").save(path, optimize=True)


def grass_blade(path):
    s = 128
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(3)
    for _ in range(9):
        x = rnd.randrange(8, s - 8)
        lean = rnd.randrange(-14, 15)
        h = rnd.randrange(50, 110)
        col = (rnd.randrange(70, 110), rnd.randrange(120, 160), rnd.randrange(40, 70), 255)
        d.line([(x, s - 4), (x + lean, s - 4 - h)], fill=col, width=rnd.randrange(2, 4))
    img.save(path, optimize=True)


def leaf(path):
    rnd = random.Random(31)
    s = 256
    img = noise_rgb((s, s), (74, 112, 52), 44, 31).convert("RGBA")
    d = ImageDraw.Draw(img)
    for _ in range(50):  # light/dark blotches
        x, y = rnd.randrange(s), rnd.randrange(s)
        r = rnd.randrange(8, 26)
        c = (rnd.randrange(50, 90), rnd.randrange(100, 140), rnd.randrange(30, 60), 90)
        d.ellipse([x - r, y - r, x + r, y + r], fill=c)
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    img.convert("RGB").save(path, optimize=True)


def window_strip(path):
    w, h = 256, 64
    img = noise_rgb((w, h), (44, 54, 66), 18, 17).convert("RGB")
    d = ImageDraw.Draw(img, "RGBA")
    for x in range(0, w, 42):
        d.rectangle([x + 4, 8, x + 38, h - 8], fill=(26, 34, 46, 255))
        d.polygon([(x + 4, h - 8), (x + 22, 8), (x + 30, 8), (x + 12, h - 8)], fill=(110, 140, 170, 90))
    img.save(path, optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, style in enumerate((0, 1, 2, 3)):
        facade_cell(os.path.join(OUT, f"facade_{'abcd'[i]}.png"), 100 + i * 7, style)
    concrete(os.path.join(OUT, "concrete.png"), 41)
    plaza(os.path.join(OUT, "plaza.png"))
    asphalt(os.path.join(OUT, "asphalt.png"))
    dirt(os.path.join(OUT, "dirt.png"))
    billboard_forever(os.path.join(OUT, "billboard_forever.png"))
    billboard_humanity(os.path.join(OUT, "billboard_humanity.png"))
    billboard_controls(os.path.join(OUT, "billboard_controls.png"))
    sign(os.path.join(OUT, "sign_market.png"), "MARKET", (120, 40, 34), (240, 230, 210), 51)
    sign(os.path.join(OUT, "sign_24h.png"), "24H MART", (30, 70, 110), (235, 240, 245), 57)
    grass_blade(os.path.join(OUT, "grass.png"))
    leaf(os.path.join(OUT, "leaf.png"))
    window_strip(os.path.join(OUT, "window_strip.png"))
    for f in sorted(os.listdir(OUT)):
        im = Image.open(os.path.join(OUT, f))
        print(f, im.size, os.path.getsize(os.path.join(OUT, f)))


if __name__ == "__main__":
    main()
