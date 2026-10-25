#!/usr/bin/env bash
# run_rc_corners.sh — 多 RC corner：用 set_layer_rc 缩放后提取 SPEF + STA
#
# OpenRCX 模型只有一套；用 set_layer_rc 的 -corner 或 res/cap 缩放做 RC 情景。
set -euo pipefail
source "$(dirname "$0")/env.sh"
require_cmd openroad
require_pdk

OUT="$ROOT/runs/19_rc_corners"
mkdir -p "$OUT"
ODB="$ROOT/runs/05_route/route.odb"
SDC="$ROOT/constraints/counter_complex.sdc"
[[ -f "$ODB" ]] || { echo "缺少 route.odb"; exit 1; }
[[ -f "$SDC" ]] || SDC="$ROOT/constraints/counter.sdc"
RCX="$PDK_PATH/libs.tech/openlane/rcx_rules.info"

# RC 情景：名义 / 电容+ / 电阻+
# name | cap_scale | res_scale
SCENARIOS=(
  "rc_nom|1.0|1.0"
  "rc_cmax|1.3|1.0"
  "rc_rmax|1.0|1.3"
  "rc_rcmax|1.3|1.3"
  "rc_cmin|0.7|0.7"
)

echo "==== 多 RC corner SPEF + STA（复杂 SDC）===="
printf '%-10s %-10s %-10s %s\n' scenario wns_setup verdict spef

for s in "${SCENARIOS[@]}"; do
  IFS='|' read -r name cs rs <<<"$s"
  cat > "$OUT/rc.tcl" <<EOF
source $SCRIPTS_DIR/common.tcl
read_db $ODB
read_sdc $SDC
# 粗粒度 RC 缩放：按 sky130 典型量级 × scale（教学近似）
# 覆盖 extract 用的层电阻；via 沿用 5Ω 假设
foreach lay {li1 met1 met2 met3 met4 met5} {
  set r0 0.125
  set c0 0.0002
  catch {set_layer_rc -layer \$lay -resistance [expr {\$r0 * $rs}] -capacitance [expr {\$c0 * $cs}]}
}
foreach v {via via2 via3 via4} {
  catch {set_layer_rc -via \$v -resistance [expr {5.0 * $rs}]}
}
# OpenRCX 提取（会读 rcx_rules；层 RC 命令作补充）
extract_parasitics -ext_model_file $RCX
write_spef $OUT/${name}.spef
read_spef $OUT/${name}.spef
report_wns
report_wns -min
puts "SCENARIO $name cap=$cs res=$rs"
EOF
  openroad -no_init -exit "$OUT/rc.tcl" > "$OUT/${name}.log" 2>&1 || true
  wns=$(grep -E '^wns max' "$OUT/${name}.log" | tail -1 | awk '{print $3}' || echo "?")
  v="MET"
  if [[ "${wns}" == "?" ]]; then v="ERR"; else
    v=$(awk -v a="$wns" 'BEGIN{print (a+0>=0)?"MET":"VIOL"}')
  fi
  printf '%-10s %-10s %-10s %s\n' "$name" "$wns" "$v" "$OUT/${name}.spef"
done

echo ""
echo "说明：OpenROAD 单 RCX 模型下 cap/res 缩放为近似；见 log 中 extract 信息。"
ls -la "$OUT"/*.spef 2>/dev/null | head
