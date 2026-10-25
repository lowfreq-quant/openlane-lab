#!/usr/bin/env bash
# 【历史存档，预期失败】Magic：读整库单元 GDS + DEF，再写出 GDS
#
# 失败点：Magic 读 ~4 MB 的 sky130_fd_sc_hd.gds 时段错误退出
# （换成 Nix 的 magic 8.3.681 也一样）。
# 现行路径：KLayout（bash scripts/run_gds_drc.sh）
set -euo pipefail
source "$(dirname "$0")/../env.sh"

OUT="$ROOT/runs/09_gds"
mkdir -p "$OUT"
MAG_HOME="$SC_DIR/mag"

echo "[legacy] 预期失败：Magic 读整库 GDS 会段错误" >&2

cat > "$OUT/magic_gds.tcl" <<EOF
drc off
tech load $PDK_PATH/libs.tech/magic/sky130A.tech
path search +$MAG_HOME
gds readonly true
gds rescale false
gds read $SC_DIR/gds/sky130_fd_sc_hd.gds

def read $ROOT/runs/05_route/route.def
load counter
select top cell
expand
puts "CELLS_LOADED"
gds write $OUT/counter.gds
puts "GDS_OK"
quit -noprompt
EOF

magic -dnull -noconsole -rcfile "$PDK_PATH/libs.tech/magic/sky130A.magicrc" \
  "$OUT/magic_gds.tcl" > "$OUT/magic_gds.log" 2>&1 || true

tail -20 "$OUT/magic_gds.log"
