#!/usr/bin/env bash
# 时钟压力扫描：对已布线设计做 STA，找 setup 开始违例的临界周期
set -euo pipefail
source "$(dirname "$0")/env.sh"

RT="$ROOT/runs/05_route"
OUT="$ROOT/runs/08_timing_sweep"
mkdir -p "$OUT"

if [[ ! -f "$RT/route.odb" ]]; then
  echo "[ERROR] 缺少 $RT/route.odb，请先跑 05_route.sh" >&2
  exit 1
fi
require_cmd openroad "安装方式见 docs/tools.md"

printf '%-10s %-10s %-10s %s\n' "period" "WNS(ns)" "TNS(ns)" "结论"
for period in 100 20 10 5 2 1 0.5; do
  sdc="$OUT/t_${period}.sdc"
  cat > "$sdc" <<EOF
create_clock -name clk -period $period [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay  0.1 -clock clk [get_ports rst_n]
set_output_delay 0.1 -clock clk [get_ports q*]
set_output_delay 0.1 -clock clk [get_ports tick]
EOF

  log="$OUT/sta_${period}.log"
  SCRIPTS_DIR="$SCRIPTS_DIR" SDC="$sdc" OUT="$OUT" RT="$RT" \
  openroad -no_init -exit <<EOF > "$log" 2>&1
source $SCRIPTS_DIR/common.tcl
read_db $RT/route.odb
read_sdc $sdc
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded
report_wns
report_tns
EOF

  wns=$(grep -E '^wns ' "$log" | tail -1 | awk '{print $3}')
  tns=$(grep -E '^tns ' "$log" | tail -1 | awk '{print $3}')
  verdict=$([[ "$wns" == "0.00" ]] && echo "MET" || echo "违例")
  printf '%-10s %-10s %-10s %s\n' "${period}ns" "${wns:-?}" "${tns:-?}" "$verdict"
done

echo ""
echo "报告在 $OUT/"
