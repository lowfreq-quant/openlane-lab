#!/usr/bin/env bash
# 功能仿真：RTL 级 + 门级（综合后网表）
# 不需要 PDK：门级用的是 sim/sky130_hd_min.v 里手写的 10 个单元功能模型
set -euo pipefail
source "$(dirname "$0")/env.sh"

cd "$ROOT"
mkdir -p sim/out
require_cmd iverilog "sudo apt install iverilog"

echo "=== 1) RTL 功能仿真 ==="
iverilog -g2012 -o sim/out/tb_rtl sim/counter_tb.v rtl/counter.v
vvp sim/out/tb_rtl | tee sim/out/rtl_sim.log
grep -q '^PASS' sim/out/rtl_sim.log || { echo "[ERROR] RTL 仿真未通过" >&2; exit 1; }

echo ""
echo "=== 2) 门级仿真（综合网表 + sky130 行为模型）==="
if [[ ! -f runs/01_synth/counter_synth.v ]]; then
  echo "[ERROR] 缺少 runs/01_synth/counter_synth.v，请先跑 01_synth.sh" >&2
  exit 1
fi
iverilog -g2012 -o sim/out/tb_gate \
  sim/counter_tb.v \
  runs/01_synth/counter_synth.v \
  sim/sky130_hd_min.v
vvp sim/out/tb_gate | tee sim/out/gate_sim.log
grep -q '^PASS' sim/out/gate_sim.log || { echo "[ERROR] 门级仿真未通过" >&2; exit 1; }

echo ""
echo "[DONE] RTL 与门级仿真均 PASS（各 256+ 步）"
