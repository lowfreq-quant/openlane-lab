#!/usr/bin/env bash
# 层次 LVS：不合并电源，保留 VNB/VPB 与 CDL 对齐
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$ROOT"
OUT=runs/17_lvs_device

# 直接用 magic 原始提取（未合并电源）
cp -f "$OUT/counter_hier_ext.spice" "$OUT/counter_hier_raw.spice"

python3 - <<'PY'
from pathlib import Path
import re
out = Path("/mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/17_lvs_device")
cdl = Path("/home/ty/.volare/sky130A/libs.ref/sky130_fd_sc_hd/cdl/sky130_fd_sc_hd.cdl").read_text()
for cand in [
    Path("/mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/10_lvs/counter_cts.v"),
    Path("/mnt/c/Users/ty/Downloads/asic/openlane-lab/runs/01_synth/counter_synth.v"),
]:
    if cand.exists():
        v = cand.read_text(); vpath = cand; break
else:
    raise SystemExit("no netlist")

subckts = {}
for m in re.finditer(r"\.SUBCKT\s+(\S+)\s+(.+)", cdl, re.I):
    subckts[m.group(1)] = m.group(2).split()
inst_re = re.compile(r"(sky130_fd_sc_hd__[a-z0-9_]+)\s+(\S+)\s*\((.*?)\);", re.S)
pin_re = re.compile(r"\.(\w+)\s*\(\s*([^)]*?)\s*\)")
insts = []
for cell, name, conns in inst_re.findall(v):
    pinmap = {a: b.replace(" ", "") for a, b in pin_re.findall(conns)}
    insts.append((cell, name, pinmap))
m = re.search(r"module\s+counter\s*\((.*?)\);", v, re.S)
ports = [p.strip() for p in m.group(1).replace("\n", " ").split(",") if p.strip()]

# golden 保持 CDL 电源脚名
lines = ["* hier golden (CDL pin names)", cdl, ".subckt counter " + " ".join(ports)]
for cell, name, pinmap in insts:
    pins = subckts.get(cell)
    if not pins:
        continue
    conns = []
    for p in pins:
        if p in ("VGND", "VNB", "VPB", "VPWR"):
            conns.append(p)
        else:
            val = pinmap.get(p) or pinmap.get(p.lower()) or pinmap.get(p.upper())
            conns.append(val if val else f"UNCONN_{p}")
    lines.append(f"X{name} " + " ".join(conns) + f" {cell}")
lines.append(".ends counter")
(out / "counter_hier_golden.spice").write_text("\n".join(lines) + "\n")
print("golden insts", len(insts))
PY

# setup：全局电源网 + 忽略 fill/tap/decap
cat > "$OUT/lvs_hier_setup.tcl" <<EOF
source $PDK_PATH/libs.tech/netgen/sky130A_setup.tcl
source $SCRIPTS_DIR/lvs_extra.tcl
foreach n {VPWR VGND VNB VPB} {
  catch {net global "-circuit1 \$n"}
  catch {net global "-circuit2 \$n"}
}
EOF

/usr/bin/netgen-lvs -batch lvs \
  "$OUT/counter_hier_raw.spice counter" \
  "$OUT/counter_hier_golden.spice counter" \
  "$OUT/lvs_hier_setup.tcl" \
  "$OUT/lvs_hier.out" 2>&1 | tail -40

echo "==== RESULT ===="
grep -E 'Result|match uniquely|Number of devices|Number of nets|MISMATCH|Circuits match' \
  "$OUT/lvs_hier.out" 2>/dev/null | tail -25 || true
