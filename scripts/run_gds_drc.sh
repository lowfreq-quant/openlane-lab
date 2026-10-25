#!/usr/bin/env bash
# run_gds_drc.sh — DEF → GDS（KLayout）+ sky130 DRC
#
# 为什么不用 OpenROAD 写 GDS：26Q2 没有 write_gds 命令（见 HANDOFF 坑列表）。
# 产物：runs/09_gds/counter.gds、runs/09_gds/drc.lyrdb
set -euo pipefail
source "$(dirname "$0")/env.sh"

OUT="$ROOT/runs/09_gds"
mkdir -p "$OUT"
require_cmd klayout "sudo apt install klayout"
require_pdk

if [[ ! -f "$ROOT/runs/05_route/route.def" ]]; then
  echo "[ERROR] 缺少 runs/05_route/route.def，请先跑 05_route.sh" >&2
  exit 1
fi
if [[ ! -f "$MERGED_LEF" ]]; then
  echo "[ERROR] 缺少合并 LEF，先跑 bash scripts/merge_lef.sh" >&2
  exit 1
fi

echo "=== 1) KLayout 合成 GDS（单元几何 + DEF 摆放）==="
ROOT="$ROOT" PDK_ROOT="$PDK_ROOT" PDK="$PDK" MERGED_LEF="$MERGED_LEF" \
  klayout -b -r "$ROOT/scripts/make_gds.py" 2>&1 | tee "$OUT/klayout_gds.log"

if [[ ! -s "$OUT/counter.gds" ]]; then
  echo "[ERROR] GDS 未生成，见 $OUT/klayout_gds.log" >&2
  exit 1
fi
# 层映射失效时 GDS 里会没有 met1/met2 绕线，DRC 会假装 0 违例——必须拦住
if grep -q 'WARN' "$OUT/klayout_gds.log"; then
  echo "[ERROR] GDS 层映射有问题：" >&2
  grep 'WARN' "$OUT/klayout_gds.log" >&2
  exit 1
fi

echo ""
echo "=== 2) KLayout DRC（sky130A.lydrc，166 类规则）==="
klayout -b \
  -r "$PDK_PATH/libs.tech/klayout/sky130A.lydrc" \
  -rd input="$OUT/counter.gds" \
  -rd report="$OUT/drc.lyrdb" \
  -rd top=counter \
  2>&1 | tee "$OUT/klayout_drc.log" | tail -20

echo ""
viol=$(grep -c '<item>' "$OUT/drc.lyrdb" 2>/dev/null || true)
cats=$(grep -c '<category>' "$OUT/drc.lyrdb" 2>/dev/null || true)
viol=${viol:-0}
cats=${cats:-0}
echo "[DRC] 规则类别: $cats   违例条目: $viol"
if [[ "$viol" != "0" ]]; then
  echo "[FAIL] DRC 有违例，见 $OUT/drc.lyrdb" >&2
  exit 1
fi
echo "[PASS] DRC 0 违例    GDS: $OUT/counter.gds"
