# make_gds_hier.py — 层次化 GDS（保留标准单元边界）供器件级 LVS
# 用法: klayout -b -r make_gds_hier.py
import pya, os, sys

PDK = os.environ.get("PDK_ROOT", os.path.expanduser("~/.volare")) + "/sky130A"
LEF = "/mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/lef/sky130_fd_sc_hd_merged.lef"
CELL_GDS = f"{PDK}/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds"
DEF = "/mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/05_route/route.def"
OUT = "/mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/17_lvs_device/counter_hier.gds"
os.makedirs(os.path.dirname(OUT), exist_ok=True)

opt = pya.LoadLayoutOptions()
cfg = pya.LEFDEFReaderConfiguration()
cfg.lef_files = [LEF]
try:
    cfg.read_lef_with_def = True
except Exception:
    pass
opt.lefdef_config = cfg

ly = pya.Layout()
ly.read(CELL_GDS)
print(f"cell lib cells={ly.cells()}")
ly.read(DEF, opt)
top = ly.cell("counter")
if top is None:
    tops = list(ly.top_cells())
    print("tops:", [c.name for c in tops])
    top = tops[0]
print(f"top={top.name} insts={sum(1 for _ in top.each_inst())}")

# 裁掉未引用单元，但不 flatten
keep = set()
stack = [top]
while stack:
    c = stack.pop()
    if c.cell_index() in keep:
        continue
    keep.add(c.cell_index())
    for inst in c.each_inst():
        stack.append(inst.cell)
doomed = [c for c in ly.top_cells() if c.cell_index() not in keep]
print(f"pruning {len(doomed)} unused tops")
for c in doomed:
    c.delete()

# 只写 counter 为 top 的层次
ly_out = pya.Layout()
ly_out.dbu = ly.dbu
# 用 write 整个 layout（此时只有一个 top）
ly.write(OUT)
print(f"HIER_GDS_OK size={os.path.getsize(OUT)} tops={[c.name for c in ly.top_cells()]}")
print(f"cells_remaining={ly.cells()}")
