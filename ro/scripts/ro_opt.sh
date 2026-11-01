#!/bin/bash
# 环振版图优化轮: pitch 340 -> 240, 扩散/走线全面瘦身, mcon 垂直错位
source ~/.bashrc >/dev/null 2>&1
PDKA=$PDK_ROOT/sky130A
RO=~/asic_ro
cd $RO || exit 1

python3 > ro2.magic.tcl <<'PYEOF'
N = 7
PITCH = 240
E = N * PITCH  # 1680
for i in range(N):
    c = i * PITCH
    # 阱/扩散/栅: 源 x50..110, 栅 110..125, 漏 125..190 (最小扩散)
    print(f"box {c+0} 240 {c+240} 500"); print("paint nwell")
    print(f"box {c+70} 100 {c+175} 200"); print("paint ndiff")
    print(f"box {c+70} 280 {c+175} 480"); print("paint pdiff")
    print(f"box {c+110} 60 {c+125} 556"); print("paint poly")
    print(f"box {c+0} 505 {c+125} 556"); print("paint poly")   # IN blob (连栅)
    # IN: pc -> li1 -> mcon(水平错位) -> met1 pad
    print(f"box {c+20} 524 {c+40} 544"); print("paint pc")
    print(f"box {c+12} 514 {c+72} 554"); print("paint li1")
    print(f"box {c+44} 524 {c+64} 544"); print("paint mcon")
    print(f"box {c+8} 514 {c+76} 554"); print("paint met1")
    # NMOS 源 -> VGND (mcon 在 licon1 下方垂直错位)
    print(f"box {c+75} 135 {c+95} 155"); print("paint ndc")
    print(f"box {c+67} 92 {c+103} 188"); print("paint li1")
    print(f"box {c+75} 100 {c+95} 120"); print("paint mcon")
    print(f"box {c+60} 0 {c+110} 165"); print("paint met1")
    # NMOS 漏 + PMOS 漏 -> OUT 竖干 (met1 x125..175)
    print(f"box {c+150} 135 {c+170} 155"); print("paint ndc")
    print(f"box {c+142} 127 {c+178} 188"); print("paint li1")
    print(f"box {c+150} 160 {c+170} 180"); print("paint mcon")
    print(f"box {c+150} 285 {c+170} 305"); print("paint pdc")
    print(f"box {c+142} 242 {c+178} 313"); print("paint li1")
    print(f"box {c+150} 250 {c+170} 270"); print("paint mcon")
    print(f"box {c+125} 120 {c+175} 320"); print("paint met1")
    # OUT: met1 -> via1 -> met2 短垂直 -> 顶走线
    print(f"box {c+128} 150 {c+148} 170"); print("paint via1")
    print(f"box {c+128} 140 {c+148} 538"); print("paint met2")
    if i < N-1:
        print(f"box {c+128} 518 {c+320} 538"); print("paint met2")
        print(f"box {c+255} 524 {c+275} 544"); print("paint via1")  # 下到下级 IN pad
    else:
        print(f"box {c+128} 518 1760 538"); print("paint met2")
    # PMOS 源 -> VPWR (mcon 垂直错位在 licon1 上方)
    print(f"box {c+75} 425 {c+95} 445"); print("paint pdc")
    print(f"box {c+67} 417 {c+103} 500"); print("paint li1")
    print(f"box {c+75} 470 {c+95} 490"); print("paint mcon")
    print(f"box {c+60} 410 {c+110} 500"); print("paint met1")
    # 阱/衬底接触 x200..240
    print(f"box {c+200} 295 {c+240} 325"); print("paint ntap")
    print(f"box {c+210} 300 {c+230} 320"); print("paint nsc")
    print(f"box {c+192} 292 {c+248} 360"); print("paint li1")
    print(f"box {c+210} 330 {c+230} 350"); print("paint mcon")
    print(f"box {c+190} 292 {c+252} 500"); print("paint met1")
    print(f"box {c+200} 33 {c+240} 63"); print("paint ptap")
    print(f"box {c+210} 40 {c+230} 60"); print("paint psc")
    print(f"box {c+192} 32 {c+248} 96"); print("paint li1")
    print(f"box {c+210} 68 {c+230} 88"); print("paint mcon")
    print(f"box {c+190} 0 {c+252} 96"); print("paint met1")
# 电源轨
print("box -60 0 1720 20"); print("paint met1")
print("box -60 480 1720 500"); print("paint met1")
# 反馈环 (抬高到 y650, 远离单元)
print("box 1740 520 1760 670"); print("paint met2")
print("box -110 650 1760 670"); print("paint met2")
print("box -110 520 -80 670"); print("paint met2")
print("box -105 524 -85 544"); print("paint via1")
print("box -110 510 20 550"); print("paint met1")
# 标签
print("box 800 488 802 490"); print("label vpwr")
print("box 800 8 802 10"); print("label vgnd")
print("box 1650 525 1652 527"); print("label out")
print("save ro_opt")
print("drc catchup")
print("drc count")
print("extract all")
print("ext2spice cthresh 0")
print("ext2spice")
print("gds write ro_opt.gds")
print("quit -noprompt")
PYEOF

magic -T "$PDKA/libs.tech/magic/sky130A.tech" \
      -rcfile "$PDKA/libs.tech/magic/sky130A.magicrc" \
      -dnull -noconsole < ro2.magic.tcl > magic2.log 2>&1
echo "magic exit: $?"
grep -iE "unrecognized|DRC errors" magic2.log | head -4
echo "X 器件: $(grep -cE '^X[0-9]' ro_opt.spice)  C 寄生: $(grep -cE '^C[0-9]' ro_opt.spice)"

echo
echo "=== 拓扑校验 ==="
python3 - <<'PYEOF'
import re
from collections import defaultdict
txt = open('/home/user/asic_ro/ro_opt.spice').read()
devs = re.findall(r'^X(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+sky130_fd_pr__(n|p)fet_01v8', txt, re.M)
drives = defaultdict(list)
for n, d, g, s, b, tp in devs:
    assert s == b == ('vgnd' if tp=='n' else 'vpwr'), f'X{n} 端子异常'
    drives[d].append((g, tp))
seen, cur = [], 'out'
while cur not in seen:
    seen.append(cur); cur = drives[cur][0][0]
ok = len(drives)==7 and len(seen)==7 and all(sorted(t for _,t in v)==['n','p'] for v in drives.values())
print(f'器件 {len(devs)}, 环长 {len(seen)}: {"[OK]" if ok else "[!!]"}')
PYEOF

echo
echo "=== 后仿 ==="
sed -E 's/\*\*FLOATING//g; s/^\.end.*$//' ro_opt.spice > ro_opt_post.spice
cat >> ro_opt_post.spice <<'EOF'
vvss vgnd 0 dc 0
vvcc vpwr 0 pwl 0 0 1n 0 1.05n 1.8 200n 1.8
.lib /home/user/.volare/sky130A/libs.tech/ngspice/sky130.lib.spice tt
.control
save all
tran 0.05n 200n
meas tran t1 when v(out)=0.9 rise=4
meas tran t2 when v(out)=0.9 rise=10
.endc
.end
EOF
timeout 300 ngspice -b ro_opt_post.spice > postsim2.log 2>&1
grep -E "^t1|^t2|Error" postsim2.log | head -4

python3 - <<'PYEOF'
import re
def meas(fn):
    t1 = t2 = None
    for L in open(fn, errors='replace'):
        m = re.search(r't1\s*=\s*([0-9.eE+-]+)', L)
        if m: t1 = float(m.group(1))
        m = re.search(r't2\s*=\s*([0-9.eE+-]+)', L)
        if m: t2 = float(m.group(1))
    return t1, t2
p1, p2 = meas('/home/user/asic_ro/presim.log')
s1, s2 = meas('/home/user/asic_ro/postsim2.log')
if s1 and s2:
    f_pre, f_post = 3/(p2-p1)/1e6, 3/(s2-s1)/1e6
    print(f'前仿  f_pre  = {f_pre:,.1f} MHz')
    print(f'优化版后仿    = {f_post:,.1f} MHz  (原版 835.7 MHz)')
    print(f'寄生损耗: {(1-f_post/f_pre)*100:.2f}%  (原版 38.10%)')
else:
    print('[!] 未起振或测量失败')
PYEOF
ls -la ro_opt.gds

echo
echo "=== LVS 复验 (优化版) ==="
{ echo '.subckt ro out vpwr vgnd'; sed -E 's/\*\*FLOATING//g; /^C[0-9]+ /d; s/^\.end.*$//' ro_opt.spice; echo '.ends ro'; } > ro_opt_lvs.spice
export NETGENDIR=/nix/store/dkz56a072q19x2vaqa9am4wnnn124qcn-netgen-1.5.323/lib/netgen/tcl
NETBIN=$(readlink -f ~/.nix-profile/bin/netgen)
timeout 180 "$NETBIN" -batch lvs "ro_opt_lvs.spice ro" "ro_schem.spice ro" \
  "$PDKA/libs.tech/netgen/sky130A_setup.tcl" > ro_opt_lvs.log 2>&1
grep -E "match uniquely|failed|Mismatch" ro_opt_lvs.log | tail -2

echo
echo "=== 渲染 + 交付 ==="
cat > render2.py <<'EOF'
import pya
layout = pya.Layout()
layout.read("/home/user/asic_ro/ro_opt.gds")
view = pya.LayoutView.new()
view.show_layout(layout, False)
view.max_hier()
view.zoom_fit()
view.save_image("/home/user/asic_ro/ro_opt.png", 1800, 900)
view.close()
print("PNG saved")
EOF
timeout 120 klayout -b -r render2.py 2>&1 | tail -1
WS=/path/to/Downloads/asic
cp ro_opt.gds ro_opt.png ro_opt.spice ro_opt_lvs.log $WS/ 2>/dev/null
ls -la $WS/ro_opt.* 2>/dev/null
