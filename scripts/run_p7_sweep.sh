#!/usr/bin/env bash
# run_p7_sweep.sh — P7: 缩 die / 提频，找工程上有意义的时序边界
#
# 策略：先在固定 netlist 上扫时钟（不重跑 P&R），再试更小 die 重跑 floorplan+place。
set -euo pipefail
source "$(dirname "$0")/env.sh"
require_cmd openroad
require_pdk

OUT="$ROOT/runs/18_p7"
mkdir -p "$OUT"
ODB="$ROOT/runs/05_route/route.odb"
SPEF="$ROOT/runs/13_spef/counter.spef"
[[ -f "$ODB" ]] || { echo "[ERROR] 缺少 route.odb"; exit 1; }

echo "======== A) 现有版图：时钟频率扫描（SPEF）========"
printf '%-10s %-10s %-10s %-8s\n' period_ns freq_MHz setupWNS verdict
for per in 20 10 5 4 3 2.5 2 1.5 1.2 1.0 0.8; do
  cat > "$OUT/sdc.sdc" <<EOF
create_clock -name clk -period $per [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay  0.2 -clock clk [get_ports rst_n]
set_output_delay 0.2 -clock clk [get_ports q*]
set_output_delay 0.2 -clock clk [get_ports tick]
EOF
  openroad -no_init -exit > "$OUT/sta_$per.log" 2>&1 <<EOF || true
source $SCRIPTS_DIR/common.tcl
read_db $ODB
read_sdc $OUT/sdc.sdc
if {[file exists $SPEF]} { read_spef $SPEF } else { estimate_parasitics -global_routing }
report_wns
report_checks -path_delay max -format slack_only
EOF
  wns=$(grep -E '^wns max' "$OUT/sta_$per.log" | tail -1 | awk '{print $3}' || echo "?")
  freq=$(python3 -c "print(f'{1000/$per:.0f}')" 2>/dev/null || echo "?")
  if [[ "${wns}" == "?" || -z "${wns}" ]]; then
    v="ERR"
  else
    v=$(awk -v a="$wns" 'BEGIN{print (a+0>=0)?"MET":"VIOL"}')
  fi
  printf '%-10s %-10s %-10s %-8s\n' "$per" "$freq" "$wns" "$v"
done

echo ""
echo "======== B) 试更小 die（40x40 / core 30x30）重跑布图布局 ========"
# 仅演示 floorplan+place 面积与是否可合法化；完整流可用改过的 02 脚本
cat > "$OUT/small_fp.tcl" <<EOF
source $SCRIPTS_DIR/common.tcl
read_verilog $ROOT/runs/01_synth/counter_synth.v
link_design counter
initialize_floorplan -site unithd -die_area {0 0 40 40} -core_area {2 2 38 38}
make_tracks
place_pins -hor_layers met3 -ver_layers met2
report_design_area
write_def $OUT/small_floorplan.def
EOF
openroad -no_init -exit "$OUT/small_fp.tcl" 2>&1 | tee "$OUT/small_fp.log" | tail -15

echo ""
echo "======== 结论线索 ========"
grep -E 'utilization|Core area|Total instances|wns' "$OUT/small_fp.log" | head
echo "详细 log: $OUT/"
