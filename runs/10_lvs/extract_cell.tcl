drc off
tech load /home/user/.volare/sky130A/libs.tech/magic/sky130A.tech
# 单元用 LEF 抽象，不展开晶体管
lef read /path/to/openlane-lab/runs/lef/sky130_fd_sc_hd_merged.lef
def read /path/to/openlane-lab/runs/05_route/route.def
load counter
select top cell
# 层次化提取：保持单元实例
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique
extract do local
extract all
ext2spice lvs
ext2spice -o /path/to/openlane-lab/runs/10_lvs/counter_ext_cell.spice
quit -noprompt
