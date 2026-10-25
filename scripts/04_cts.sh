#!/usr/bin/env bash
# 04 时钟树综合 CTS：插 buffer 平衡时钟 skew
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/04_cts"
mkdir -p "$OUT"

PL="$ROOT/runs/03_place"
SDC="$ROOT/constraints/counter.sdc"
if [[ ! -f "$PL/place.odb" ]]; then
  echo "[ERROR] 缺少 $PL/place.odb，请先跑 03_place.sh" >&2
  exit 1
fi
require_cmd openroad "安装方式见 docs/tools.md"

cat > "$OUT/cts.tcl" <<'EOF'
source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(PL)/place.odb

if {[info exists ::env(SDC)] && [file exists $::env(SDC)]} {
  read_sdc $::env(SDC)
}

# 时钟树：OpenROAD 内置 CTS
clock_tree_synthesis \
  -buf_list {sky130_fd_sc_hd__buf_1 sky130_fd_sc_hd__buf_2} \
  -sink_clustering_enable \
  -balance_levels

# 插完 buffer 要重新合法化
detailed_placement
estimate_parasitics -placement
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded
report_clock_skew

write_db $::env(OUT)/cts.odb
write_def $::env(OUT)/cts.def
EOF

SCRIPTS_DIR="$ROOT/scripts" PL="$PL" SDC="$SDC" OUT="$OUT" \
  openroad -no_init -exit "$OUT/cts.tcl" 2>&1 | tee "$OUT/openroad.log"

echo "[DONE] DEF: $OUT/cts.def"
echo "       注意：CTS 会插时钟 buffer，网表单元数会变多（23 → 26）"
echo "       下一步: 05_route.sh"
