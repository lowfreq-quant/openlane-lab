#!/usr/bin/env bash
# 05 布线 Route：全局 + 详细布线 + 天线检查 + 填充单元
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

# 天线检查：长线在等离子刻蚀时积累电荷，必须没有天线违例
check_antennas -verbose

# 用全局布线的估算寄生做时序（没有 RCX 模型，做不了真实提取，见 README）
estimate_parasitics -global_routing
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded

# 填充单元：把空 site 用 fill cell 填满，保证密度/平坦化
# 填完重新 global_connect，否则新实例的电源脚不接网格
filler_placement -prefix FILLER_ {
  sky130_fd_sc_hd__fill_8
  sky130_fd_sc_hd__fill_4
  sky130_fd_sc_hd__fill_2
  sky130_fd_sc_hd__fill_1
}
global_connect

report_design_area
write_db $::env(OUT)/route.odb
write_def $::env(OUT)/route.def
EOF

SCRIPTS_DIR="$ROOT/scripts" CTS="$CTS" SDC="$SDC" OUT="$OUT" \
  openroad -no_init -exit "$OUT/route.tcl" 2>&1 | tee "$OUT/openroad.log"

# detail route 必须收敛到 0；不收敛就别往下走
viol=$(grep -oE 'Number of violations = [0-9]+' "$OUT/openroad.log" | tail -1 | grep -oE '[0-9]+$' || true)
[[ "${viol:-}" == "0" ]] || { echo "[ERROR] 布线未收敛（violations=${viol:-?}）" >&2; exit 1; }

# 天线也必须干净
ant=$(grep -oE 'Found [0-9]+ (net|pin) violations' "$OUT/openroad.log" | grep -oE '[0-9]+' | paste -sd+ - | bc || true)
[[ "${ant:-1}" == "0" ]] || { echo "[ERROR] 有天线违例：$(grep 'Found .* violations' "$OUT/openroad.log" | tr '\n' ' ')" >&2; exit 1; }

fills=$(grep -c 'sky130_fd_sc_hd__fill' "$OUT/route.def" || true)
echo "[DONE] DEF: $OUT/route.def   route violations=0  antenna=0  fillers=${fills:-0}"
echo "       下一步: 06_signoff.sh"
