#!/usr/bin/env bash
# run_postsim.sh — 后仿：布线后网表 + SDF（估算寄生）做门级时序仿真
#
# 前置：
#   bash scripts/05_route.sh          # 布线 + 填充
#   bash scripts/06_signoff.sh        # 生成 runs/06_signoff/counter.sdf
#   bash scripts/dump_route_netlist.sh
#
# 说明：sky130 的 PDK 不带 OpenRCX 模型，SDF 里的连线延迟来自
# `estimate_parasitics -global_routing` 的估算，不是 3D 提取（见 README 局限）。
set -euo pipefail
source "$(dirname "$0")/env.sh"

cd "$ROOT"
OUT="$ROOT/runs/12_postsim"
mkdir -p "$OUT"
require_cmd iverilog "sudo apt install iverilog"

NET="$ROOT/runs/06_signoff/counter_route.v"
SDF="$ROOT/runs/06_signoff/counter.sdf"
for f in "$NET" "$SDF"; do
  [[ -f "$f" ]] || { echo "[ERROR] 缺少 $f，先跑 06_signoff.sh 和 dump_route_netlist.sh" >&2; exit 1; }
done

echo "=== 编译（布线后网表 + 物理单元桩 + 功能模型）==="
iverilog -g2012 -gspecify -DSDF -o "$OUT/tb_postsim" \
  sim/counter_tb.v \
  "$NET" \
  sim/sky130_hd_min.v \
  sim/sky130_physical_stubs.v

echo "=== 跑 SDF 后仿 ==="
cd "$OUT"
vvp ./tb_postsim +SDF="$SDF" 2>&1 | tee "$OUT/postsim.log"
grep -q '^PASS' "$OUT/postsim.log" || { echo "[ERROR] 后仿未通过" >&2; exit 1; }

hits=$(grep -c 'SDF annotate' "$OUT/postsim.log" || true)
echo "[DONE] 后仿 PASS（SDF: $SDF，日志: $OUT/postsim.log）"
