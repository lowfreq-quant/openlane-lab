#!/usr/bin/env bash
# 06 签核 Signoff：静态时序分析（STA）
#
# GDS / DRC / LVS 不在这里做——见：
#   bash scripts/run_gds_drc.sh    # DEF → GDS → sky130 DRC
#   bash scripts/dump_cts_netlist.sh && bash scripts/run_lvs_cell.sh && bash scripts/run_lvs.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/06_signoff"
mkdir -p "$OUT"

RT="$ROOT/runs/05_route"
SDC="$ROOT/constraints/counter.sdc"
if [[ ! -f "$RT/route.odb" ]]; then
  echo "[ERROR] 缺少 $RT/route.odb，请先跑 05_route.sh" >&2
  exit 1
fi

if command -v openroad >/dev/null 2>&1; then
  cat > "$OUT/sta.tcl" <<'EOF'
source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(RT)/route.odb
read_sdc $::env(SDC)
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded
report_checks -path_delay min
report_clock_skew
report_wns
report_tns
report_design_area
EOF
  SCRIPTS_DIR="$ROOT/scripts" RT="$RT" SDC="$SDC" OUT="$OUT" \
    openroad -no_init -exit "$OUT/sta.tcl" 2>&1 | tee "$OUT/sta.log"
else
  echo "[ERROR] 未找到 openroad，无法做 STA" >&2
  exit 1
fi

# --- 布线 DRC 摘要（详细布线自己报的，不是版图 DRC）---
if [[ -f "$RT/route_drc.rpt" ]]; then
  echo "--- 布线 DRC：$RT/route_drc.rpt ---"
  if [[ -s "$RT/route_drc.rpt" ]]; then
    head -20 "$RT/route_drc.rpt"
  else
    echo "（空文件 = 0 条）"
  fi
fi

# --- PDN 连通性 + IR drop ---
cat > "$OUT/pdn_check.tcl" <<'EOF'
source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(RT)/route.odb
foreach n {VPWR VGND} {
  if {[catch {check_power_grid -net $n} err]} {
    puts "PDN_CHECK_FAIL $n: $err"
  }
}

# LEF 里层电阻有、via 电阻没有；PSM 遇到 0 电阻会报 PSM-0021。
# 这里按 5 ohm/个 假设（见 README「已知局限」），只为让 PSM 能算出压降。
foreach v {via via2 via3 via4} {
  catch {set_layer_rc -via $v -resistance 5.0}
}
foreach n {VPWR VGND} {
  if {[catch {analyze_power_grid -net $n} err]} {
    puts "IR_FAIL $n: $err"
  }
}
puts "PDN_CHECK_DONE"
EOF
SCRIPTS_DIR="$ROOT/scripts" RT="$RT" OUT="$OUT" \
  openroad -no_init -exit "$OUT/pdn_check.tcl" 2>&1 | tee "$OUT/pdn_check.log" >/dev/null
if grep -q 'PDN_CHECK_FAIL' "$OUT/pdn_check.log"; then
  echo "[ERROR] PDN 连通性检查失败：" >&2
  grep 'PDN_CHECK_FAIL' "$OUT/pdn_check.log" >&2
  exit 1
fi
# check_power_grid 和 analyze_power_grid 都会打这行，按网名去重再计数
pdn_ok=$(grep -oE 'All shapes on net [A-Za-z0-9_]+ are connected' "$OUT/pdn_check.log" | sort -u | wc -l)
echo "[DONE] PDN: ${pdn_ok:-0}/2 个电源网所有图形连通（check_power_grid）"
if [[ "${pdn_ok:-0}" -ne 2 ]]; then
  echo "[ERROR] 电源网连通数不对（期望 2）" >&2
  exit 1
fi

if grep -q 'IR_FAIL' "$OUT/pdn_check.log"; then
  echo "[WARN] IR drop 分析失败（不阻塞流程）："
  grep 'IR_FAIL' "$OUT/pdn_check.log" | sed 's/^/       /'
else
  grep -E '^Net +: (VPWR|VGND)|Worstcase IR drop|Percentage drop' "$OUT/pdn_check.log" \
    | sed 's/^/       /'
fi

wns=$(grep -E '^wns ' "$OUT/sta.log" | tail -1 | awk '{print $3}')
tns=$(grep -E '^tns ' "$OUT/sta.log" | tail -1 | awk '{print $3}')
echo "[DONE] STA: WNS=${wns:-?} TNS=${tns:-?}  报告: $OUT/sta.log"
echo "       版图签核下一步: bash scripts/run_gds_drc.sh"
