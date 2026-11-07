#!/usr/bin/env python3
"""Builds a contact sheet directly from the canonical files in shared-assets/ (not from app screenshots).

PNG masters are used as-is; SVG-only marks are rasterised with `rsvg-convert` (librsvg) and composited on the shared
ground colour. Requires Pillow. Usage: contact_sheet.py <out.png>
"""
import json
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
PACK = ROOT / "shared-assets"
manifest = json.loads((PACK / "asset-manifest.json").read_text(encoding="utf-8"))
tokens = json.loads((PACK / "tokens/tokens.json").read_text(encoding="utf-8"))["colors"]
ground = tokens["ground"]["hex"]
ink = tokens["ink"]["hex"]

CELL_W, CELL_H, PAD, LABEL = 300, 220, 16, 34
items = []
tmp = pathlib.Path(tempfile.mkdtemp())
for a in manifest["assets"]:
    if a["kind"] == "tokens":
        continue
    if "png" in a:
        path = PACK / a["png"]["source"]
    elif a["source"].endswith(".png"):
        path = PACK / a["source"]
    else:
        path = tmp / (a["id"] + ".png")
        subprocess.run(["rsvg-convert", "-w", "160", "-o", str(path), str(PACK / a["source"])], check=True)
    items.append((a["id"], path))

cols = 6
rows = (len(items) + cols - 1) // cols
sheet = Image.new("RGB", (cols * CELL_W, rows * CELL_H + 60), ground)
draw = ImageDraw.Draw(sheet)
draw.text((PAD, 18), f"NOIR LEDGER shared-assets — manifest v{manifest['version']} — {len(items)} canonical files", fill=ink)
for i, (asset_id, path) in enumerate(items):
    x = (i % cols) * CELL_W
    y = 60 + (i // cols) * CELL_H
    img = Image.open(path).convert("RGBA")
    img.thumbnail((CELL_W - 2 * PAD, CELL_H - LABEL - 2 * PAD))
    bg = Image.new("RGBA", img.size, tokens["surface2"]["hex"])
    bg.alpha_composite(img)
    sheet.paste(bg.convert("RGB"), (x + (CELL_W - img.width) // 2, y + PAD))
    draw.text((x + PAD, y + CELL_H - LABEL), asset_id, fill=ink)
out = pathlib.Path(sys.argv[1])
out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print(f"contact sheet: {out} ({len(items)} assets)")
