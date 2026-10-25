drc off
tech load /home/user/.volare/sky130A/libs.tech/magic/sky130A.tech
gds readonly true
gds rescale false
gds read /path/to/openlane-lab/runs/09_gds/counter.gds
load counter
select top cell
extract do local
extract all
ext2spice lvs
ext2spice -o /path/to/openlane-lab/runs/17_lvs_device/counter_dev_ext.spice
quit -noprompt
