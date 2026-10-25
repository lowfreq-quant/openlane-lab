drc off
tech load /home/user/.volare/sky130A/libs.tech/magic/sky130A.tech
gds readonly true
gds rescale false
gds read /path/to/openlane-lab/runs/17_lvs_device/counter_hier.gds
load counter
select top cell
# 保留层级：不要 extract do local 打平
extract no capacitance
extract no coupling
extract no resistance
extract all
ext2spice lvs
ext2spice -o /path/to/openlane-lab/runs/17_lvs_device/counter_hier_ext.spice
quit -noprompt
