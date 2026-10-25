#!/usr/bin/env bash
# 01 逻辑综合：RTL → 门级网表（yosys）
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/01_synth"
mkdir -p "$OUT"
require_cmd yosys "sudo apt install yosys"

# 没有 PDK 时退化成 generic 综合：流程仍可走通，只是不映射到 sky130 单元
if [[ ! -f "$SC_LIB" ]]; then
  echo "[WARN] 找不到 liberty: $SC_LIB"
  echo "       先跑 bash scripts/fetch_pdk.sh；本轮退化为 generic 综合。"
  yosys -p "
    read_verilog $ROOT/rtl/counter.v;
    hierarchy -top counter;
    proc; opt; fsm; opt; memory; opt;
    techmap; opt;
    stat;
    write_verilog -noattr $OUT/counter_synth.v;
  " | tee "$OUT/yosys.log"
  echo "[DONE] 网表: $OUT/counter_synth.v（generic）"
  exit 0
fi

yosys -p "
  read_verilog $ROOT/rtl/counter.v;
  hierarchy -top counter;
  proc; opt; fsm; opt; memory; opt;
  techmap; opt;
  dfflibmap -liberty $SC_LIB;
  abc -liberty $SC_LIB -D 100000;
  opt_clean;
  stat -liberty $SC_LIB;
  write_verilog -noattr $OUT/counter_synth.v;
" | tee "$OUT/yosys.log"

echo "[DONE] 网表: $OUT/counter_synth.v"
echo "       查看统计: grep -A2 'Number of cells' $OUT/yosys.log"
