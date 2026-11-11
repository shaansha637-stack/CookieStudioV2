#!/usr/bin/env python3
"""Generates the Cookie Studio app icon (1024x1024 PNG) + asset catalog.
Pure Python (no external packages)."""
import json, math, os, struct, zlib

S = 1024
ROOT = os.path.join("Sources", "CookieStudio", "Assets.xcassets")
ICONSET = os.path.join(ROOT, "AppIcon.appiconset")
os.makedirs(ICONSET, exist_ok=True)

def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def clamp01(v):
    return 0.0 if v < 0 else 1.0 if v > 1 else v

BG_A, BG_B = (0x3B, 0x1F, 0x7A), (0x10, 0x07, 0x1E)
COOKIE_L, COOKIE_D = (0xFF, 0xCB, 0x7A), (0xE5, 0x82, 0x2A)
RIM = (0xB8, 0x62, 0x1B)
CHIP = (0x4A, 0x25, 0x11)

CX, CY, R = 512, 545, 335
BITES = [(800, 275, 125), (865, 420, 70)]
CHIPS = [(420, 410, 50, 38), (610, 520, 54, 40), (440, 640, 44, 56),
         (610, 710, 52, 40), (335, 560, 36, 30), (525, 330, 40, 34),
         (705, 430, 40, 32), (715, 650, 42, 34)]

rows = []
for y in range(S):
    row = bytearray([0])
    for x in range(S):
        t = (x + y) / (2 * S)
        col = lerp(BG_A, BG_B, t)

        # soft glow behind the cookie
        gd = math.hypot(x - CX, y - CY)
        glow = clamp01(1 - gd / 560) ** 2 * 0.35
        col = lerp(col, (0xFF, 0x8A, 0x5B), glow)

        d = math.hypot(x - CX, y - CY)
        a = clamp01(R - d + 0.5)
        if a > 0:
            for bx, by, br in BITES:
                a *= clamp01(math.hypot(x - bx, y - by) - br + 0.5)
        if a > 0:
            tt = clamp01(0.5 + ((x + y) - (CX + CY)) / (2 * R * 1.4))
            c = lerp(COOKIE_L, COOKIE_D, tt)
            if d > R - 22:
                c = lerp(c, RIM, clamp01((d - (R - 22)) / 22) * 0.8)
            for cx, cy, rx, ry in CHIPS:
                e = math.hypot((x - cx) / rx, (y - cy) / ry)
                ca = clamp01((1 - e) * min(rx, ry) + 0.5)
                if ca > 0:
                    hl = clamp01(1 - math.hypot(x - (cx - rx * 0.3), y - (cy - ry * 0.3)) / (rx * 0.9)) * 0.25
                    c = lerp(c, lerp(CHIP, (0x9A, 0x5A, 0x36), hl), ca)
            col = lerp(col, c, a)
        row += bytes((int(col[0]), int(col[1]), int(col[2])))
    rows.append(bytes(row))

raw = b"".join(rows)
def chunk(tag, data):
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))

with open(os.path.join(ICONSET, "icon.png"), "wb") as f:
    f.write(png)
with open(os.path.join(ICONSET, "Contents.json"), "w") as f:
    json.dump({"images": [{"filename": "icon.png", "idiom": "universal",
                           "platform": "ios", "size": "1024x1024"}],
               "info": {"author": "xcode", "version": 1}}, f, indent=2)
with open(os.path.join(ROOT, "Contents.json"), "w") as f:
    json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
print("Icon generated:", os.path.join(ICONSET, "icon.png"))
