// sky130_hd_min.v — 仅覆盖 counter 网表用到的单元（功能模型，无时序）
// 用途：门级功能仿真 / 等价性直觉校验
`timescale 1ns/1ps
`default_nettype none

// 反相器
module sky130_fd_sc_hd__clkinv_1 (output Y, input A);
  assign Y = ~A;
endmodule

// 2 输入与非
module sky130_fd_sc_hd__nand2_1 (output Y, input A, input B);
  assign Y = ~(A & B);
endmodule

// 4 输入与非
module sky130_fd_sc_hd__nand4_1 (output Y, input A, B, C, D);
  assign Y = ~(A & B & C & D);
endmodule

// 4 输入与
module sky130_fd_sc_hd__and4_1 (output X, input A, B, C, D);
  assign X = A & B & C & D;
endmodule

// 2 输入或非
module sky130_fd_sc_hd__nor2_1 (output Y, input A, B);
  assign Y = ~(A | B);
endmodule

// 异或 / 同或
module sky130_fd_sc_hd__xor2_1 (output X, input A, B);
  assign X = A ^ B;
endmodule
module sky130_fd_sc_hd__xnor2_1 (output Y, input A, B);
  assign Y = ~(A ^ B);
endmodule

// AOI: Y = ~((A1&A2&A3) | B1)
module sky130_fd_sc_hd__a31oi_1 (output Y, input A1, A2, A3, B1);
  assign Y = ~((A1 & A2 & A3) | B1);
endmodule

// 隔离缓冲：SLEEP=0 直通；SLEEP=1 输出钳到 0
module sky130_fd_sc_hd__lpflow_isobufsrc_1 (output X, input A, input SLEEP);
  assign X = SLEEP ? 1'b0 : A;
endmodule

// 带异步复位的上升沿触发器
module sky130_fd_sc_hd__dfrtp_1 (
  output reg Q,
  input  wire CLK,
  input  wire D,
  input  wire RESET_B
);
  always @(posedge CLK or negedge RESET_B) begin
    if (!RESET_B) Q <= 1'b0;
    else          Q <= D;
  end
endmodule

`default_nettype wire
