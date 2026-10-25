#!/usr/bin/env bash
# probe_p6_topo.sh — P6：定位晶体管 LVS 拓扑残差
# 从 CDL 取 xnor2_1 / isobufsrc / dfrtp_1 的晶体管，与 GDS 提取对比
set -euo pipefail
source "$(dirname "$0")/env.sh"
OUT="$ROOT/runs/17_lvs_device"
CDL="$SC_DIR/cdl/sky130_fd_sc_hd.cdl"

echo "=== 1) CDL 中 xnor2_1 晶体管 ==="
python3 - <<'PY'
from pathlib import Path
import re
cdl = Path("/home/user/.volare/sky130A/libs.ref/sky130_fd_sc_hd/cdl/sky130_fd_sc_hd.cdl").read_text()
# 提取 .SUBCKT xxx ... 直到 .ENDS
for cell in ["sky130_fd_sc_hd__xnor2_1", "sky130_fd_sc_hd__lpflow_isobufsrc_1", "sky130_fd_sc_hd__dfrtp_1"]:
    m = re.search(rf'\.SUBCKT\s+{re.escape(cell)}\s+(.+?)\n(.*?)\.ENDS', cdl, re.I|re.S)
    if not m:
        print(f"NO CDL for {cell}"); continue
    pins = m.group(1).split()
    body = m.group(2)
    print(f"\n----- {cell} pins={pins} -----")
    for line in body.splitlines():
        s=line.strip()
        if s and not s.startswith('*'):
            print(s)
PY

echo ""
echo "=== 2) 提取网表里 tick 路径相关晶体管 ==="
# tick 由 isobufsrc 驱动；看提取侧 a_7553_3311# 与 tick
grep -E 'tick|X_uq0|nmid|_22_' "$OUT/counter_dev_ext_fix.spice" | head -30

echo ""
echo "=== 3) golden 里 tick 相关 ==="
grep -E 'tick|xnor|isobuf' "$OUT/counter_golden_dev.spice" | head -20

echo ""
echo "=== 4) netgen 对 tick / X_uq0 的 fragment ==="
grep -n -A6 'Net: tick\|Net: X_uq0\|nmid' "$OUT/lvs_dev.out" | head -40
