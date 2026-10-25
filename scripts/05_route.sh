#!/usr/bin/env bash
# 05 布线 Route：全局 + 详细布线
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/05_route"
mkdir -p "$OUT"

CTS="$ROOT/runs/04_cts"
SDC="$ROOT/constraints/counter.sdc"
if [[ ! -f "$CTS/cts.odb" ]]; then
  echo "[ERROR] 缺少 $CTS/cts.odb，请先跑 04_cts.sh" >&2
  exit 1
fi
require_cmd openroad "安装方式见 docs/tools.md"

cat > "$OUT/route.tcl" <<'EOF'
source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(CTS)/cts.odb
read_sdc $::env(SDC)

set_thread_count 4
global_route -congestion_iterations 50
detailed_route -output_drc "$::env(OUT)/route_drc.rpt" \
               -output_maze "$::env(OUT)/maze.log"

# 用全局布线的估算寄生做时序，不是真实 RC 提取（见 README「已知局限」）
estimate_parasitics -global_routing
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded
report_design_area

write_db $::env(OUT)/route.odb
write_def $::env(OUT)/route.def
EOF

SCRIPTS_DIR="$ROOT/scripts" CTS="$CTS" SDC="$SDC" OUT="$OUT" \
  openroad -no_init -exit "$OUT/route.tcl" 2>&1 | tee "$OUT/openroad.log"

# detail route 必须收敛到 0；不收敛就别往下走
viol=$(grep -oE 'Number of violations = [0-9]+' "$OUT/openroad.log" | tail -1 | grep -oE '[0-9]+$' || true)
echo "[DONE] DEF: $OUT/route.def    DRC violations = ${viol:-?}"
[[ "${viol:-}" == "0" ]] || { echo "[ERROR] 布线未收敛（violations=${viol:-?}）" >&2; exit 1; }
echo "       下一步: 06_signoff.sh"
