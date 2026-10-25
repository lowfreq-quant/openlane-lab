#!/usr/bin/env python3
"""render_from_json.py — 用 PIL 把 shapes.json 画成分层版图

输入：runs/11_layout_png/shapes.json（由 dump_shapes.py 生成）
输出：runs/11_layout_png/*.png
"""
import json
import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(os.environ.get("ROOT") or Path(__file__).resolve().parents[1])
BASE = Path(os.environ.get("PNG_DIR", ROOT / "runs" / "11_layout_png"))
BASE.mkdir(parents=True, exist_ok=True)

data = json.loads((BASE / "shapes.json").read_text())
dbu = data["dbu"]
x0, y0, x1, y1 = data["bbox"]
layers = data["layers"]
print("dbu", dbu, "bbox", data["bbox"])
print("layers", {k: len(v) for k, v in layers.items()})

COLORS = {
    "64/20": (0, 100, 0), "64/16": (0, 80, 0), "64/5": (0, 60, 0), "64/59": (0, 40, 0),
    "65/20": (0, 180, 0),
    "66/20": (220, 40, 40),
    "66/44": (180, 100, 0),
    "67/20": (40, 140, 255), "67/16": (30, 110, 200), "67/5": (20, 80, 150),
    "67/44": (0, 90, 160),
    "68/20": (50, 50, 255), "68/16": (40, 40, 200), "68/5": (30, 30, 150),
    "68/44": (120, 0, 200),
    "69/20": (220, 0, 220), "69/44": (150, 0, 120),
    "70/20": (255, 140, 0), "70/44": (180, 100, 0),
    "71/20": (0, 200, 200), "71/44": (0, 140, 140), "72/20": (200, 0, 80),
    "93/44": (255, 255, 80), "94/20": (80, 255, 255),
    "236/0": (255, 255, 255), "235/4": (255, 255, 200),
}
NAMES = {
    "64/20": "nwell", "65/20": "diff", "66/20": "poly", "66/44": "licon",
    "67/20": "li1", "67/44": "mcon", "68/20": "met1", "68/44": "via",
    "69/20": "met2", "69/44": "via2", "70/20": "met3", "70/44": "via3",
    "71/20": "met4", "71/44": "via4", "72/20": "met5", "236/0": "outline",
    "93/44": "nsdm", "94/20": "psdm",
}

W = H = 1400
MARGIN = 50


def render(name, keys, label, crop=None):
    """crop=(x0,y0,x1,y1) 时只画这块区域（dbu），用于单元特写"""
    cx0, cy0, cx1, cy1 = crop if crop else (x0, y0, x1, y1)
    cw, ch = max(cx1 - cx0, 1), max(cy1 - cy0, 1)
    s = min((W - 2 * MARGIN) / cw, (H - 2 * MARGIN) / ch)
    ox = MARGIN + (W - 2 * MARGIN - cw * s) / 2
    oy = MARGIN + (H - 2 * MARGIN - ch * s) / 2

    def to_px(x, y):
        return (ox + (x - cx0) * s, H - (oy + (y - cy0) * s))

    img = Image.new("RGB", (W, H), (0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    n = 0
    for k in keys:
        if k not in layers:
            continue
        col = COLORS.get(k, (200, 200, 200))
        for pts in layers[k]:
            px = [to_px(x, y) for x, y in pts]
            if len(px) >= 3:
                draw.polygon(px, fill=col + (170,), outline=col + (255,))
                n += 1
    draw.rectangle([0, 0, W, 52], fill=(0, 0, 0, 220))
    draw.text((12, 8), f"{label}  |  shapes={n}  |  {cw*dbu:.1f} x {ch*dbu:.1f} um",
              fill=(255, 255, 255))
    names = [NAMES.get(k, k) for k in keys if k in layers]
    draw.text((12, 30), "layers: " + ", ".join(names[:10]), fill=(180, 180, 180))
    path = BASE / f"{name}.png"
    img.save(path)
    print(f"wrote {name}.png shapes={n} {os.path.getsize(path)}B")


# 有源区（diff）的包围盒 = 单元实际占的地方，用来出单元特写
diff = layers.get("65/20", [])
if diff:
    xs = [x for poly in diff for x, _ in poly]
    ys = [y for poly in diff for _, y in poly]
    pad = 2500
    zoom = (min(xs) - pad, min(ys) - pad, max(xs) + pad, max(ys) + pad)
else:
    zoom = None

render("00_all", list(layers.keys()), "counter · full die")
if zoom:
    render("00_zoom", list(layers.keys()), "counter · cells (zoom)", crop=zoom)

GROUPS = [
    ("01_nwell", ["64/20", "64/16", "64/5", "64/59"]),
    ("02_diff", ["65/20"]),
    ("03_poly", ["66/20"]),
    ("04_licon", ["66/44"]),
    ("05_li1", ["67/20", "67/16", "67/5"]),
    ("06_mcon", ["67/44"]),
    ("07_met1", ["68/20", "68/16", "68/5"]),
    ("08_via", ["68/44"]),
    ("09_met2", ["69/20", "69/44"]),
    ("10_met3", ["70/20", "70/44"]),
    ("11_implant", ["93/44", "94/20"]),
    ("12_device", ["64/20", "65/20", "66/20", "66/44", "93/44", "94/20"]),
    ("13_lower_metal", ["67/20", "67/16", "67/5", "67/44", "68/20", "68/16", "68/5"]),
    ("14_routing", ["68/20", "68/44", "69/20", "69/44", "70/20"]),
    ("15_pdn", ["68/20", "68/44", "71/20", "71/44", "72/20"]),
]
for n, k in GROUPS:
    # 分层图都裁到单元区域，否则 5% 利用率下整张图全是空白
    render(n, k, n.split("_", 1)[1], crop=zoom)

print("DONE")
