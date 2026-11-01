#!/bin/bash
# 环振后段: 拓扑校验 + 后仿 + 前后对比 + LVS
source ~/.bashrc >/dev/null 2>&1
PDKA=$PDK_ROOT/sky130A
RO=~/asic_ro
cd $RO || exit 1

echo "=== 1. 拓扑环校验 ==="
python3 - <<'PYEOF'
import re
from collections import defaultdict
txt = open('/home/user/asic_ro/ro_layout.spice').read()
devs = re.findall(r'^X(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+sky130_fd_pr__(n|p)fet_01v8', txt, re.M)
print(f'器件数: {len(devs)} (期望14)')
drives = defaultdict(list)
for n, d, g, s, b, tp in devs:
    expect = 'vgnd' if tp == 'n' else 'vpwr'
    assert s == b == expect, f'X{n} 源/衬底异常: {s} {b} (期望 {expect})'
    drives[d].append((g, tp))
bad = 0
for net, lst in sorted(drives.items()):
    tps = sorted(t for _, t in lst)
    gs = set(g for g, _ in lst)
    ok = tps == ['n', 'p'] and len(gs) == 1
    if not ok: bad += 1
    print(f'  {net}: {"OK" if ok else "BAD"} 驱动={[t for _,t in lst]} 输入={list(gs)}')
seen = []
cur = 'out'
while cur not in seen:
    seen.append(cur)
    cur = drives[cur][0][0]
print(f'环长度: {len(seen)} {"[OK] 7 级闭环" if len(seen)==7 and bad==0 else "[!!] 检查"}')
PYEOF

echo
echo "=== 2. 后仿 (含寄生) ==="
sed -E 's/\*\*FLOATING//g; s/^\.end.*$//' ro_layout.spice > ro_post.spice
cat >> ro_post.spice <<'EOF'
vvss vgnd 0 dc 0
vvcc vpwr 0 pwl 0 0 1n 0 1.05n 1.8 200n 1.8
.lib /home/user/.volare/sky130A/libs.tech/ngspice/sky130.lib.spice tt
.control
save all
tran 0.05n 200n
meas tran t1 when v(out)=0.9 rise=4
meas tran t2 when v(out)=0.9 rise=10
write ro_post.raw
.endc
.end
EOF
timeout 300 ngspice -b ro_post.spice > postsim.log 2>&1
grep -E "t1|t2|Error|error" postsim.log | head -5
T1=$(grep -oP 't1\s*=\s*\K[0-9.e+-]+' postsim.log | head -1)
T2=$(grep -oP 't2\s*=\s*\K[0-9.e+-]+' postsim.log | head -1)
ls -la ro_post.raw 2>/dev/null

echo
echo "=== 3. 前后仿对比 ==="
PRE_T1=$(grep -oP 't1\s*=\s*\K[0-9.e+-]+' presim.log 2>/dev/null | head -1)
PRE_T2=$(grep -oP 't2\s*=\s*\K[0-9.e+-]+' presim.log 2>/dev/null | head -1)
if [ -n "$T1" ] && [ -n "$T2" ] && [ -n "$PRE_T1" ] && [ -n "$PRE_T2" ]; then
python3 - <<PYEOF
f_pre  = 3/($PRE_T2-$PRE_T1)*1e9
f_post = 3/($T2-$T1)*1e9
print(f'前仿 f_pre  = {f_pre:,.1f} MHz  (原理图级)')
print(f'后仿 f_post = {f_post:,.1f} MHz  (含版图寄生)')
print(f'寄生使频率下降 {(1-f_post/f_pre)*100:.2f}%')
PYEOF
else
  echo "[!] 缺少测量值: pre=($PRE_T1,$PRE_T2) post=($T1,$T2)"
fi

echo
echo "=== 4. netgen LVS ==="
cat > ro_schem.spice <<'EOF'
* 7-stage ring oscillator - schematic (flat, from xschem netlist)
.subckt ro out vpwr vgnd
xm1n n1 out vgnd vgnd sky130_fd_pr__nfet_01v8 w=1 l=0.15
xm1p n1 out vpwr vpwr sky130_fd_pr__pfet_01v8 w=2 l=0.15
xm2n n2 n1 vgnd vgnd sky130_fd_pr__nfet_01v8 w=1 l=0.15
xm2p n2 n1 vpwr vpwr sky130_fd_pr__pfet_01v8 w=2 l=0.15
xm3n n3 n2 vgnd vgnd sky130_fd_pr__nfet_01v8 w=1 l=0.15
xm3p n3 n2 vpwr vpwr sky130_fd_pr__pfet_01v8 w=2 l=0.15
xm4n n4 n3 vgnd vgnd sky130_fd_pr__nfet_01v8 w=1 l=0.15
xm4p n4 n3 vpwr vpwr sky130_fd_pr__pfet_01v8 w=2 l=0.15
xm5n n5 n4 vgnd vgnd sky130_fd_pr__nfet_01v8 w=1 l=0.15
xm5p n5 n4 vpwr vpwr sky130_fd_pr__pfet_01v8 w=2 l=0.15
xm6n n6 n5 vgnd vgnd sky130_fd_pr__nfet_01v8 w=1 l=0.15
xm6p n6 n5 vpwr vpwr sky130_fd_pr__pfet_01v8 w=2 l=0.15
xm7n out n6 vgnd vgnd sky130_fd_pr__nfet_01v8 w=1 l=0.15
xm7p out n6 vpwr vpwr sky130_fd_pr__pfet_01v8 w=2 l=0.15
.ends ro
EOF
{ echo '.subckt ro out vpwr vgnd'; sed -E 's/\*\*FLOATING//g; s/^\.end.*$//' ro_layout.spice; echo '.ends ro'; } > ro_ext_lvs.spice
export NETGENDIR="$(dirname "$(find /usr -name ng.tcl 2>/dev/null | head -1)")"
echo "NETGENDIR=$NETGENDIR"
timeout 120 netgen -batch lvs "ro_ext_lvs.spice ro" "ro_schem.spice ro" \
  "$PDKA/libs.tech/netgen/sky130A_setup.tcl" > ro_lvs.log 2>&1
tail -3 ro_lvs.log
echo "--- 结论行 ---"
grep -E "Netlists match|match|Correct|property" ro_lvs.log | tail -6
