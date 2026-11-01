#!/bin/bash
# LVS: nix netgen (LVS 版) 重跑
source ~/.bashrc >/dev/null 2>&1
PDKA=$PDK_ROOT/sky130A
RO=~/asic_ro
cd $RO || exit 1

NGDIR=/nix/store/dkz56a072q19x2vaqa9am4wnnn124qcn-netgen-1.5.323/lib/netgen/tcl
ls "$NGDIR" | head -5
export NETGENDIR="$NGDIR"

# 重建 LVS 输入: 剥寄生电容 (LVS 只比对连通性)
{ echo '.subckt ro out vpwr vgnd'; sed -E 's/\*\*FLOATING//g; /^C[0-9]+ /d; s/^\.end.*$//' ro_layout.spice; echo '.ends ro'; } > ro_ext_lvs.spice
grep -c '^X' ro_ext_lvs.spice | xargs echo "提取侧器件数:"

echo
echo "=== LVS: ro_ext_lvs.spice (版图提取) vs ro_schem.spice (原理图) ==="
NETBIN=$(readlink -f ~/.nix-profile/bin/netgen)
echo "netgen: $NETBIN"
timeout 180 "$NETBIN" -batch lvs "ro_ext_lvs.spice ro" "ro_schem.spice ro" \
  "$PDKA/libs.tech/netgen/sky130A_setup.tcl" > ro_lvs.log 2>&1
echo "exit: $?"
echo "--- 日志尾部 ---"
tail -6 ro_lvs.log
echo "--- 结论 ---"
grep -iE "netlists match|match|property|not match|error" ro_lvs.log | tail -8
