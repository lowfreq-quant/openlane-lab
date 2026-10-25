source $::env(SCRIPTS_DIR)/common.tcl

read_verilog $::env(NETLIST)
link_design counter
read_sdc $::env(SDC)

# 裸 die：site=unithd（sky130_fd_sc_hd 的行高）
initialize_floorplan \
  -site unithd \
  -die_area {0 0 100 100} \
  -core_area {10 10 90 90}

# 必须先有轨道，place_pins 才有地方放
make_tracks

# IO 摆放（sky130：水平 met3 / 垂直 met2）
place_pins -hor_layers met3 -ver_layers met2

# 注意：本 lab 不做 PDN（见 README「已知局限」）
write_db $::env(OUT)/floorplan.odb
write_def $::env(OUT)/floorplan.def
report_design_area
