source $::env(SCRIPTS_DIR)/common.tcl
read_db $::env(RT)/route.odb
read_sdc $::env(SDC)
report_checks -path_delay max -fields {slew capacitance} -format full_clock_expanded
report_checks -path_delay min
report_clock_skew
report_wns
report_tns
report_design_area
