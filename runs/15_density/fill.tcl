source /path/to/openlane-lab/scripts/common.tcl
read_db /path/to/openlane-lab/runs/05_route/route.odb
puts "===== density_fill ====="
density_fill -rules /path/to/openlane-lab/scripts/sky130_density_fill.json
puts "FILL_DONE"
write_db /path/to/openlane-lab/runs/15_density/route_filled.odb
write_def /path/to/openlane-lab/runs/15_density/route_filled.def
report_design_area
