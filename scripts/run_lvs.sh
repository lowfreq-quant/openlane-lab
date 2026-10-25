#!/usr/bin/env bash
# run_lvs.sh — LVS：版图提取网表 vs post-CTS 网表（单元级）
#
# 前置：
#   bash scripts/merge_lef.sh          # 合并 LEF
#   bash scripts/dump_cts_netlist.sh   # runs/10_lvs/counter_cts.v
#   bash scripts/lvs_extract.sh        # runs/10_lvs/counter_ext_cell.spice
#
# 本脚本：生成金标准 → 合并电源脚 → netgen 比对 → 判定
set -euo pipefail
source "$(dirname "$0")/env.sh"

cd "$ROOT"
OUT="$ROOT/runs/10_lvs"
mkdir -p "$OUT"
require_cmd netgen-lvs "sudo apt install netgen-lvs（注意不是 netgen）"
require_cmd python3 "apt install python3"
require_pdk

for f in counter_cts.v counter_ext_cell.spice; do
  if [[ ! -s "$OUT/$f" ]]; then
    echo "[ERROR] 缺少 $OUT/$f，请先按脚本头部的顺序跑前置步骤" >&2
    exit 1
  fi
done

echo "=== 1) 生成金标准（post-CTS + CDL）==="
python3 "$ROOT/scripts/make_golden.py"

echo "=== 2) 合并提取网表的电源脚 ==="
python3 "$ROOT/scripts/fix_ext_power.py"

echo "=== 3) netgen 比对 ==="
cat > "$OUT/lvs_setup.tcl" <<EOF
source $PDK_PATH/libs.tech/netgen/sky130A_setup.tcl
source $ROOT/scripts/lvs_extra.tcl
EOF

netgen-lvs -batch lvs \
  "$OUT/counter_ext_fix.spice counter" \
  "$OUT/counter_golden.spice counter" \
  "$OUT/lvs_setup.tcl" \
  "$OUT/lvs.out" 2>&1 | tee "$OUT/netgen_lvs.log" | tail -20

echo ""
echo "=== 结果 ==="
grep -E 'devices|nets|Netlists|Circuits match|match uniquely|MISMATCH' "$OUT/lvs.out" | tail -12

if grep -q 'Netlists match uniquely' "$OUT/lvs.out"; then
  echo ""
  echo "[PASS] LVS: Netlists match uniquely"
else
  echo ""
  echo "[FAIL] LVS 未通过，详见 $OUT/lvs.out" >&2
  exit 1
fi
