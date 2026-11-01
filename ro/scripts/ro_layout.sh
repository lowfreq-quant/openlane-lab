#!/bin/bash
# 环振 magic 版图 v5: met2 级间走线 + 错位接触 + IN 接触在栅顶 poly blob 上
# pitch 340u (3.4um), 高 610u
source ~/.bashrc >/dev/null 2>&1
PDKA=$PDK_ROOT/sky130A
RO=~/asic_ro
cd $RO || exit 1

python3 > ro.magic.tcl <<'PYEOF'
N = 7
PITCH = 340
E = N * PITCH  # 2380
for i in range(N):
    c = i * PITCH
    # 阱/扩散/栅
    print(f"box {c+0} 240 {c+340} 500"); print("paint nwell")
    print(f"box {c+3} 100 {c+220} 200"); print("paint ndiff")
    print(f"box {c+3} 280 {c+220} 480"); print("paint pdiff")
    print(f"box {c+150} 60 {c+165} 556"); print("paint poly")
    print(f"box {c+145} 505 {c+190} 556"); print("paint poly")   # IN blob
    # IN: pc(licon1) on poly blob -> li1 -> mcon(错位) -> met1 pad
    print(f"box {c+150} 524 {c+170} 544"); print("paint pc")
    print(f"box {c+138} 514 {c+212} 554"); print("paint li1")
    print(f"box {c+182} 524 {c+202} 544"); print("paint mcon")
    print(f"box {c+136} 514 {c+214} 554"); print("paint met1")
    # NMOS 源 -> VGND
    print(f"box {c+60} 135 {c+80} 155"); print("paint ndc")
    print(f"box {c+52} 127 {c+128} 163"); print("paint li1")
    print(f"box {c+100} 135 {c+120} 155"); print("paint mcon")
    print(f"box {c+50} 0 {c+130} 165"); print("paint met1")
    # NMOS 漏 + PMOS 漏 -> OUT 竖干 (met1)
    print(f"box {c+190} 135 {c+210} 155"); print("paint ndc")
    print(f"box {c+182} 127 {c+258} 163"); print("paint li1")
    print(f"box {c+230} 135 {c+250} 155"); print("paint mcon")
    print(f"box {c+190} 285 {c+210} 305"); print("paint pdc")
    print(f"box {c+182} 277 {c+258} 313"); print("paint li1")
    print(f"box {c+230} 285 {c+250} 305"); print("paint mcon")
    print(f"box {c+180} 40 {c+258} 310"); print("paint met1")
    # OUT: met1 -> via1 -> met2 垂直跨过 VPWR 轨 -> 顶部 met2 走线
    print(f"box {c+220} 70 {c+240} 90"); print("paint via1")
    print(f"box {c+220} 60 {c+240} 535"); print("paint met2")
    if i < N-1:
        print(f"box {c+220} 518 {c+530} 548"); print("paint met2")
        print(f"box {c+510} 524 {c+530} 544"); print("paint via1")  # 下到下级 IN pad
    else:
        print(f"box {c+220} 518 2430 548"); print("paint met2")
    # PMOS 源 -> VPWR
    print(f"box {c+60} 445 {c+80} 465"); print("paint pdc")
    print(f"box {c+52} 437 {c+128} 473"); print("paint li1")
    print(f"box {c+100} 445 {c+120} 465"); print("paint mcon")
    print(f"box {c+50} 435 {c+130} 500"); print("paint met1")
    # 阱/衬底接触
    print(f"box {c+283} 295 {c+337} 325"); print("paint ntap")
    print(f"box {c+290} 300 {c+310} 320"); print("paint nsc")
    print(f"box {c+277} 292 {c+340} 328"); print("paint li1")
    print(f"box {c+312} 300 {c+332} 320"); print("paint mcon")
    print(f"box {c+275} 292 {c+340} 500"); print("paint met1")
    print(f"box {c+283} 33 {c+337} 67"); print("paint ptap")
    print(f"box {c+290} 40 {c+310} 60"); print("paint psc")
    print(f"box {c+277} 32 {c+340} 68"); print("paint li1")
    print(f"box {c+312} 40 {c+332} 60"); print("paint mcon")
    print(f"box {c+275} 0 {c+340} 68"); print("paint met1")
# 电源轨
print("box -60 0 2380 20"); print("paint met1")
print("box -60 480 2380 500"); print("paint met1")
# 反馈环 (met2 顶部 + 左侧 met1 link 到 IN pad0)
print("box 2400 518 2430 598"); print("paint met2")
print("box -110 568 2430 598"); print("paint met2")
print("box -110 518 -80 598"); print("paint met2")
print("box -105 524 -85 544"); print("paint via1")
print("box -110 514 150 554"); print("paint met1")
# 标签
print("box 1000 488 1002 490"); print("label vpwr")
print("box 1000 8 1002 10"); print("label vgnd")
print("box 2350 530 2352 532"); print("label out")
# 保存 / DRC / 提取 / GDS
print("save ro_layout")
print("drc catchup")
print("drc count")
print("extract all")
print("ext2spice cthresh 0")
print("ext2spice")
print("gds write ro_layout.gds")
print("quit -noprompt")
PYEOF

magic -T "$PDKA/libs.tech/magic/sky130A.tech" \
      -rcfile "$PDKA/libs.tech/magic/sky130A.magicrc" \
      -dnull -noconsole < ro.magic.tcl > magic.log 2>&1
echo "magic exit: $?"
grep -iE "unrecognized|error tile|has [0-9]+ error" magic.log | head -4
echo "--- DRC ---"
grep -iE "DRC errors" magic.log
echo "--- 网表统计 ---"
echo "X 器件: $(grep -cE '^X[0-9]' ro_layout.spice)  C 寄生: $(grep -cE '^C[0-9]' ro_layout.spice)"
echo "独立 a_* 节点: $(grep -oE 'a_[0-9_]+#' ro_layout.spice | sort -u | wc -l)"
grep -oE 'a_[0-9_]+#' ro_layout.spice | sort -u
echo "--- 器件抽样 ---"
grep -E '^X[0-9]+ ' ro_layout.spice | head -4
ls -la ro_layout.gds
