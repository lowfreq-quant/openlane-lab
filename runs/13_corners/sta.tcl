read_lef $::env(MERGED_LEF)
read_liberty /home/user/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_100C_1v40.lib
read_db /path/to/openlane-lab/runs/05_route/route.odb
read_sdc /path/to/openlane-lab/runs/13_corners/t_stress_1ns.sdc
estimate_parasitics -global_routing
puts "SLACK_MAX_BEGIN"
report_checks -path_delay max -format slack_only
puts "SLACK_MAX_END"
report_wns
report_tns
