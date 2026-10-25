#!/usr/bin/env bash
# run_lvs_device.sh — P6: 晶体管级 LVS
#
# 版图侧：Magic 从扁平 GDS 提取晶体管（layout extract）
# 源侧：post-CTS 网表 + 单元 CDL（展开为晶体管）
# 比对：netgen-lvs（sky130A_setup 忽略 fill/tap/decap 类）
set -euo pipefail
source "$(dirname "$0")/env.sh"
require_cmd magic "Nix: nix-env -iA nixpkgs.magic-vlsi"
require_cmd python3
require_pdk

OUT="$ROOT/runs/17_lvs_device"
mkdir -p "$OUT"
GDS="$ROOT/runs/09_gds/counter.gds"
CDL="$SC_DIR/cdl/sky130_fd_sc_hd.cdl"
SETUP="$PDK_PATH/libs.tech/netgen/sky130A_setup.tcl"
NETGEN=/usr/bin/netgen-lvs
RCX_PROBE=1

[[ -f "$GDS" ]] || { echo "[ERROR] 缺少 GDS，先 make gds"; exit 1; }
[[ -f "$CDL" ]] || { echo "[ERROR] 缺少 CDL"; exit 1; }

echo "=== 1) Magic: GDS → 晶体管级 SPICE ==="
cat > "$OUT/extract.tcl" <<EOF
drc off
tech load $PDK_PATH/libs.tech/magic/sky130A.tech
gds readonly true
gds rescale false
gds read $GDS
load counter
select top cell
extract do local
extract all
ext2spice lvs
ext2spice -o $OUT/counter_dev_ext.spice
quit -noprompt
EOF

magic -dnull -noconsole -rcfile $PDK_PATH/libs.tech/magic/sky130A.magicrc \
  "$OUT/extract.tcl" > "$OUT/magic_extract.log" 2>&1 || true

if [[ ! -f "$OUT/counter_dev_ext.spice" ]]; then
  echo "[ERROR] 提取失败"; tail -30 "$OUT/magic_extract.log"; exit 1
fi
echo "提取: $(wc -l < "$OUT/counter_dev_ext.spice") 行"

echo "=== 2) 电源脚归一 ==="
python3 - <<'PY'
import os
import re
from pathlib import Path
base = Path(os.environ["ROOT"]) / "runs" / "17_lvs_device"
src = base / "counter_dev_ext.spice"
dst = base / "counter_dev_ext_fix.spice"

def fix(n: str) -> str:
    n = n.strip()
    # layout 的阱/衬底经 tap 接电源，LVS 时并入电源网
    if n in ("VPWR", "VPB") or n.endswith("/VPWR") or n.endswith("/VPB"):
        return "VPWR"
    if n in ("VGND", "VNB", "SUB") or n.endswith("/VGND") or n.endswith("/VNB"):
        return "VGND"
    return n

out = []
buf = []
for line in src.read_text().splitlines(True):
    if line.startswith("+"):
        buf.append(line); continue
    if buf:
        out.append("".join(buf)); buf = []
    buf.append(line)
if buf:
    out.append("".join(buf))

fixed = []
for block in out:
    if block.startswith(".subckt counter"):
        parts = block.replace("\n+", " ").split()
        name = parts[1]
        ports = []
        seen = set()
        for p in parts[2:]:
            p2 = fix(p)
            if p2 not in seen:
                seen.add(p2); ports.append(p2)
        fixed.append(".subckt " + name + " " + " ".join(ports))
    elif block[:1] in ("X", "x"):
        toks = block.replace("\n+", " ").replace("\n", " ").split()
        cell = toks[-1]
        nets = [fix(t) for t in toks[1:-1]]
        fixed.append(toks[0] + " " + " ".join(nets) + " " + cell)
    else:
        fixed.append(block.replace("\n+", " +"))
dst.write_text("\n".join(fixed) + "\n")
print("wrote", dst)
PY

echo "=== 3) 源网表：CDL + post-CTS 顶层 ==="
# 用 make_golden 若已有；否则从 counter_cts.v 生成
if [[ ! -f "$OUT/counter_golden_dev.spice" ]]; then
  python3 - <<'PY'
import os
import re
from pathlib import Path
root = Path(os.environ["ROOT"])
out = root / "runs" / "17_lvs_device"
# 优先 post-CTS
for cand in [
    root / "runs/10_lvs/counter_cts.v",
    root / "runs/01_synth/counter_synth.v",
]:
    if cand.exists():
        v = cand.read_text(); vpath = cand; break
else:
    raise SystemExit("no netlist")
cdl = Path(os.environ["SC_CDL"]).read_text()
subckts = {}
for m in re.finditer(r'\.SUBCKT\s+(\S+)\s+(.+)', cdl, re.I):
    subckts[m.group(1)] = m.group(2).split()
inst_re = re.compile(r'(sky130_fd_sc_hd__[a-z0-9_]+)\s+(\S+)\s*\((.*?)\);', re.S)
pin_re = re.compile(r'\.(\w+)\s*\(\s*([^)]*?)\s*\)')
insts = []
for cell, name, conns in inst_re.findall(v):
    pinmap = {a: b.replace(' ','') for a,b in pin_re.findall(conns)}
    insts.append((cell, name, pinmap))
m = re.search(r'module\s+counter\s*\((.*?)\);', v, re.S)
ports = [p.strip() for p in m.group(1).replace('\n',' ').split(',') if p.strip()]
lines = ["* transistor-level LVS golden", cdl, ".subckt counter " + " ".join(ports)]
for cell, name, pinmap in insts:
    pins = subckts.get(cell)
    if not pins:
        print("skip", cell); continue
    conns = []
    for p in pins:
        if p in ("VPWR", "VPB"):
            conns.append("VPWR")  # 阱并入电源
        elif p in ("VGND", "VNB", "SUB"):
            conns.append("VGND")
        else:
            val = pinmap.get(p) or pinmap.get(p.lower()) or pinmap.get(p.upper())
            conns.append(val if val else f"UNCONN_{p}")
    lines.append(f"X{name} " + " ".join(conns) + f" {cell}")
lines.append(".ends counter")
(out / "counter_golden_dev.spice").write_text("\n".join(lines) + "\n")
print("golden insts", len(insts), "from", vpath)
PY
fi

echo "=== 4) netgen 晶体管级 LVS ==="
cat > "$OUT/lvs_setup.tcl" <<EOF
source $SETUP
source $SCRIPTS_DIR/lvs_extra.tcl
EOF

$NETGEN -batch lvs \
  "$OUT/counter_dev_ext_fix.spice counter" \
  "$OUT/counter_golden_dev.spice counter" \
  "$OUT/lvs_setup.tcl" \
  "$OUT/lvs_dev.out" | tee "$OUT/netgen.log" | tail -40

echo ""
echo "======== 结果 ========"
grep -E 'Result|Circuit [0-9] contains|contains [0-9]+|MISMATCH|match uniquely|Netlists' \
  "$OUT/lvs_dev.out" 2>/dev/null | tail -20 || true
grep -E 'Result|match' "$OUT/netgen.log" | tail -10
