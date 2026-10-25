#!/usr/bin/env bash
# 变异测试：往设计里注入 bug，testbench 必须抓到
# 有任何一个没抓到 → 说明测试无效，脚本返回非 0
set -euo pipefail
source "$(dirname "$0")/env.sh"

cd "$ROOT"
mkdir -p sim/out
require_cmd iverilog "sudo apt install iverilog"

run_case() {
  local name="$1" def="$2" expect="$3"   # expect: PASS | FAIL
  echo "=== mutation: $name ($def) expect=$expect ==="
  if [[ -z "$def" ]]; then
    iverilog -g2012 -o "sim/out/tb_$name" sim/counter_tb.v sim/counter_bug.v
  else
    iverilog -g2012 -D"$def" -o "sim/out/tb_$name" sim/counter_tb.v sim/counter_bug.v
  fi
  local out got=FAIL
  out=$(vvp "sim/out/tb_$name" 2>&1 | tail -3)
  echo "$out"
  echo "$out" | grep -q '^PASS' && got=PASS

  if [[ "$expect" == "PASS" && "$got" == "PASS" ]]; then
    echo "RESULT: $name -> 正确设计通过" | tee -a sim/out/mutation_summary.txt
  elif [[ "$expect" == "FAIL" && "$got" == "FAIL" ]]; then
    echo "RESULT: $name -> testbench 抓到 bug" | tee -a sim/out/mutation_summary.txt
  elif [[ "$expect" == "PASS" ]]; then
    echo "RESULT: $name -> 正确设计竟 FAIL（有问题）" | tee -a sim/out/mutation_summary.txt
  else
    echo "RESULT: $name -> 未抓到 bug（测试无效！）" | tee -a sim/out/mutation_summary.txt
  fi
  echo ""
}

rm -f sim/out/mutation_summary.txt

run_case "correct"   ""          "PASS"
run_case "bug_reset" "BUG_RESET" "FAIL"
run_case "bug_step"  "BUG_STEP"  "FAIL"
run_case "bug_tick"  "BUG_TICK"  "FAIL"

echo "======== 汇总 ========"
cat sim/out/mutation_summary.txt

if grep -qE '有问题|测试无效' sim/out/mutation_summary.txt; then
  echo "[ERROR] 变异测试未全部符合预期" >&2
  exit 1
fi
echo "[DONE] 4/4 符合预期（3 个 bug 全被抓到，对照通过）"
