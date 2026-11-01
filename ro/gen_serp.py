#!/usr/bin/env python3
"""gen_serp.py — 生成蛇形（两排）环振版图的 magic TCL。

下排 cell0..3 正常朝向；上排 cell4..6 旋转 180°，管脚面向中间通道；
反馈网在通道内横走，右侧 met2 竖带跨行缝合电源。
输出到 stdout，由 run_ro.sh 交给 magic -dnull 执行。
"""
import os

N = 7
PITCH = 240
Y1 = 650          # 上排基线
CELL_W, CELL_H = 240, 500
NAME = os.environ.get("LAYOUT_NAME", "ro_serp")


def emit(x1, y1, x2, y2, layer, bx, by, rot):
    if rot:
        X1, Y1_ = bx + CELL_W - x2, by + CELL_H - y2
        X2, Y2_ = bx + CELL_W - x1, by + CELL_H - y1
    else:
        X1, Y1_, X2, Y2_ = bx + x1, by + y1, bx + x2, by + y2
    print(f"box {X1} {Y1_} {X2} {Y2_}")
    print(f"paint {layer}")


def cell(bx, by, rot):
    e = lambda a, b, c, d, lay: emit(a, b, c, d, lay, bx, by, rot)
    e(0, 240, 240, 500, "nwell")
    e(70, 100, 175, 200, "ndiff")
    e(70, 280, 175, 480, "pdiff")
    e(110, 60, 125, 556, "poly")      # 栅极条：必须连到 IN blob（556）
    e(0, 505, 125, 556, "poly")       # IN blob
    e(20, 524, 40, 544, "pc")
    e(12, 514, 72, 554, "li1")
    e(44, 524, 64, 544, "mcon")
    e(8, 514, 76, 554, "met1")        # IN pad
    e(75, 135, 95, 155, "ndc")        # NMOS 源
    e(67, 92, 103, 188, "li1")
    e(75, 100, 95, 120, "mcon")
    e(60, 0, 110, 165, "met1")
    e(150, 135, 170, 155, "ndc")      # 漏
    e(142, 127, 178, 188, "li1")
    e(150, 160, 170, 180, "mcon")
    e(150, 285, 170, 305, "pdc")
    e(142, 242, 178, 313, "li1")
    e(150, 250, 170, 270, "mcon")
    e(125, 120, 175, 320, "met1")     # OUT 竖干
    e(128, 150, 148, 170, "via1")
    e(128, 140, 148, 538, "met2")     # OUT 爬升
    e(75, 425, 95, 445, "pdc")        # PMOS 源
    e(67, 417, 103, 500, "li1")
    e(75, 470, 95, 490, "mcon")
    e(60, 410, 110, 500, "met1")
    e(200, 295, 240, 325, "ntap")     # nwell tap
    e(210, 300, 230, 320, "nsc")
    e(192, 292, 248, 360, "li1")
    e(210, 330, 230, 350, "mcon")
    e(190, 292, 252, 500, "met1")
    e(200, 33, 240, 63, "ptap")       # pwell tap
    e(210, 40, 230, 60, "psc")
    e(192, 32, 248, 96, "li1")
    e(210, 68, 230, 88, "mcon")
    e(190, 0, 252, 96, "met1")


for i in range(4):
    cell(i * PITCH, 0, False)
for i, col in zip(range(4, 7), [3, 2, 1]):
    cell(col * PITCH, Y1, True)

# 电源轨
print("box -60 0 1050 20");      print("paint met1")     # 下排 VGND
print("box -60 480 1050 500");   print("paint met1")     # 下排 VPWR
print("box 200 650 1050 670");   print("paint met1")     # 上排 VPWR（旋转后到下方）
print("box 200 1130 1050 1150"); print("paint met1")     # 上排 VGND（旋转后到上方）

# 下排级间走线（cell0->1, 1->2, 2->3）
for i in range(3):
    c = i * PITCH
    print(f"box {c+128} 518 {c+316} 538"); print("paint met2")
    print(f"box {c+250} 524 {c+270} 544"); print("paint via1")

# cell3 -> cell4（跨排：短竖 + jog）
print("box 848 538 868 632"); print("paint met2")
print("box 848 612 914 632"); print("paint met2")
print("box 890 606 910 626"); print("paint via1")

# 上排级间走线（cell4->5, 5->6，右到左）
print("box 644 612 832 632"); print("paint met2")
print("box 656 606 676 626"); print("paint via1")
print("box 404 612 592 632"); print("paint met2")
print("box 420 606 440 626"); print("paint via1")

# 反馈：cell6 -> cell0（通道内横走 + 下探进 IN pad）
print("box 44 612 352 632"); print("paint met2")
print("box 42 524 66 632"); print("paint met2")
print("box 46 524 62 544"); print("paint via1")
print("box 8 514 70 554"); print("paint met1")

# 电源跨排缝合带（met2）
print("box 965 470 995 680"); print("paint met2")        # VPWR
print("box 970 480 990 500"); print("paint via1")
print("box 970 650 990 670"); print("paint via1")
print("box 1015 0 1045 1150"); print("paint met2")       # VGND
print("box 1020 0 1040 20"); print("paint via1")
print("box 1020 1130 1040 1150"); print("paint via1")

# 标签
print("box 500 488 502 490"); print("label vpwr")
print("box 500 8 502 10"); print("label vgnd")
print("box 250 620 252 622"); print("label out")

print(f"save {NAME}")
print("drc catchup")
print("drc count")
print("extract all")
print("ext2spice cthresh 0")
print("ext2spice")
print(f"gds write {NAME}.gds")
print("quit -noprompt")
