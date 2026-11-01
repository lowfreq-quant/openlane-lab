#!/bin/bash
# Finale: klayout 渲染 GDS + 交付物拷贝 + GUI
source ~/.bashrc >/dev/null 2>&1
PDKA=$PDK_ROOT/sky130A
RO=~/asic_ro
WS=/path/to/Downloads/asic
cd $RO || exit 1

echo "=== 1. klayout 渲染 GDS ==="
cat > render.py <<'EOF'
import pya
layout = pya.Layout()
layout.read("/home/user/asic_ro/ro_layout.gds")
view = pya.LayoutView.new()
view.show_layout(layout, False)
view.max_hier()
view.zoom_fit()
view.save_image("/home/user/asic_ro/ro_layout.png", 1800, 900)
view.close()
print("PNG saved")
EOF
timeout 120 klayout -b -r render.py 2>&1 | tail -3
ls -la ro_layout.png 2>/dev/null

echo
echo "=== 2. 交付物拷贝到 Windows 工作区 ==="
mkdir -p $WS
cp ro_layout.gds ro_layout.png ro_lvs.log ro.spice ro.sch \
   ro_post.spice magic.log presim.log postsim.log $WS/ 2>/dev/null
ls -la $WS/ro_layout.* 2>/dev/null

echo
echo "=== 3. 启动 GUI ==="
nohup xschem --rcfile "$PDKA/libs.tech/xschem/xschemrc" "$RO/ro.sch" >/tmp/xschem.log 2>&1 &
disown
nohup magic -T "$PDKA/libs.tech/magic/sky130A.tech" \
   -rcfile "$PDKA/libs.tech/magic/sky130A.magicrc" "$RO/ro_layout.mag" \
   >/tmp/magic_gui.log 2>&1 &
disown
sleep 4
pgrep -a xschem | head -1
pgrep -a magic | head -1
echo "[完成] xschem(原理图) + magic(版图) 窗口已打开"
