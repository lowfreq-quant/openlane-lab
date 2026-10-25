#!/usr/bin/env bash
# 形式等价：RTL (gold) vs 综合网表 (gate)，yosys equiv_make / equiv_simple / equiv_induct
set -euo pipefail
source "$(dirname "$0")/env.sh"

cd "$ROOT"
OUT="$ROOT/runs/07_equiv"
mkdir -p "$OUT"
require_cmd yosys "sudo apt install yosys"

if [[ ! -f "$ROOT/runs/01_synth/counter_synth.v" ]]; then
  echo "[ERROR] 缺少 runs/01_synth/counter_synth.v，请先跑 01_synth.sh" >&2
  exit 1
fi

# 用 sim/sky130_hd_min.v 展开 sky130 单元，否则 SAT 里是黑盒
# 异步复位要 async2sync，否则 $adff 证不动
yosys -p "
  read_verilog -DFUNCTIONAL $ROOT/sim/sky130_hd_min.v;
  read_verilog $ROOT/rtl/counter.v;
  prep -top counter -flatten;
  async2sync;
  opt_clean;
  design -stash gold;

  read_verilog -DFUNCTIONAL $ROOT/sim/sky130_hd_min.v;
  read_verilog $ROOT/runs/01_synth/counter_synth.v;
  prep -top counter -flatten;
  async2sync;
  opt_clean;
  design -stash gate;

  design -copy-from gold -as gold counter;
  design -copy-from gate -as gate counter;

  equiv_make gold gate equiv;
  hierarchy -top equiv;
  equiv_simple -seq 3;
  equiv_induct -seq 3;
  equiv_status -assert;
" 2>&1 | tee "$OUT/equiv.log" | tail -40

echo ""
echo "=== 等价结论 ==="
grep -E 'Proven|Unproven|Equivalence' "$OUT/equiv.log" | tail -10
grep -q 'Equivalence successfully proven' "$OUT/equiv.log" || {
  echo "[ERROR] 等价未证明" >&2; exit 1;
}
