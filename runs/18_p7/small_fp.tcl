source /path/to/openlane-lab/scripts/common.tcl
read_verilog /path/to/openlane-lab/runs/01_synth/counter_synth.v
link_design counter
initialize_floorplan -site unithd -die_area {0 0 40 40} -core_area {2 2 38 38}
make_tracks
place_pins -hor_layers met3 -ver_layers met2
report_design_area
write_def /path/to/openlane-lab/runs/18_p7/small_floorplan.def
