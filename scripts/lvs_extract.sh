#!/usr/bin/env bash
# lvs_extract.sh — 版图侧：Magic 读 DEF + 合并 LEF，做单元级提取
#
# 这一步是 LEF 抽象级提取：保留标准单元实例，不展开晶体管。
# 所以它验证的是「布局布线后的连接关系 + 单元类型」，不是器件级版图一致性。
# 产物：runs/10_lvs/counter_ext_cell.spice
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/10_lvs"
DEF="$ROOT/runs/05_route/route.def"
mkdir -p "$OUT"
require_cmd magic "见 docs/tools.md（Nix: nixpkgs.magic-vlsi）"
require_pdk

if [[ ! -f "$MERGED_LEF" ]]; then
  echo "[ERROR] 缺少合并 LEF，先跑 bash scripts/merge_lef.sh" >&2
  exit 1
fi
if [[ ! -f "$DEF" ]]; then
  echo "[ERROR] 缺少 $DEF，先跑 05_route.sh" >&2
  exit 1
fi

cat > "$OUT/extract_cell.tcl" <<EOF
drc off
tech load $PDK_PATH/libs.tech/magic/sky130A.tech
# 单元用 LEF 抽象，不展开晶体管
lef read $MERGED_LEF
def read $DEF
load counter
select top cell
# 层次化提取：保持单元实例
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique
extract do local
extract all
ext2spice lvs
ext2spice -o $OUT/counter_ext_cell.spice
quit -noprompt
EOF

magic -dnull -noconsole -rcfile "$PDK_PATH/libs.tech/magic/sky130A.magicrc" \
  "$OUT/extract_cell.tcl" > "$OUT/magic_extract_cell.log" 2>&1 || true
tail -15 "$OUT/magic_extract_cell.log"

if [[ ! -s "$OUT/counter_ext_cell.spice" ]]; then
  echo "[ERROR] 提取失败，见 $OUT/magic_extract_cell.log" >&2
  exit 1
fi
echo "--- 提取网表前 15 行 ---"
head -15 "$OUT/counter_ext_cell.spice"
echo "[DONE] $OUT/counter_ext_cell.spice"
