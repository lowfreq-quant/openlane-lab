# netgen LVS 额外规则：电源全局 + 忽略 fill/tap
# 在 sky130A_setup.tcl 之后 source

# 电源地视为全局网
foreach n {VGND VPWR VNB VPB} {
  catch {net global "-circuit1 $n"}
  catch {net global "-circuit2 $n"}
}

# 时钟树缓冲可以不忽略——它们在 golden 里
# 仅忽略 fill/tap/decap（setup 里已有部分）
foreach c {
  sky130_fd_sc_hd__fill_1
  sky130_fd_sc_hd__fill_2
  sky130_fd_sc_hd__fill_4
  sky130_fd_sc_hd__fill_8
  sky130_fd_sc_hd__decap_3
  sky130_fd_sc_hd__decap_4
  sky130_fd_sc_hd__decap_6
  sky130_fd_sc_hd__decap_8
  sky130_fd_sc_hd__decap_12
  sky130_fd_sc_hd__tap_1
  sky130_fd_sc_hd__tap_2
  sky130_fd_sc_hd__tapvgnd_1
  sky130_fd_sc_hd__tapvgnd2_1
  sky130_fd_sc_hd__tapvpwrvgnd_1
} {
  catch {ignore class "-circuit1 $c"}
  catch {ignore class "-circuit2 $c"}
}
