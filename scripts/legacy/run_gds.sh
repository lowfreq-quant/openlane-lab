#!/usr/bin/env bash
# 【历史存档，预期失败】OpenROAD 直接由 DEF 写 GDS
#
# OpenROAD 26Q2 没有 write_gds / read_gds：下面这段会报
#   invalid command name "read_gds"
#   invalid command name "write_gds"
# 所以这个脚本现在只用来复现「为什么不能这么做」。
# 现行路径：bash scripts/run_gds_drc.sh（KLayout 合成）
set -euo pipefail
source "$(dirname "$0")/../env.sh"

export OUT="$ROOT/runs/09_gds"
mkdir -p "$OUT"

echo "[legacy] 预期失败：OpenROAD 26Q2 没有 write_gds" >&2
openroad -no_init -exit <<'EOF'
read_lef $::env(MERGED_LEF)
read_liberty $::env(SC_LIB)
if {[catch {read_gds [file join $::env(PDK_PATH) libs.ref sky130_fd_sc_hd gds sky130_fd_sc_hd.gds]} err]} {
  puts "read_gds not available: $err"
}
read_def $::env(ROOT)/runs/05_route/route.def
if {[catch {write_gds $::env(OUT)/counter.gds} err]} {
  puts "write_gds not available: $err"
  exit 1
}
EOF
