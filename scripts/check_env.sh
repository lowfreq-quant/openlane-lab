#!/usr/bin/env bash
# check_env.sh — 环境自检：工具在不在、PDK 全不全、合并 LEF 有没有
# 有问题只提示，不中断，方便一次看清全部缺失
source "$(dirname "$0")/env.sh"

echo "=== 工具 ==="
for t in yosys iverilog openroad magic klayout netgen-lvs volare python3; do
  if command -v "$t" >/dev/null 2>&1; then
    printf '%-12s %s\n' "$t" "$(command -v "$t")"
  else
    printf '%-12s MISSING\n' "$t"
  fi
done

echo ""
echo "=== PDK ==="
echo "PDK_ROOT=$PDK_ROOT"
echo "PDK_PATH=$PDK_PATH"
for f in \
  "$SC_DIR/techlef/sky130_fd_sc_hd.tlef" \
  "$SC_DIR/lef/sky130_fd_sc_hd.lef" \
  "$SC_LIB" \
  "$SC_CDL" \
  "$SC_DIR/gds/sky130_fd_sc_hd.gds" \
  "$PDK_PATH/libs.tech/klayout/sky130A.lydrc" \
  "$PDK_PATH/libs.tech/netgen/sky130A_setup.tcl" \
  "$PDK_PATH/libs.tech/magic/sky130A.tech" ; do
  [[ -f "$f" ]] && echo "  OK   $f" || echo "  MISS $f"
done

echo ""
echo "=== 工程产物 ==="
for f in \
  "$MERGED_LEF" \
  "$ROOT/runs/01_synth/counter_synth.v" \
  "$ROOT/runs/05_route/route.def" \
  "$ROOT/runs/09_gds/counter.gds" ; do
  [[ -f "$f" ]] && echo "  OK   $f" || echo "  MISS $f"
done

echo ""
echo "=== 版本 ==="
yosys -V 2>/dev/null | head -1
iverilog -V 2>/dev/null | head -1
klayout -v 2>/dev/null | head -1
openroad -version 2>/dev/null | head -1
volare --version 2>/dev/null | head -1
