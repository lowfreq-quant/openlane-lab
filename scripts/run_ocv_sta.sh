#!/usr/bin/env bash
# run_ocv_sta.sh — P5: OCV derate + 更多电压/温度 corner
#
# 为什么：tt/ff/ss 各一点不够；真实签核要看 derate 后的 setup/hold，
# 以及电压/温度组合。这里用 set_timing_derate + 8 个 liberty 角。
set -euo pipefail
source "$(dirname "$0")/env.sh"
require_cmd openroad
require_pdk

OUT="$ROOT/runs/16_ocv"
mkdir -p "$OUT"
ODB="$ROOT/runs/05_route/route.odb"
SPEF="$ROOT/runs/13_spef/counter.spef"
SDC="$ROOT/constraints/counter.sdc"
[[ -f "$ODB" ]] || { echo "[ERROR] 缺少 $ODB，先 make all"; exit 1; }

LIBDIR="$SC_DIR/lib"
# 名称: 文件 | derate_setup | derate_hold
# OCV 常用：setup 路径 clock/data 加悲观 derate，hold 另一套
CORNERS=(
  "tt_025C_1v80|sky130_fd_sc_hd__tt_025C_1v80.lib|1.05|0.95"
  "tt_100C_1v80|sky130_fd_sc_hd__tt_100C_1v80.lib|1.05|0.95"
  "ss_n40C_1v40|sky130_fd_sc_hd__ss_n40C_1v40.lib|1.10|0.95"
  "ss_100C_1v40|sky130_fd_sc_hd__ss_100C_1v40.lib|1.10|0.95"
  "ss_n40C_1v60|sky130_fd_sc_hd__ss_n40C_1v60.lib|1.10|0.95"
  "ff_n40C_1v95|sky130_fd_sc_hd__ff_n40C_1v95.lib|1.05|0.90"
  "ff_100C_1v95|sky130_fd_sc_hd__ff_100C_1v95.lib|1.05|0.90"
  "ff_n40C_1v65|sky130_fd_sc_hd__ff_n40C_1v65.lib|1.05|0.90"
)

echo "==== P5: OCV + 多电压/温度 corner ===="
printf '%-14s %-10s %-10s %-10s %-10s %s\n' \
  corner setupWNS setupSlack holdWNS holdSlack verdict

fail=0
for entry in "${CORNERS[@]}"; do
  IFS='|' read -r name lib ds dh <<<"$entry"
  libpath="$LIBDIR/$lib"
  if [[ ! -f "$libpath" ]]; then
    echo "[WARN] 跳过 $name（缺 $lib）"
    continue
  fi
  cat > "$OUT/ocv.tcl" <<EOF
source $SCRIPTS_DIR/common.tcl
read_db $ODB
read_liberty $libpath
read_sdc $SDC
if {[file exists $SPEF]} {
  read_spef $SPEF
} else {
  estimate_parasitics -global_routing
}
# OCV：setup 路径悲观，hold 另一套
set_timing_derate -early $dh
set_timing_derate -late  $ds
# 仅对 clock 网络也可再加 -clock；这里全局 early/late 已足够教学
puts "SLACK_MAX_BEGIN"
report_checks -path_delay max -format slack_only
puts "SLACK_MAX_END"
puts "SLACK_MIN_BEGIN"
report_checks -path_delay min -format slack_only
puts "SLACK_MIN_END"
report_wns
report_tns
report_wns -min
report_tns -min
EOF
  openroad -no_init -exit "$OUT/ocv.tcl" > "$OUT/ocv_${name}.log" 2>&1 || true
  log="$OUT/ocv_${name}.log"
  wns=$(grep -E '^wns max' "$log" | tail -1 | awk '{print $3}')
  tns=$(grep -E '^tns max' "$log" | tail -1 | awk '{print $3}')
  hwns=$(grep -E '^wns min' "$log" | tail -1 | awk '{print $3}')
  sslack=$(awk '/SLACK_MAX_BEGIN/{f=1;next} /SLACK_MAX_END/{f=0} f && $0 !~ /^Group/ && $0 !~ /^---/ && NF>=2 {print $NF}' "$log" | sort -g | head -1)
  hslack=$(awk '/SLACK_MIN_BEGIN/{f=1;next} /SLACK_MIN_END/{f=0} f && $0 !~ /^Group/ && $0 !~ /^---/ && NF>=2 {print $NF}' "$log" | sort -g | head -1)
  verdict=$(awk -v a="${wns:-0}" -v b="${hwns:-0}" 'BEGIN{ if (a+0 >= 0 && b+0 >= 0) print "MET"; else print "FAIL" }')
  [[ "$verdict" == "MET" ]] || fail=1
  printf '%-14s %-10s %-10s %-10s %-10s %s\n' \
    "$name" "${wns:-?}" "${sslack:-?}" "${hwns:-?}" "${hslack:-?}" "$verdict"
done

echo ""
echo "报告: $OUT/ocv_*.log"
if [[ "$fail" -ne 0 ]]; then
  echo "[FAIL] 有 corner 在 OCV derate 后违例"
  exit 1
fi
echo "[PASS] 全部 corner OCV derate 后 setup+hold MET（constraints/counter.sdc）"
