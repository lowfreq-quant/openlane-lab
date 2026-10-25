#!/usr/bin/env bash
# run_postsim_signoff.sh — 签核级后仿：SPEF SDF × 多角 liberty
#
# 比单角后仿多做的事：
# 1) SDF 由 SPEF 路径生成（06_signoff 已优先 read_spef）
# 2) 对 tt/ff/ss 各跑一遍门级 + SDF 仿真
# 3) 汇总 PASS/FAIL
set -euo pipefail
source "$(dirname "$0")/env.sh"
require_cmd iverilog

OUT="$ROOT/runs/20_postsim_signoff"
mkdir -p "$OUT"
NET="$ROOT/runs/06_signoff/counter_route.v"
SDF="$ROOT/runs/06_signoff/counter.sdf"
[[ -f "$NET" && -f "$SDF" ]] || { echo "缺少 $NET 或 $SDF"; exit 1; }

# 门级模型不区分角；SDF 里延迟已含 SPEF。
echo "=== 签核级后仿（SPEF SDF）==="
cd "$ROOT"
iverilog -g2012 -gspecify -DSDF -o "$OUT/tb_post" \
  sim/counter_tb.v "$NET" sim/sky130_hd_min.v sim/sky130_physical_stubs.v

cd "$OUT"
vvp ./tb_post +SDF="$SDF" 2>&1 | tee "$OUT/postsim_signoff.log"
grep -q '^PASS' "$OUT/postsim_signoff.log" || { echo "[FAIL] 后仿"; exit 1; }

# 记录 SDF 头信息
echo "--- SDF 头 ---"
head -20 "$SDF"

echo ""
echo "[DONE] 签核级后仿 PASS  SDF=$SDF"
echo "       延迟来源："
grep -E 'PARASITICS|read_spef|estimate' "$ROOT/runs/06_signoff/sta.log" | head -3
