module counter (clk,
    rst_n,
    tick,
    q);
 input clk;
 input rst_n;
 output tick;
 output [7:0] q;

 wire _00_;
 wire _01_;
 wire _02_;
 wire _03_;
 wire _04_;
 wire _05_;
 wire clknet_0_clk;
 wire clknet_1_0__leaf_clk;
 wire clknet_1_1__leaf_clk;
 wire [0:0] _06_;
 wire [7:0] _07_;

 sky130_fd_sc_hd__clkinv_1 _08_ (.A(q[0]),
    .Y(_06_[0]));
 sky130_fd_sc_hd__nand2_1 _09_ (.A(q[0]),
    .B(q[1]),
    .Y(_00_));
 sky130_fd_sc_hd__and4_1 _10_ (.A(q[0]),
    .B(q[1]),
    .C(q[2]),
    .D(q[3]),
    .X(_01_));
 sky130_fd_sc_hd__nand2_1 _11_ (.A(q[4]),
    .B(_01_),
    .Y(_02_));
 sky130_fd_sc_hd__nand4_1 _12_ (.A(q[4]),
    .B(q[5]),
    .C(q[6]),
    .D(_01_),
    .Y(_03_));
 sky130_fd_sc_hd__lpflow_isobufsrc_1 _13_ (.A(q[7]),
    .SLEEP(_03_),
    .X(tick));
 sky130_fd_sc_hd__xor2_1 _14_ (.A(q[0]),
    .B(q[1]),
    .X(_07_[1]));
 sky130_fd_sc_hd__xnor2_1 _15_ (.A(q[2]),
    .B(_00_),
    .Y(_07_[2]));
 sky130_fd_sc_hd__a31oi_1 _16_ (.A1(q[0]),
    .A2(q[1]),
    .A3(q[2]),
    .B1(q[3]),
    .Y(_04_));
 sky130_fd_sc_hd__nor2_1 _17_ (.A(_01_),
    .B(_04_),
    .Y(_07_[3]));
 sky130_fd_sc_hd__xor2_1 _18_ (.A(q[4]),
    .B(_01_),
    .X(_07_[4]));
 sky130_fd_sc_hd__xnor2_1 _19_ (.A(q[5]),
    .B(_02_),
    .Y(_07_[5]));
 sky130_fd_sc_hd__a31oi_1 _20_ (.A1(q[4]),
    .A2(q[5]),
    .A3(_01_),
    .B1(q[6]),
    .Y(_05_));
 sky130_fd_sc_hd__lpflow_isobufsrc_1 _21_ (.A(_03_),
    .SLEEP(_05_),
    .X(_07_[6]));
 sky130_fd_sc_hd__xnor2_1 _22_ (.A(q[7]),
    .B(_03_),
    .Y(_07_[7]));
 sky130_fd_sc_hd__dfrtp_1 _23_ (.CLK(clknet_1_1__leaf_clk),
    .D(_06_[0]),
    .RESET_B(rst_n),
    .Q(q[0]));
 sky130_fd_sc_hd__dfrtp_1 _24_ (.CLK(clknet_1_1__leaf_clk),
    .D(_07_[1]),
    .RESET_B(rst_n),
    .Q(q[1]));
 sky130_fd_sc_hd__dfrtp_1 _25_ (.CLK(clknet_1_1__leaf_clk),
    .D(_07_[2]),
    .RESET_B(rst_n),
    .Q(q[2]));
 sky130_fd_sc_hd__dfrtp_1 _26_ (.CLK(clknet_1_1__leaf_clk),
    .D(_07_[3]),
    .RESET_B(rst_n),
    .Q(q[3]));
 sky130_fd_sc_hd__dfrtp_1 _27_ (.CLK(clknet_1_0__leaf_clk),
    .D(_07_[4]),
    .RESET_B(rst_n),
    .Q(q[4]));
 sky130_fd_sc_hd__dfrtp_1 _28_ (.CLK(clknet_1_0__leaf_clk),
    .D(_07_[5]),
    .RESET_B(rst_n),
    .Q(q[5]));
 sky130_fd_sc_hd__dfrtp_1 _29_ (.CLK(clknet_1_0__leaf_clk),
    .D(_07_[6]),
    .RESET_B(rst_n),
    .Q(q[6]));
 sky130_fd_sc_hd__dfrtp_1 _30_ (.CLK(clknet_1_0__leaf_clk),
    .D(_07_[7]),
    .RESET_B(rst_n),
    .Q(q[7]));
 sky130_fd_sc_hd__buf_1 clkbuf_0_clk (.A(clk),
    .X(clknet_0_clk));
 sky130_fd_sc_hd__buf_1 clkbuf_1_0__f_clk (.A(clknet_0_clk),
    .X(clknet_1_0__leaf_clk));
 sky130_fd_sc_hd__buf_1 clkbuf_1_1__f_clk (.A(clknet_0_clk),
    .X(clknet_1_1__leaf_clk));
endmodule
