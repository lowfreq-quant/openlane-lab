#!/usr/bin/env bash
# run_density_fill.sh — P3: 金属密度填充
#
# rules 格式来自 OpenROAD src/fin/test/fill.json（layers 为 map；
# width/height 必须是数组）。语义：在空白区铺满 fill 矩形（非窗密度驱动）。
set -euo pipefail
source "$(dirname "$0")/env.sh"
require_cmd openroad
require_pdk

OUT="$ROOT/runs/15_density"
mkdir -p "$OUT"
RULES="$ROOT/scripts/sky130_density_fill.json"
ODB="$ROOT/runs/05_route/route.odb"
[[ -f "$ODB" ]] || { echo "[ERROR] 缺少 $ODB"; exit 1; }

cat > "$OUT/fill.tcl" <<EOF
source $SCRIPTS_DIR/common.tcl
read_db $ODB
puts "===== density_fill ====="
density_fill -rules $RULES
puts "FILL_DONE"
write_db $OUT/route_filled.odb
write_def $OUT/route_filled.def
report_design_area
EOF

openroad -no_init -exit "$OUT/fill.tcl" 2>&1 | tee "$OUT/fill.log"

echo ""
echo "======== 摘要 ========"
grep -E 'FILL_|Total fills|Filling|Skipping|WARN|ERROR' "$OUT/fill.log" | tail -25
echo "DEF: $OUT/route_filled.def"
