#!/usr/bin/env bash
# run_corner_sta.sh — 多工艺角 STA（tt / ff / ss）
#
# 为什么：只跑 tt 一个 corner，setup 和 hold 都"看起来很好"，
# 但真实情况是 ss 先挂 setup、ff 先挂 hold。多 corner 才能看出哪边先不行。
#
# 两张表：
#   1) 标称签核：真实 SDC（constraints/counter.sdc，10 MHz），setup + hold 都看
#   2) 频率压力：1 ns 压力 SDC（uncertainty 0.05 / IO delay 0.1），只看 setup
#      —— 这里不能看 hold：把 IO delay 压到 0.1 会让输入路径假性 hold 违例，
#         所以 hold 只在标称 SDC 下判。
#
# 判据：标称周期下所有 corner 的 setup/hold WNS 必须 >= 0，否则退出 1。
set -euo pipefail
source "$(dirname "$0")/env.sh"

ROOT_RT="$ROOT/runs/05_route"
OUT="$ROOT/runs/13_corners"
mkdir -p "$OUT"
require_cmd openroad "安装方式见 docs/tools.md"
require_pdk

[[ -f "$ROOT_RT/route.odb" ]] || { echo "[ERROR] 缺少 route.odb，先跑 make all" >&2; exit 1; }

LIBDIR="$SC_DIR/lib"
declare -A LIB=(
  [tt]="$LIBDIR/sky130_fd_sc_hd__tt_025C_1v80.lib"
  [ff]="$LIBDIR/sky130_fd_sc_hd__ff_n40C_1v95.lib"
  [ss]="$LIBDIR/sky130_fd_sc_hd__ss_100C_1v40.lib"
)
CORNERS="tt ff ss"

for c in $CORNERS; do
  [[ -f "${LIB[$c]}" ]] || { echo "[ERROR] 找不到 ${LIB[$c]}" >&2; exit 1; }
done

# 1 ns 压力约束（只用于 setup 频率比较）
cat > "$OUT/t_stress_1ns.sdc" <<'EOF'
create_clock -name clk -period 1 [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay  0.1 -clock clk [get_ports rst_n]
set_output_delay 0.1 -clock clk [get_ports q*]
set_output_delay 0.1 -clock clk [get_ports tick]
EOF

run_sta() {   # $1=corner $2=sdc $3=tag $4=extra reports
  local c=$1 sdc=$2 tag=$3 extra=$4
  cat > "$OUT/sta.tcl" <<EOF
read_lef \$::env(MERGED_LEF)
read_liberty ${LIB[$c]}
read_db $ROOT_RT/route.odb
read_sdc $sdc
estimate_parasitics -global_routing
$extra
EOF
  MERGED_LEF="$MERGED_LEF" openroad -no_init -exit "$OUT/sta.tcl" > "$OUT/sta_${c}_${tag}.log" 2>&1
}

printf '== 标称签核（真实 SDC, 10 MHz）==\n'
printf '%-5s %-9s %-10s %-9s %-10s %s\n' "corner" "setup WNS" "setup slack" "hold WNS" "hold slack" "结论"
fail=0
for c in $CORNERS; do
  run_sta "$c" "$ROOT/constraints/counter.sdc" "nominal" \
    "puts \"SLACK_MAX_BEGIN\"
report_checks -path_delay max -format slack_only
puts \"SLACK_MAX_END\"
puts \"SLACK_MIN_BEGIN\"
report_checks -path_delay min -format slack_only
puts \"SLACK_MIN_END\"
report_wns
report_tns
report_wns -min
report_tns -min"
  log="$OUT/sta_${c}_nominal.log"
  wns=$(grep -E '^wns max' "$log" | tail -1 | awk '{print $3}')
  tns=$(grep -E '^tns max' "$log" | tail -1 | awk '{print $3}')
  hwns=$(grep -E '^wns min' "$log" | tail -1 | awk '{print $3}')
  sslack=$(awk '/SLACK_MAX_BEGIN/{f=1;next} /SLACK_MAX_END/{f=0} f && $0 !~ /^Group/ && $0 !~ /^---/ && NF>=2 {print $NF}' "$log" | sort -g | head -1)
  hslack=$(awk '/SLACK_MIN_BEGIN/{f=1;next} /SLACK_MIN_END/{f=0} f && $0 !~ /^Group/ && $0 !~ /^---/ && NF>=2 {print $NF}' "$log" | sort -g | head -1)
  verdict=$(awk -v a="${wns:-0}" -v b="${hwns:-0}" 'BEGIN{ if (a+0 >= 0 && b+0 >= 0) print "MET"; else print "违例" }')
  printf '%-5s %-9s %-10s %-9s %-10s %s\n' "$c" "${wns:-?}" "${sslack:-?}" "${hwns:-?}" "${hslack:-?}" "$verdict"
  [[ "$verdict" == "MET" ]] || fail=1
done

printf '\n== 频率压力（1 ns，只看 setup）==\n'
printf '%-5s %-9s %-10s %s\n' "corner" "setup WNS" "setup slack" "结论"
for c in $CORNERS; do
  run_sta "$c" "$OUT/t_stress_1ns.sdc" "1ns" \
    "puts \"SLACK_MAX_BEGIN\"
report_checks -path_delay max -format slack_only
puts \"SLACK_MAX_END\"
report_wns
report_tns"
  log="$OUT/sta_${c}_1ns.log"
  wns=$(grep -E '^wns max' "$log" | tail -1 | awk '{print $3}')
  tns=$(grep -E '^tns max' "$log" | tail -1 | awk '{print $3}')
  sslack=$(awk '/SLACK_MAX_BEGIN/{f=1;next} /SLACK_MAX_END/{f=0} f && $0 !~ /^Group/ && $0 !~ /^---/ && NF>=2 {print $NF}' "$log" | sort -g | head -1)
  verdict=$(awk -v a="${wns:-0}" 'BEGIN{ print (a+0 >= 0) ? "MET" : "违例" }')
  printf '%-5s %-9s %-10s %s\n' "$c" "${wns:-?}" "${sslack:-?}" "$verdict"
done

echo ""
echo "[INFO] 报告在 $OUT/"
if [[ "$fail" -ne 0 ]]; then
  echo "[FAIL] 标称周期下至少一个 corner 的 WNS < 0" >&2
  exit 1
fi
echo "[PASS] 10 MHz 下 tt/ff/ss 的 setup 与 hold 全部 MET"
