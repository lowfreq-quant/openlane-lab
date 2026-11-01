#!/bin/bash
# 环振 v7: 两排蛇形 (serpentine) floorplan
# 下排 cell0..3 正常朝向; 上排 cell4..6 旋转180°, 管脚面向通道
source ~/.bashrc >/dev/null 2>&1
PDKA=$PDK_ROOT/sky130A
RO=~/asic_ro
cd $RO || exit 1

python3 > ro3.magic.tcl <<'PYEOF'
N = 7
PITCH = 240
Y1 = 650            # 上排基线
CELL_W, CELL_H = 240, 500

def emit(x1, y1, x2, y2, layer, bx, by, rot):
    if rot:
        X1, Y1 = bx + CELL_W - x2, by + CELL_H - y2
        X2, Y2 = bx + CELL_W - x1, by + CELL_H - y1
    else:
        X1, Y1, X2, Y2 = bx + x1, by + y1, bx + x2, by + y2
    print(f"box {X1} {Y1} {X2} {Y2}")
    print(f"paint {layer}")

def cell(bx, by, rot):
    e = lambda a,b,c,d,lay: emit(a,b,c,d,lay,bx,by,rot)
    e(0,240,240,500,"nwell")
    e(70,100,175,200,"ndiff")
    e(70,280,175,480,"pdiff")
    e(110,60,125,556,"poly")
    e(0,505,125,556,"poly")          # IN blob 连栅
    e(20,524,40,544,"pc")
    e(12,514,72,554,"li1")
    e(44,524,64,544,"mcon")
    e(8,514,76,554,"met1")            # IN pad
    e(75,135,95,155,"ndc")           # NMOS 源
    e(67,92,103,188,"li1")
    e(75,100,95,120,"mcon")
    e(60,0,110,165,"met1")
    e(150,135,170,155,"ndc")          # 漏
    e(142,127,178,188,"li1")
    e(150,160,170,180,"mcon")
    e(150,285,170,305,"pdc")
    e(142,242,178,313,"li1")
    e(150,250,170,270,"mcon")
    e(125,120,175,320,"met1")         # OUT 竖干
    e(128,150,148,170,"via1")
    e(128,140,148,538,"met2")         # OUT 爬升
    e(75,425,95,445,"pdc")            # PMOS 源
    e(67,417,103,500,"li1")
    e(75,470,95,490,"mcon")
    e(60,410,110,500,"met1")
    e(200,295,240,325,"ntap")
    e(210,300,230,320,"nsc")
    e(192,292,248,360,"li1")
    e(210,330,230,350,"mcon")
    e(190,292,252,500,"met1")
    e(200,33,240,63,"ptap")
    e(210,40,230,60,"psc")
    e(192,32,248,96,"li1")
    e(210,68,230,88,"mcon")
    e(190,0,252,96,"met1")

# 下排: cell0..3 @ x=0,240,480,720, y=0
for i in range(4):
    cell(i*PITCH, 0, False)
# 上排: cell4,5,6 @ x=720,480,240, y=650 (旋转180°)
for i, col in zip(range(4,7), [3,2,1]):
    cell(col*PITCH, Y1, True)

# 电源轨
print("box -60 0 1050 20");      print("paint met1")   # 下排 VGND
print("box -60 480 1050 500"); print("paint met1")   # 下排 VPWR
print("box 200 650 1050 670"); print("paint met1")   # 上排 VPWR (旋转后)
print("box 200 1130 1050 1150"); print("paint met1") # 上排 VGND

# 下排级间走线 (cell0->1,1->2,2->3)
for i in range(3):
    c = i*PITCH
    print(f"box {c+128} 518 {c+316} 538"); print("paint met2")
    print(f"box {c+250} 524 {c+270} 544"); print("paint via1")
# cell3 -> cell4 (跨排, 短竖+jog)
print("box 848 538 868 632"); print("paint met2")
print("box 848 612 914 632"); print("paint met2")
print("box 890 606 910 626"); print("paint via1")
# 上排级间走线 (cell4->5, cell5->6, 右到左)
print("box 644 612 832 632"); print("paint met2")
print("box 656 606 676 626"); print("paint via1")
print("box 404 612 592 632"); print("paint met2")
print("box 420 606 440 626"); print("paint via1")
# 反馈: cell6 -> cell0 (通道内横走 + 下探)
print("box 44 612 352 632"); print("paint met2")
print("box 42 524 66 632"); print("paint met2")
print("box 46 524 62 544"); print("paint via1")
print("box 8 514 70 554"); print("paint met1")
# 电源跨排缝合带 (met2)
print("box 965 470 995 680"); print("paint met2")    # VPWR 带
print("box 970 480 990 500"); print("paint via1")
print("box 970 650 990 670"); print("paint via1")
print("box 1015 0 1045 1150"); print("paint met2")   # VGND 带
print("box 1020 0 1040 20"); print("paint via1")
print("box 1020 1130 1040 1150"); print("paint via1")
# 标签
print("box 500 488 502 490"); print("label vpwr")
print("box 500 8 502 10"); print("label vgnd")
print("box 250 620 252 622"); print("label out")
print("save ro_serp")
print("drc catchup")
print("drc count")
print("extract all")
print("ext2spice cthresh 0")
print("ext2spice")
print("gds write ro_serp.gds")
print("quit -noprompt")
PYEOF

magic -T "$PDKA/libs.tech/magic/sky130A.tech" \
      -rcfile "$PDKA/libs.tech/magic/sky130A.magicrc" \
      -dnull -noconsole < ro3.magic.tcl > magic3.log 2>&1
echo "magic exit: $?"
grep -iE "unrecognized|DRC errors" magic3.log | head -4
echo "X 器件: $(grep -cE '^X[0-9]' ro_serp.spice)  C 寄生: $(grep -cE '^C[0-9]' ro_serp.spice)"

echo
echo "=== 拓扑校验 ==="
python3 - <<'PYEOF'
import re
from collections import defaultdict
txt = open('/home/user/asic_ro/ro_serp.spice').read()
devs = re.findall(r'^X(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+sky130_fd_pr__(n|p)fet_01v8', txt, re.M)
drives = defaultdict(list)
for n, d, g, s, b, tp in devs:
    pwr = 'vgnd' if tp == 'n' else 'vpwr'
    terms = {d, s}
    assert b == pwr and pwr in terms, f'X{n} 端子异常 {d}/{s}/{b}'
    ring_net = (terms - {pwr}).pop()
    drives[ring_net].append((g, tp))
seen, cur = [], 'out'
while cur not in seen:
    seen.append(cur); cur = drives[cur][0][0]
ok = len(devs)==14 and len(seen)==7 and all(sorted(t for _,t in v)==['n','p'] for v in drives.values())
print(f'器件 {len(devs)}, 环长 {len(seen)}: {"[OK] 7级闭环" if ok else "[!!]"}')
PYEOF

echo
echo "=== 后仿 ==="
sed -E 's/\*\*FLOATING//g; s/^\.end.*$//' ro_serp.spice > ro_serp_post.spice
cat >> ro_serp_post.spice <<'EOF'
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
timeout 300 ngspice -b ro_serp_post.spice > postsim3.log 2>&1
grep -E "^t1|^t2|Error" postsim3.log | head -4
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
s1, s2 = meas('/home/user/asic_ro/postsim3.log')
if s1 and s2:
    f_pre, f_post = 3/(p2-p1)/1e6, 3/(s2-s1)/1e6
    print(f'前仿    f_pre = {f_pre:,.1f} MHz')
    print(f'蛇形版  f    = {f_post:,.1f} MHz  (单排版 910.8)')
    print(f'寄生损耗: {(1-f_post/f_pre)*100:.2f}%  (单排版 32.54%)')
else:
    print('[!] 未起振')
PYEOF

echo
echo "=== LVS ==="
{ echo '.subckt ro out vpwr vgnd'; sed -E 's/\*\*FLOATING//g; /^C[0-9]+ /d; s/^\.end.*$//' ro_serp.spice; echo '.ends ro'; } > ro_serp_lvs.spice
export NETGENDIR=/nix/store/dkz56a072q19x2vaqa9am4wnnn124qcn-netgen-1.5.323/lib/netgen/tcl
NETBIN=$(readlink -f ~/.nix-profile/bin/netgen)
timeout 180 "$NETBIN" -batch lvs "ro_serp_lvs.spice ro" "ro_schem.spice ro" \
  "$PDKA/libs.tech/netgen/sky130A_setup.tcl" > ro_serp_lvs.log 2>&1
grep -E "match uniquely|failed|Mismatch" ro_serp_lvs.log | tail -2

echo
echo "=== 渲染 + 交付 ==="
cat > render3.py <<'EOF'
import pya
layout = pya.Layout()
layout.read("/home/user/asic_ro/ro_serp.gds")
view = pya.LayoutView.new()
view.show_layout(layout, False)
view.max_hier()
view.zoom_fit()
view.save_image("/home/user/asic_ro/ro_serp.png", 1400, 1400)
view.close()
print("PNG saved")
EOF
timeout 120 klayout -b -r render3.py 2>&1 | tail -1
WS=/path/to/Downloads/asic
cp ro_serp.gds ro_serp.png ro_serp.spice ro_serp_lvs.log $WS/ 2>/dev/null
ls -la $WS/ro_serp.* 2>/dev/null
