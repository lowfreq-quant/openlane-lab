// 物理单元桩（sky130_fd_sc_hd 的 fill / tap）
//
// 后仿用的网表来自 route.odb，里面含 730 个 fill cell 和 93 个 tap cell。
// 它们没有逻辑，也不该有时序模型，这里给个空模块，让 iverilog 能编译通过。
// 注意：不要把它们加进 sim/sky130_hd_min.v（那是功能模型，参与等价/门级仿真）。

`timescale 1ns/1ps

module sky130_fd_sc_hd__fill_1 (); endmodule
module sky130_fd_sc_hd__fill_2 (); endmodule
module sky130_fd_sc_hd__fill_4 (); endmodule
module sky130_fd_sc_hd__fill_8 (); endmodule

module sky130_fd_sc_hd__tapvpwrvgnd_1 (); endmodule
module sky130_fd_sc_hd__tapvgnd_1 (); endmodule
module sky130_fd_sc_hd__tapvgnd2_1 (); endmodule
module sky130_fd_sc_hd__tap_1 (); endmodule
module sky130_fd_sc_hd__tap_2 (); endmodule

module sky130_fd_sc_hd__decap_3 (); endmodule
module sky130_fd_sc_hd__decap_4 (); endmodule
module sky130_fd_sc_hd__decap_6 (); endmodule
module sky130_fd_sc_hd__decap_8 (); endmodule
module sky130_fd_sc_hd__decap_12 (); endmodule
