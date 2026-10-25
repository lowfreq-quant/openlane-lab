source /path/to/openlane-lab/scripts/common.tcl
read_db /path/to/openlane-lab/runs/05_route/route.odb
create_clock -name clk -period 1.0 [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay  0.1 -clock clk [get_ports rst_n]
set_output_delay 0.1 -clock clk [get_ports q*]
set_output_delay 0.1 -clock clk [get_ports tick]

puts "---- STRESS 1ns: estimate ----"
estimate_parasitics -global_routing
report_wns
report_checks -path_delay max -digits 3

puts "---- STRESS 1ns: SPEF ----"
extract_parasitics -ext_model_file /home/user/.volare/sky130A/libs.tech/openlane/rcx_rules.info
read_spef /path/to/openlane-lab/runs/13_spef/counter.spef
report_wns
report_checks -path_delay max -digits 3
