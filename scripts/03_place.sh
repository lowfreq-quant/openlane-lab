#!/usr/bin/env bash
# 03 布局 Place：把标准单元摆进 core
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/03_place"
mkdir -p "$OUT"

FP="$ROOT/runs/02_floorplan"
SDC="$ROOT/constraints/counter.sdc"
if [[ ! -f "$FP/floorplan.odb" ]]; then
  echo "[ERROR] 缺少 $FP/floorplan.odb，请先跑 02_floorplan.sh" >&2
  exit 1
fi
require_cmd openroad "安装方式见 docs/tools.md"

cat > "$OUT/place.tcl" <<'EOF'
source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(FP)/floorplan.odb

if {[info exists ::env(SDC)] && [file exists $::env(SDC)]} {
  read_sdc $::env(SDC)
}

# 全局布局 → 详细布局
global_placement -density 0.55
estimate_parasitics -placement
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded

detailed_placement
check_placement -verbose

write_db $::env(OUT)/place.odb
write_def $::env(OUT)/place.def
report_design_area
EOF

SCRIPTS_DIR="$ROOT/scripts" FP="$FP" SDC="$SDC" OUT="$OUT" \
  openroad -no_init -exit "$OUT/place.tcl" 2>&1 | tee "$OUT/openroad.log"

echo "[DONE] DEF: $OUT/place.def"
echo "       下一步: 04_cts.sh"
