#!/usr/bin/env python3
"""Side-by-side Android/iOS evidence sheet from real captures (no redrawing, no approximations).

Usage: parity_sheet.py <android repo> <ios screenshots dir> <ios contact sheet> <out.png>

Rows pair the Android lane's final runtime captures (.qa/final) with the iOS simulator captures of the same subject:
installed app icon, the city with all five district motifs, a district detail, and the New Game+ ledger; plus the
two contact sheets rendered from the canonical shared-assets/ files. Requires Pillow.
"""
import pathlib
import sys

from PIL import Image, ImageDraw

android = pathlib.Path(sys.argv[1])
ios = pathlib.Path(sys.argv[2])
ios_sheet = pathlib.Path(sys.argv[3])
out = pathlib.Path(sys.argv[4])

ROWS = [
    ("Installed app icon", [android / ".qa/final/98_launcher_icon.png"], [ios / "en_60_home_screen_icon.png"]),
    ("City and district motifs", [android / f".qa/final/{n}" for n in ("10_city_top.png", "11_city_middle.png", "12_city_bottom.png")],
     [ios / f"en_tour_{n}" for n in ("08_city.png", "09_city_districts.png", "10_city_districts_end.png")]),
    ("District detail (North Quay)", [android / ".qa/final/22_district_docks.png"], [ios / "en_tour_11_district.png"]),
    ("New Game+ ledger", [android / ".qa/final/40_ng_ledger_top.png"], [ios / "en_tour_28_new_game_plus.png"]),
    ("Canonical contact sheets", [android / "docs/asset-contact-sheet.png"], [ios_sheet]),
]

H = 760
GAP = 16
LABEL = 44
BG = (15, 13, 11)
INK = (233, 223, 201)


def fit(path: pathlib.Path) -> Image.Image:
    img = Image.open(path).convert("RGB")
    w = int(img.width * H / img.height)
    return img.resize((w, H), Image.LANCZOS)


rendered = []
for title, left, right in ROWS:
    missing = [p for p in left + right if not p.is_file()]
    if missing:
        raise SystemExit(f"missing evidence for {title}: {missing}")
    a = [fit(p) for p in left]
    b = [fit(p) for p in right]
    rendered.append((title, a, b))

side_w = max(sum(i.width for i in imgs) + GAP * (len(imgs) - 1) for _, a, b in rendered for imgs in (a, b))
width = side_w * 2 + GAP * 3
height = sum(LABEL + H + GAP for _ in rendered) + LABEL + GAP
sheet = Image.new("RGB", (width, height), BG)
draw = ImageDraw.Draw(sheet)
draw.text((GAP, 12), "NOIR LEDGER parity: Android (left) | iOS (right)", fill=INK)
y = LABEL
for title, a, b in rendered:
    draw.text((GAP, y + 12), f"{title}: Android", fill=INK)
    draw.text((side_w + 2 * GAP, y + 12), f"{title}: iOS", fill=INK)
    y += LABEL
    for col, imgs in ((GAP, a), (side_w + 2 * GAP, b)):
        x = col
        for img in imgs:
            sheet.paste(img, (x, y))
            x += img.width + GAP
    y += H + GAP
out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print(f"parity sheet: {out} ({sheet.width}x{sheet.height})")
