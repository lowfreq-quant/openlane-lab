source /home/user/.volare/sky130A/libs.tech/netgen/sky130A_setup.tcl
source /path/to/openlane-lab/scripts/lvs_extra.tcl

# 忽略 fill/tap/decap 类
foreach c {
  sky130_fd_sc_hd__decap_3 sky130_fd_sc_hd__decap_4 sky130_fd_sc_hd__decap_6
  sky130_fd_sc_hd__decap_8 sky130_fd_sc_hd__decap_12
  sky130_fd_sc_hd__fill_1 sky130_fd_sc_hd__fill_2 sky130_fd_sc_hd__fill_4 sky130_fd_sc_hd__fill_8
  sky130_fd_sc_hd__tap_1 sky130_fd_sc_hd__tap_2
  sky130_fd_sc_hd__tapvgnd_1 sky130_fd_sc_hd__tapvgnd2_1 sky130_fd_sc_hd__tapvpwrvgnd_1
} {
  catch {ignore class "-circuit1 $c"}
  catch {ignore class "-circuit2 $c"}
}

# 晶体管属性：LVS 只看连接，不看 W/L/面积
foreach p {w l m mult as ad ps pd sa sb sd area perim topography nf nrd nrs} {
  catch {property "-circuit1 sky130_fd_pr__nfet_01v8" remove $p}
  catch {property "-circuit2 nfet_01v8" remove $p}
  catch {property "-circuit1 sky130_fd_pr__pfet_01v8_hvt" remove $p}
  catch {property "-circuit2 pfet_01v8_hvt" remove $p}
}

# 电源全局
foreach n {VPWR VGND VNB VPB} {
  catch {net global "-circuit1 $n"}
  catch {net global "-circuit2 $n"}
}
