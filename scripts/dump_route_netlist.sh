#!/usr/bin/env bash
# dump_route_netlist.sh — 导出布线后网表（含 CTS buffer / tap / fill），后仿用
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/06_signoff"
mkdir -p "$OUT"
require_cmd openroad "安装方式见 docs/tools.md"

if [[ ! -f "$ROOT/runs/05_route/route.odb" ]]; then
  echo "[ERROR] 缺少 runs/05_route/route.odb，请先跑 05_route.sh" >&2
  exit 1
fi

SCRIPTS_DIR="$SCRIPTS_DIR" MERGED_LEF="$MERGED_LEF" SC_LIB="$SC_LIB" \
RT_ODB="$ROOT/runs/05_route/route.odb" OUT="$OUT" \
openroad -no_init -exit <<'EOF'
read_lef $::env(MERGED_LEF)
read_liberty $::env(SC_LIB)
read_db $::env(RT_ODB)
write_verilog $::env(OUT)/counter_route.v
puts "ROUTE_NETLIST_OK"
EOF

n=$(grep -cE 'sky130_fd_sc_hd__' "$OUT/counter_route.v" || true)
echo "[DONE] $OUT/counter_route.v  实例行: $n"
