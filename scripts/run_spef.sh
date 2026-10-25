#!/usr/bin/env bash
# run_spef.sh — OpenRCX 真寄生提取 → SPEF → STA 对比
#
# 为什么：此前 STA/SDF 用 estimate_parasitics -global_routing 的估算值；
# 有了 rcx_rules.info 就能 extract_parasitics 提出每根线的 R/C，write_spef 落盘，
# 再 read_spef 重算——数字才可追溯。
#
# 产物：runs/13_spef/counter.spef + spef.log（估算 vs 提取 的 WNS/TNS）
set -euo pipefail
source "$(dirname "$0")/env.sh"

require_cmd openroad "见 docs/tools.md"
require_pdk

RCX="$PDK_PATH/libs.tech/openlane/rcx_rules.info"
ODB="$ROOT/runs/05_route/route.odb"
SDC="$ROOT/constraints/counter.sdc"
OUT="$ROOT/runs/13_spef"
mkdir -p "$OUT"

# filler 后的 odb 寄生会过期；若存在则优先
if [[ -f "$ROOT/runs/05_route/route_filled.odb" ]]; then
  ODB="$ROOT/runs/05_route/route_filled.odb"
fi

[[ -f "$ODB" ]] || { echo "[ERROR] 缺少 $ODB，先 make all" >&2; exit 1; }
[[ -f "$RCX" ]] || { echo "[ERROR] 缺少 RCX rules: $RCX" >&2; exit 1; }

echo "[info] ODB  = $ODB"
echo "[info] RCX  = $RCX"

cat > "$OUT/spef.tcl" <<EOF
source $SCRIPTS_DIR/common.tcl
read_db $ODB
read_sdc $SDC

puts "======== 1) estimate_parasitics (baseline) ========"
estimate_parasitics -global_routing
puts "WNS_EST [report_wns]"
puts "TNS_EST [report_tns]"
report_checks -path_delay max -digits 3

puts "======== 2) extract_parasitics (OpenRCX) ========"
if {[catch {extract_parasitics -ext_model_file $RCX} err]} {
  puts "EXTRACT_FAILED: \$err"
  exit 1
}
puts "EXTRACT_OK"

write_spef $OUT/counter.spef
puts "SPEF_WRITTEN"

puts "======== 3) STA with SPEF ========"
if {[catch {read_spef $OUT/counter.spef} err]} {
  puts "READ_SPEF_FAILED: \$err"
  exit 1
}
puts "SPEF_LOADED"
puts "WNS_SPEF [report_wns]"
puts "TNS_SPEF [report_tns]"
report_checks -path_delay max -digits 3
report_checks -path_delay min -digits 3
report_parasitic_annotation -report_unannotated
EOF

openroad -no_init -exit "$OUT/spef.tcl" 2>&1 | tee "$OUT/spef.log"

# ---- 1 ns 压力：估算 vs SPEF 的差异才明显 ----
cat > "$OUT/spef_stress.tcl" <<EOF
source $SCRIPTS_DIR/common.tcl
read_db $ODB
create_clock -name clk -period 1.0 [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay  0.1 -clock clk [get_ports rst_n]
set_output_delay 0.1 -clock clk [get_ports q*]
set_output_delay 0.1 -clock clk [get_ports tick]

puts "---- STRESS 1ns: estimate ----"
estimate_parasitics -global_routing
report_wns
report_checks -path_delay max -digits 3

puts "---- STRESS 1ns: SPEF ----"
extract_parasitics -ext_model_file $RCX
read_spef $OUT/counter.spef
report_wns
report_checks -path_delay max -digits 3
EOF

openroad -no_init -exit "$OUT/spef_stress.tcl" 2>&1 | tee "$OUT/spef_stress.log" | grep -E 'STRESS|wns|slack \(|Startpoint|Endpoint|data arrival' | tail -30

echo ""
echo "======== 产物 ========"
ls -la "$OUT"
if [[ -f "$OUT/counter.spef" ]]; then
  echo "SPEF 行数: $(wc -l < "$OUT/counter.spef")"
  grep -E 'WNS_EST|TNS_EST|WNS_SPEF|TNS_SPEF|EXTRACT|SPEF_' "$OUT/spef.log" || true
fi
