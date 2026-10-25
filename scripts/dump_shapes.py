#!/usr/bin/env python3
"""dump_shapes.py — 把 GDS 里的多边形按层导出成 JSON，供 render_from_json.py 画图

KLayout 的 LayoutView.save_image 在 batch 模式下常出空图，所以走这条
「导出几何 → PIL 自己画」的路。
"""
import json
import os
from pathlib import Path

import pya

ROOT = Path(os.environ.get("ROOT") or Path(__file__).resolve().parents[1])
GDS = Path(os.environ.get("GDS_IN", ROOT / "runs" / "09_gds" / "counter.gds"))
OUT = Path(os.environ.get("SHAPES_JSON", ROOT / "runs" / "11_layout_png" / "shapes.json"))
OUT.parent.mkdir(parents=True, exist_ok=True)

ly = pya.Layout()
ly.read(str(GDS))
top = ly.top_cell()
bb = top.bbox()
dbu = ly.dbu

layers = {}
for i in ly.layer_indexes():
    info = ly.get_info(i)
    key = f"{info.layer}/{info.datatype}"
    polys = []
    for s in top.shapes(i).each():
        if s.is_box():
            b = s.box
            polys.append([[b.left, b.bottom], [b.right, b.bottom],
                          [b.right, b.top], [b.left, b.top]])
        else:
            p = s.polygon if (s.is_polygon() or s.is_path()) else \
                (s.simple_polygon if s.is_simple_polygon() else None)
            if p is None:
                continue
            pts = [[pt.x, pt.y] for pt in p.each_point_hull()]
            if len(pts) >= 3:
                polys.append(pts)
    if polys:
        layers[key] = polys

data = {"dbu": dbu, "bbox": [bb.left, bb.bottom, bb.right, bb.top], "layers": layers}
OUT.write_text(json.dumps(data))
print("layers", {k: len(v) for k, v in layers.items()})
print("bbox", data["bbox"], "dbu", dbu)
print("wrote", OUT)
