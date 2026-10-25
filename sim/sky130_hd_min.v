// sky130_hd_min.v — 仅覆盖 counter 网表用到的单元
//
// 用途：
//   1) 门级功能仿真（run_sim.sh）
//   2) 形式等价（run_equiv.sh，-DFUNCTIONAL）
//   3) SDF 后仿（run_postsim.sh，-gspecify 时 specify 块生效）
//
// specify 块里的数字只是占位默认值；后仿时会被 SDF 里的延迟覆盖。
// 没有 specify 块，iverilog 会直接忽略 $sdf_annotate（"specify blocks are
// being omitted"），所以这几行是后仿能成立的前提。
`timescale 1ns/1ps
`default_nettype none

// 反相器
module sky130_fd_sc_hd__clkinv_1 (output Y, input A);
  assign Y = ~A;
  specify
    (A => Y) = (0.05, 0.05);
  endspecify
endmodule

// 2 输入与非
module sky130_fd_sc_hd__nand2_1 (output Y, input A, input B);
  assign Y = ~(A & B);
  specify
    (A => Y) = (0.05, 0.05);
    (B => Y) = (0.05, 0.05);
  endspecify
endmodule

// 4 输入与非
module sky130_fd_sc_hd__nand4_1 (output Y, input A, B, C, D);
  assign Y = ~(A & B & C & D);
  specify
    (A => Y) = (0.05, 0.05);
    (B => Y) = (0.05, 0.05);
    (C => Y) = (0.05, 0.05);
    (D => Y) = (0.05, 0.05);
  endspecify
endmodule

// 4 输入与
module sky130_fd_sc_hd__and4_1 (output X, input A, B, C, D);
  assign X = A & B & C & D;
  specify
    (A => X) = (0.05, 0.05);
    (B => X) = (0.05, 0.05);
    (C => X) = (0.05, 0.05);
    (D => X) = (0.05, 0.05);
  endspecify
endmodule

// 2 输入或非
module sky130_fd_sc_hd__nor2_1 (output Y, input A, B);
  assign Y = ~(A | B);
  specify
    (A => Y) = (0.05, 0.05);
    (B => Y) = (0.05, 0.05);
  endspecify
endmodule

// 异或 / 同或
module sky130_fd_sc_hd__xor2_1 (output X, input A, B);
  assign X = A ^ B;
  specify
    (A => X) = (0.05, 0.05);
    (B => X) = (0.05, 0.05);
  endspecify
endmodule
module sky130_fd_sc_hd__xnor2_1 (output Y, input A, B);
  assign Y = ~(A ^ B);
  specify
    (A => Y) = (0.05, 0.05);
    (B => Y) = (0.05, 0.05);
  endspecify
endmodule

// AOI: Y = ~((A1&A2&A3) | B1)
module sky130_fd_sc_hd__a31oi_1 (output Y, input A1, A2, A3, B1);
  assign Y = ~((A1 & A2 & A3) | B1);
  specify
    (A1 => Y) = (0.05, 0.05);
    (A2 => Y) = (0.05, 0.05);
    (A3 => Y) = (0.05, 0.05);
    (B1 => Y) = (0.05, 0.05);
  endspecify
endmodule

// 隔离缓冲：SLEEP=0 直通；SLEEP=1 输出钳到 0
module sky130_fd_sc_hd__lpflow_isobufsrc_1 (output X, input A, input SLEEP);
  assign X = SLEEP ? 1'b0 : A;
  specify
    (A => X) = (0.05, 0.05);
    (SLEEP => X) = (0.05, 0.05);
  endspecify
endmodule

// 普通缓冲：CTS 会插它做时钟树（后仿网表里才有）
module sky130_fd_sc_hd__buf_1 (output X, input A);
  assign X = A;
  specify
    (A => X) = (0.05, 0.05);
  endspecify
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
  specify
    (posedge CLK => (Q +: D)) = (0.2, 0.1);
    (negedge RESET_B => (Q +: 1'b0)) = (0.2, 0.1);
  endspecify
endmodule

`default_nettype wire
