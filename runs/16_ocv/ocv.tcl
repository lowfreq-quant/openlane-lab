source /path/to/openlane-lab/scripts/common.tcl
read_db /path/to/openlane-lab/runs/05_route/route.odb
read_liberty /home/user/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_n40C_1v65.lib
read_sdc /path/to/openlane-lab/constraints/counter.sdc
if {[file exists /path/to/openlane-lab/runs/13_spef/counter.spef]} {
  read_spef /path/to/openlane-lab/runs/13_spef/counter.spef
} else {
  estimate_parasitics -global_routing
}
# OCV：setup 路径悲观，hold 另一套
set_timing_derate -early 0.90
set_timing_derate -late  1.05
# 仅对 clock 网络也可再加 -clock；这里全局 early/late 已足够教学
puts "SLACK_MAX_BEGIN"
report_checks -path_delay max -format slack_only
puts "SLACK_MAX_END"
puts "SLACK_MIN_BEGIN"
report_checks -path_delay min -format slack_only
puts "SLACK_MIN_END"
report_wns
report_tns
report_wns -min
report_tns -min
