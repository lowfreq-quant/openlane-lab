#!/usr/bin/env bash
# run_lvs_hier.sh — 层次化 GDS → 器件级 LVS（目标：拓扑 100% match）
set -euo pipefail
source "$(dirname "$0")/env.sh"
require_cmd klayout
require_cmd magic
require_pdk

OUT="$ROOT/runs/17_lvs_device"
mkdir -p "$OUT"
HIER="$OUT/counter_hier.gds"
CDL="$SC_DIR/cdl/sky130_fd_sc_hd.cdl"
SETUP="$PDK_PATH/libs.tech/netgen/sky130A_setup.tcl"
NETGEN=/usr/bin/netgen-lvs

echo "=== 1) 层次化 GDS ==="
klayout -b -r "$ROOT/scripts/make_gds_hier.py" 2>&1 | tail -10
[[ -f "$HIER" ]] || { echo "[ERROR] 无层次 GDS"; exit 1; }

echo "=== 2) Magic 层次提取（不 flatten）==="
cat > "$OUT/extract_hier.tcl" <<EOF
drc off
tech load $PDK_PATH/libs.tech/magic/sky130A.tech
gds readonly true
gds rescale false
gds read $HIER
load counter
select top cell
# 保留层级：不要 extract do local 打平
extract no capacitance
extract no coupling
extract no resistance
extract all
ext2spice lvs
ext2spice -o $OUT/counter_hier_ext.spice
quit -noprompt
EOF

magic -dnull -noconsole -rcfile $PDK_PATH/libs.tech/magic/sky130A.magicrc \
  "$OUT/extract_hier.tcl" > "$OUT/magic_hier.log" 2>&1 || true

if [[ ! -f "$OUT/counter_hier_ext.spice" ]]; then
  echo "[ERROR] 提取失败"; tail -25 "$OUT/magic_hier.log"; exit 1
fi
echo "ext lines: $(wc -l < "$OUT/counter_hier_ext.spice")"
echo "--- subckts ---"
grep -E '^\.subckt' "$OUT/counter_hier_ext.spice" | head -20

echo "=== 3) 电源归一 + golden（CDL）==="
python3 "$ROOT/scripts/fix_hier_lvs.py"

echo "=== 4) netgen LVS（层次）==="
cat > "$OUT/lvs_hier_setup.tcl" <<EOF
source $SETUP
source $SCRIPTS_DIR/lvs_extra.tcl
EOF

$NETGEN -batch lvs \
  "$OUT/counter_hier_ext_fix.spice counter" \
  "$OUT/counter_hier_golden.spice counter" \
  "$OUT/lvs_hier_setup.tcl" \
  "$OUT/lvs_hier.out" | tee "$OUT/netgen_hier.log" | tail -35

echo ""
echo "======== 结果 ========"
grep -E 'Result|match uniquely|contains [0-9]+|MISMATCH|Netlists' "$OUT/lvs_hier.out" 2>/dev/null | tail -15 || true
grep -E 'Result|match' "$OUT/netgen_hier.log" | tail -8
