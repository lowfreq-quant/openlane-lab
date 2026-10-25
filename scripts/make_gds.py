#!/usr/bin/env python3
"""make_gds.py — 用 KLayout 把 DEF + 标准单元 GDS 合成一个扁平化的顶层 GDS

背景：OpenROAD 26Q2 没有 write_gds，所以改走 KLayout。

**关键坑**：LEF/DEF 里的层名（met1/met2/…）没有 GDS 层号。KLayout 读 DEF 时会
自己编号（met1→5/0、met2→7/0…），和 sky130 的 68/20、69/20 对不上——
结果 GDS 里单元图形对、绕线全在假层上，DRC 扫不到线，会假装"0 违例"。
所以这里必须按层名把 DEF 的几何搬到真实 GDS 层号上。

用法：klayout -b -r scripts/make_gds.py
环境：ROOT / PDK_ROOT / PDK / MERGED_LEF（由 scripts/env.sh 提供）
"""
import os
import sys
from pathlib import Path

import pya

ROOT = Path(os.environ.get("ROOT") or Path(__file__).resolve().parents[1])
PDK_ROOT = Path(os.environ.get("PDK_ROOT", Path.home() / ".volare"))
PDK = os.environ.get("PDK", "sky130A")

LEF = Path(os.environ.get("MERGED_LEF", ROOT / "runs" / "lef" / "sky130_fd_sc_hd_merged.lef"))
CELL_GDS = PDK_ROOT / PDK / "libs.ref" / "sky130_fd_sc_hd" / "gds" / "sky130_fd_sc_hd.gds"
DEF = Path(os.environ.get("ROUTE_DEF", ROOT / "runs" / "05_route" / "route.def"))
OUT = Path(os.environ.get("GDS_OUT", ROOT / "runs" / "09_gds" / "counter.gds"))

# sky130 LEF 层名 → GDS layer/datatype
LAYER_MAP = {
    "nwell": (64, 20), "pwell": (64, 44),
    "li1": (67, 20), "mcon": (67, 44),
    "met1": (68, 20), "via": (68, 44),
    "met2": (69, 20), "via2": (69, 44),
    "met3": (70, 20), "via3": (70, 44),
    "met4": (71, 20), "via4": (71, 44),
    "met5": (72, 20),
}
# LEF/DEF 的辅助层（引脚/标签/阻挡）不进最终 GDS：单元几何已由单元库 GDS 提供
SKIP_SUFFIXES = (".PIN", ".LABEL", ".OBS", ".BLOCKAGE")

for f, hint in ((LEF, "bash scripts/merge_lef.sh"),
                (CELL_GDS, "bash scripts/fetch_pdk.sh"),
                (DEF, "bash scripts/05_route.sh")):
    if not f.is_file():
        print(f"ERROR: 缺少 {f}（{hint}）")
        sys.exit(1)
OUT.parent.mkdir(parents=True, exist_ok=True)

# DEF 里引用 LEF 的 MACRO 抽象（实例的摆放、绕线几何）
opt = pya.LoadLayoutOptions()
cfg = pya.LEFDEFReaderConfiguration()
cfg.lef_files = [str(LEF)]
try:
    cfg.read_lef_with_def = True
except Exception:
    pass
opt.lefdef_config = cfg

ly = pya.Layout()
ly.read(str(CELL_GDS))
print(f"cell lib cells={ly.cells()}")

ly.read(str(DEF), opt)
top = ly.cell("counter")
if top is None:
    print("ERROR: 合并后找不到 cell 'counter'")
    print("tops:", [c.name for c in ly.top_cells()])
    sys.exit(1)
print(f"merged top={top.name} instances={sum(1 for _ in top.each_inst())}")

# 展平：单元几何直接落到顶层，输出只有一个 top cell
top.flatten(True)

ly_out = pya.Layout()
ly_out.dbu = ly.dbu
dst = ly_out.create_cell("counter")

routed = {}
for li in ly.layer_indexes():
    info = ly.get_info(li)
    name = info.name or ""
    if name == "OUTLINE" or any(name.endswith(s) for s in SKIP_SUFFIXES):
        continue
    target = pya.LayerInfo(*LAYER_MAP[name]) if name in LAYER_MAP else info
    shapes = top.shapes(li)
    n = sum(1 for _ in shapes.each())
    if n:
        dst.shapes(ly_out.layer(target)).insert(shapes)
        if name in LAYER_MAP:
            routed[name] = routed.get(name, 0) + n

ly_out.write(str(OUT))
tops = [c.name for c in ly_out.top_cells()]
print(f"GDS_OK size={OUT.stat().st_size} tops={tops}")
print("DEF 绕线层映射:", routed or "(none)")
if tops != ["counter"]:
    print("WARN: 期望只有一个 top cell 'counter'")
for need in ("met1", "met2", "met3"):
    if need not in routed:
        print(f"WARN: GDS 里没有 {need} 的绕线几何（层映射可能失效）")
