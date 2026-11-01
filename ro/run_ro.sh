#!/usr/bin/env bash
# run_ro.sh — 环振（蛇形版）一键复现：前仿 → 版图+DRC → PEX → 后仿 → LVS → 渲染
#
# 用法:
#   bash ro/run_ro.sh               # 完整流程
#   bash ro/run_ro.sh --corners     # 额外跑 tt/ss/ff × -40/25/100C 后仿
#
# 可用环境变量覆盖:
#   RO=~/asic_ro/run    工作目录（magic/ngspice 中间文件）
#   OUT=ro/out/serp     结果输出目录
#   PDK_ROOT=~/.volare  PDK 根目录
#   PDK=sky130A         工艺名
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
RO=${RO:-$HOME/asic_ro/run}
OUT=${OUT:-$HERE/out/serp}
PDK_ROOT=${PDK_ROOT:-$HOME/.volare}
PDK=${PDK:-sky130A}
PDKA=$PDK_ROOT/$PDK
NET=$HERE/netlist
NG_LIB=$PDKA/libs.tech/ngspice/sky130.lib.spice
MAGIC_TECH=$PDKA/libs.tech/magic/sky130A.tech
MAGIC_RC=$PDKA/libs.tech/magic/sky130A.magicrc
NETGEN_SETUP=$PDKA/libs.tech/netgen/sky130A_setup.tcl

CORNERS=0
[[ "${1:-}" == "--corners" ]] && CORNERS=1

say() { printf '\n=== %s ===\n' "$*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "缺少 $1"; }

need ngspice; need klayout; need python3

# magic：apt 的 8.3.105 读不了 sky130 tech（要求 >= 8.3.260），优先用 Nix 版
MAGIC=${MAGIC:-}
if [[ -z "$MAGIC" ]]; then
  if [[ -x "$HOME/.nix-profile/bin/magic" ]]; then
    MAGIC=$HOME/.nix-profile/bin/magic
  else
    MAGIC=$(command -v magic || true)
  fi
fi
[[ -n "$MAGIC" ]] || die "缺少 magic"

# netgen：优先 Nix 版（1.5.323），并设置它需要的 NETGENDIR
NETGEN=${NETGEN:-}
if [[ -z "$NETGEN" ]]; then
  if [[ -x "$HOME/.nix-profile/bin/netgen" ]]; then
    NETGEN=$HOME/.nix-profile/bin/netgen
    NETGENDIR=$(cd "$(dirname "$(readlink -f "$NETGEN")")/../lib/netgen/tcl" && pwd)
    export NETGENDIR
  else
    NETGEN=$(command -v netgen-lvs || command -v netgen || true)
  fi
fi
[[ -n "$NETGEN" ]] || die "缺少 netgen-lvs"
for f in "$NG_LIB" "$MAGIC_TECH" "$MAGIC_RC" "$NETGEN_SETUP" "$NET/ro.spice" "$NET/ro_schem.spice"; do
  [[ -f "$f" ]] || die "缺少 $f"
done

mkdir -p "$RO" "$OUT"
cd "$RO"

# ---------- 1. 前仿 ----------
say "1/5 前仿（原理图网表）"
python3 - "$NET/ro.spice" "$RO/ro_pre.spice" "$NG_LIB" <<'PY'
import re, sys
src, dst, lib = sys.argv[1:4]
keep = []
for line in open(src):
    s = line.strip()
    if re.match(r'^(vvss|vvcc|\.lib|\.control|\.endc|\.end|write|save|tran|meas)\b', s):
        continue
    keep.append(line.rstrip('\n'))
keep.append("""
vvss VSS 0 dc 0
vvcc VCC 0 pwl 0 0 1n 0 1.05n 1.8 200n 1.8
.lib %s tt
.control
save v(out)
tran 0.005n 120n
meas tran r10 when v(out)=0.9 rise=10
meas tran r50 when v(out)=0.9 rise=50
.endc
.end
""" % lib)
open(dst, 'w').write("\n".join(keep) + "\n")
PY
ngspice -b ro_pre.spice > presim.log 2>&1 || { tail -20 presim.log; die "前仿失败"; }
grep -qE '^r50' presim.log || { tail -20 presim.log; die "前仿未起振"; }

# ---------- 2. 版图 ----------
say "2/5 版图（magic：DRC + 提取 + GDS）"
LAYOUT_NAME=ro_serp python3 "$HERE/gen_serp.py" > "$RO/layout.tcl"
"$MAGIC" -T "$MAGIC_TECH" -rcfile "$MAGIC_RC" -dnull -noconsole < layout.tcl > magic.log 2>&1 || true
grep -q "Total DRC errors found: 0" magic.log || {
  echo "--- DRC 摘要 ---"; grep -iE 'drc|error' magic.log | tail -10; die "DRC 未通过"; }
[[ -s ro_serp.spice ]] || die "没有生成 ro_serp.spice"
[[ -s ro_serp.gds ]]   || die "没有生成 ro_serp.gds"

# ---------- 3. 后仿（PEX） ----------
say "3/5 后仿（提取寄生）"
python3 - "$RO/ro_serp.spice" "$RO/ro_serp_post.spice" "$NG_LIB" <<'PY'
import re, sys
src, dst, lib = sys.argv[1:4]
out = []
for line in open(src):
    line = re.sub(r'\s*\*\*.*$', '', line.rstrip('\n'))
    s = line.strip()
    if not s or s.startswith('*') or s.startswith('.end'):
        continue
    out.append(line)
out.append("""
vvss vgnd 0 dc 0
vvcc vpwr 0 pwl 0 0 1n 0 1.05n 1.8 200n 1.8
.lib %s tt
.control
save v(out)
tran 0.005n 120n
meas tran r10 when v(out)=0.9 rise=10
meas tran r50 when v(out)=0.9 rise=50
.endc
.end
""" % lib)
open(dst, 'w').write("* ro post-layout netlist (first line = SPICE title)\n" + "\n".join(out) + "\n")
PY
ngspice -b ro_serp_post.spice > postsim.log 2>&1 || { tail -20 postsim.log; die "后仿失败"; }

# ---------- 4. LVS ----------
say "4/5 LVS"
python3 - "$RO/ro_serp.spice" "$RO/ro_serp_lvs.spice" <<'PY'
import re, sys
src, dst = sys.argv[1:3]
body = []
for line in open(src):
    line = re.sub(r'\s*\*\*.*$', '', line.rstrip('\n'))
    s = line.strip()
    if not s or s.startswith('*') or s.startswith('.end'):
        continue
    if re.match(r'^C\d+\s', s, re.I):
        continue
    body.append(line)
open(dst, 'w').write("* ro lvs netlist\n.subckt ro out vpwr vgnd\n" + "\n".join(body) + "\n.ends ro\n")
PY
"$NETGEN" -batch lvs "ro_serp_lvs.spice ro" "$NET/ro_schem.spice ro" "$NETGEN_SETUP" > lvs.log 2>&1 || true
grep -q "match uniquely" lvs.log || { tail -20 lvs.log; die "LVS 未通过"; }

# ---------- 5. 渲染 ----------
say "5/5 渲染"
cat > render.py <<EOF
import pya
ly = pya.Layout(); ly.read("$RO/ro_serp.gds")
view = pya.LayoutView.new(); view.show_layout(ly, False); view.max_hier(); view.zoom_fit()
view.save_image("$OUT/ro_serp.png", 1400, 1400); view.close()
print("PNG saved")
EOF
klayout -b -r render.py > render.log 2>&1 || true

# ---------- 汇总 ----------
python3 - "$RO/presim.log" "$RO/postsim.log" "$RO/ro_serp.spice" "$RO/ro_serp.gds" <<'PY'
import re, sys, os
def meas(fn):
    v = {}
    for line in open(fn, errors='replace'):
        m = re.match(r'\s*(r\d+)\s*=\s*([0-9.eE+-]+)', line)
        if m: v[m.group(1)] = float(m.group(2))
    return v
pre = meas(sys.argv[1]); post = meas(sys.argv[2])
def freq(v):
    if 'r10' not in v or 'r50' not in v: return None
    return 40.0 / (v['r50'] - v['r10']) / 1e6
fp, fs = freq(pre), freq(post)
print(f"前仿（无寄生） : {fp:8.1f} MHz" if fp else "前仿: 未起振")
print(f"后仿（PEX）    : {fs:8.1f} MHz" if fs else "后仿: 未起振")
if fp and fs:
    print(f"寄生损耗       : {(1-fs/fp)*100:8.2f} %")
print(f"器件/电容      : X={sum(1 for l in open(sys.argv[3]) if l.startswith('X'))} "
      f"C={sum(1 for l in open(sys.argv[3]) if l.startswith('C'))}")
print(f"GDS            : {os.path.getsize(sys.argv[4])} bytes")
PY

# ---------- 可选：corner ----------
if [[ $CORNERS -eq 1 ]]; then
  say "corner 扫描（PEX 后仿：tt/ss/ff × -40/25/100C）"
  printf '%-6s %-8s %12s\n' corner temp "f(MHz)"
  for c in tt ss ff; do
    for t in -40 25 100; do
      python3 - "$RO/ro_serp.spice" "$RO/corner.spice" "$NG_LIB" "$c" "$t" <<'PY'
import re, sys
src, dst, lib, corner, temp = sys.argv[1:6]
out = []
for line in open(src):
    line = re.sub(r'\s*\*\*.*$', '', line.rstrip('\n'))
    s = line.strip()
    if not s or s.startswith('*') or s.startswith('.end'):
        continue
    out.append(line)
out.append("""
vvss vgnd 0 dc 0
vvcc vpwr 0 pwl 0 0 1n 0 1.05n 1.8 200n 1.8
.lib %s %s
.temp %s
.control
save v(out)
tran 0.005n 120n
meas tran r10 when v(out)=0.9 rise=10
meas tran r50 when v(out)=0.9 rise=50
.endc
.end
""" % (lib, corner, temp))
open(dst, 'w').write("* ro post-layout netlist (first line = SPICE title)\n" + "\n".join(out) + "\n")
PY
      ngspice -b corner.spice > "corner_${c}_${t}.log" 2>&1 || true
      python3 - "corner_${c}_${t}.log" "$c" "$t" <<'PY'
import re, sys
v = {}
for line in open(sys.argv[1], errors='replace'):
    m = re.match(r'\s*(r\d+)\s*=\s*([0-9.eE+-]+)', line)
    if m: v[m.group(1)] = float(m.group(2))
if 'r10' in v and 'r50' in v:
    f = 40.0 / (v['r50'] - v['r10']) / 1e6
    print(f"{sys.argv[2]:<6} {sys.argv[3]:<8} {f:12.1f}")
else:
    print(f"{sys.argv[2]:<6} {sys.argv[3]:<8} {'未起振':>12}")
PY
    done
  done
fi

# ---------- 归档 ----------
cp -f ro_serp.gds ro_serp.spice presim.log postsim.log lvs.log magic.log "$OUT"/ 2>/dev/null || true
cp -f ro_serp_post.spice "$OUT"/ 2>/dev/null || true
say "完成"
echo "结果目录: $OUT"
ls -la "$OUT"
