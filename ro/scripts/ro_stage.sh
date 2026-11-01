#!/bin/bash
# 延迟分解: 每级延迟 + 提取参数对比
source ~/.bashrc >/dev/null 2>&1
RO=~/asic_ro
cd $RO || exit 1

echo "=== 优化版器件参数 (ad/as 面积) ==="
grep -E '^X[0-9]+ ' ro_opt.spice | head -4
echo
echo "=== 寄生电容全表 (fF) ==="
grep -E '^C[0-9]+ ' ro_opt.spice
echo
python3 - <<'PYEOF'
import re
caps = re.findall(r'^C(\d+)\s+(\S+)\s+(\S+)\s+([0-9.]+)f', open('ro_opt.spice').read(), re.M)
total = sum(float(c[3]) for c in caps)
print(f'寄生电容总数 {len(caps)}, 合计 {total:.3f} fF')
# 按节点统计对地+耦合
from collections import defaultdict
load = defaultdict(float)
for _, a, b, v in caps:
    va = float(v)
    load[a] += va/2; load[b] += va/2
for n, v in sorted(load.items(), key=lambda x:-x[1]):
    print(f'  节点 {n}: 等效负载 {v:.3f} fF')
PYEOF

echo
echo "=== 每级延迟测量 ==="
python3 - <<'PYEOF'
import re
from collections import defaultdict
txt = open('ro_opt.spice').read()
devs = re.findall(r'^X(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+sky130_fd_pr__(n|p)fet_01v8', txt, re.M)
drives = {}
for n, d, g, s, b, tp in devs:
    drives[d] = g
# 环序: 从 out 往回数
ring = []
cur = 'out'
while cur not in ring:
    ring.append(cur)
    cur = drives[cur]
ring = list(reversed(ring))  # ring[k] 的输出驱动 ring 的下一级
lines = []
for k, node in enumerate(ring):
    lines.append(f'meas tran td{k} when v({node})=0.9 fall=1')
open('/home/user/asic_ro/stages.txt','w').write('\n'.join(lines))
print('环序:', ' -> '.join(ring))
PYEOF
sed -E 's/\*\*FLOATING//g; s/^\.end.*$//' ro_opt.spice > ro_stage.spice
STAGES=$(cat stages.txt)
cat >> ro_stage.spice <<EOF
vvss vgnd 0 dc 0
vvcc vpwr 0 pwl 0 0 1n 0 1.05n 1.8 200n 1.8
.lib /home/user/.volare/sky130A/libs.tech/ngspice/sky130.lib.spice tt
.control
save all
tran 0.05n 200n
${STAGES}
.endc
.end
EOF
timeout 300 ngspice -b ro_stage.spice > stages.log 2>&1
grep -E "^td" stages.log
python3 - <<'PYEOF'
import re
vals = {}
for L in open('stages.log', errors='replace'):
    m = re.match(r'(td\d)\s*=\s*([0-9.eE+-]+)', L.strip())
    if m: vals[m.group(1)] = float(m.group(2))
for L in open('postsim2.log', errors='replace'):
    m = re.search(r't1\s*=\s*([0-9.eE+-]+)', L)
    if m: T1 = float(m.group(1))
    m = re.search(r't2\s*=\s*([0-9.eE+-]+)', L)
    if m: T2 = float(m.group(1))
if len(vals) == 7 and (T2 - T1) > 0:
    T = (T2 - T1) / 3  # 3 个周期
    ts = [vals[f'td{k}'] for k in range(7)]
    print('每级延迟:')
    for k in range(7):
        a = ts[k]
        b = ts[(k + 1) % 7]
        if b < a: b += T * 2  # 14τ = T... 相邻翻转差一级
        d = (b - a) * 1e9
        print(f'  级 {k}→{(k+1)%7}: {d*1000:.1f} ps')
    print(f'前仿单级 ~105.8 ps, 环周期 {T*1e9:.4f} ns')
PYEOF
