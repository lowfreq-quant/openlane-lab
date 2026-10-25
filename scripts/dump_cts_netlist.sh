#!/usr/bin/env bash
# dump_cts_netlist.sh — 导出 post-CTS 网表，作为 LVS 金标准
#
# 为什么不用综合网表：CTS 会插时钟 buffer，综合网表和版图实例数对不上。
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/10_lvs"
mkdir -p "$OUT"
require_cmd openroad "安装方式见 docs/tools.md"
require_pdk

if [[ ! -f "$ROOT/runs/04_cts/cts.odb" ]]; then
  echo "[ERROR] 缺少 runs/04_cts/cts.odb，请先跑 04_cts.sh" >&2
  exit 1
fi

SCRIPTS_DIR="$SCRIPTS_DIR" MERGED_LEF="$MERGED_LEF" SC_LIB="$SC_LIB" \
CTS_ODB="$ROOT/runs/04_cts/cts.odb" OUT="$OUT" \
openroad -no_init -exit <<'EOF'
read_lef $::env(MERGED_LEF)
read_liberty $::env(SC_LIB)
read_db $::env(CTS_ODB)
write_verilog $::env(OUT)/counter_cts.v
puts "CTS_NETLIST_OK"
EOF

n=$(grep -cE 'sky130_fd_sc_hd__' "$OUT/counter_cts.v" || true)
echo "[DONE] $OUT/counter_cts.v  单元实例行: $n"
