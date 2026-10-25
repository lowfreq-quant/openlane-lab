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

 sky130_fd_sc_hd__decap_12 FILLER_0_0 ();
 sky130_fd_sc_hd__decap_3 FILLER_0_12 ();
 sky130_fd_sc_hd__fill_1 FILLER_0_22 ();
 sky130_fd_sc_hd__decap_12 FILLER_0_29 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_41 ();
 sky130_fd_sc_hd__fill_2 FILLER_0_49 ();
 sky130_fd_sc_hd__decap_12 FILLER_0_57 ();
 sky130_fd_sc_hd__decap_8 FILLER_0_69 ();
 sky130_fd_sc_hd__decap_12 FILLER_10_0 ();
 sky130_fd_sc_hd__decap_12 FILLER_10_12 ();
 sky130_fd_sc_hd__decap_4 FILLER_10_24 ();
 sky130_fd_sc_hd__decap_12 FILLER_10_29 ();
 sky130_fd_sc_hd__decap_12 FILLER_10_41 ();
 sky130_fd_sc_hd__decap_12 FILLER_10_53 ();
 sky130_fd_sc_hd__decap_12 FILLER_10_65 ();
 sky130_fd_sc_hd__decap_12 FILLER_11_0 ();
 sky130_fd_sc_hd__decap_12 FILLER_11_12 ();
 sky130_fd_sc_hd__decap_4 FILLER_11_24 ();
 sky130_fd_sc_hd__decap_12 FILLER_11_29 ();
 sky130_fd_sc_hd__decap_12 FILLER_11_41 ();
 sky130_fd_sc_hd__decap_3 FILLER_11_53 ();
 sky130_fd_sc_hd__decap_12 FILLER_11_57 ();
 sky130_fd_sc_hd__decap_8 FILLER_11_69 ();
 sky130_fd_sc_hd__decap_6 FILLER_1_0 ();
 sky130_fd_sc_hd__decap_12 FILLER_1_34 ();
 sky130_fd_sc_hd__fill_1 FILLER_1_6 ();
 sky130_fd_sc_hd__decap_3 FILLER_2_0 ();
 sky130_fd_sc_hd__decap_4 FILLER_2_36 ();
 sky130_fd_sc_hd__decap_4 FILLER_2_73 ();
 sky130_fd_sc_hd__decap_4 FILLER_3_0 ();
 sky130_fd_sc_hd__decap_4 FILLER_3_41 ();
 sky130_fd_sc_hd__fill_1 FILLER_3_45 ();
 sky130_fd_sc_hd__decap_3 FILLER_3_7 ();
 sky130_fd_sc_hd__decap_8 FILLER_4_0 ();
 sky130_fd_sc_hd__decap_12 FILLER_4_29 ();
 sky130_fd_sc_hd__decap_6 FILLER_4_41 ();
 sky130_fd_sc_hd__fill_1 FILLER_4_47 ();
 sky130_fd_sc_hd__decap_8 FILLER_4_68 ();
 sky130_fd_sc_hd__fill_1 FILLER_4_76 ();
 sky130_fd_sc_hd__decap_12 FILLER_5_0 ();
 sky130_fd_sc_hd__decap_8 FILLER_5_12 ();
 sky130_fd_sc_hd__fill_1 FILLER_5_20 ();
 sky130_fd_sc_hd__decap_12 FILLER_5_26 ();
 sky130_fd_sc_hd__decap_12 FILLER_5_38 ();
 sky130_fd_sc_hd__decap_6 FILLER_5_50 ();
 sky130_fd_sc_hd__decap_12 FILLER_5_57 ();
 sky130_fd_sc_hd__decap_8 FILLER_5_69 ();
 sky130_fd_sc_hd__decap_12 FILLER_6_0 ();
 sky130_fd_sc_hd__decap_12 FILLER_6_12 ();
 sky130_fd_sc_hd__decap_4 FILLER_6_24 ();
 sky130_fd_sc_hd__decap_12 FILLER_6_29 ();
 sky130_fd_sc_hd__decap_12 FILLER_6_41 ();
 sky130_fd_sc_hd__decap_12 FILLER_6_53 ();
 sky130_fd_sc_hd__decap_12 FILLER_6_65 ();
 sky130_fd_sc_hd__decap_12 FILLER_7_0 ();
 sky130_fd_sc_hd__decap_12 FILLER_7_12 ();
 sky130_fd_sc_hd__decap_12 FILLER_7_24 ();
 sky130_fd_sc_hd__decap_12 FILLER_7_36 ();
 sky130_fd_sc_hd__decap_8 FILLER_7_48 ();
 sky130_fd_sc_hd__decap_12 FILLER_7_57 ();
 sky130_fd_sc_hd__decap_8 FILLER_7_69 ();
 sky130_fd_sc_hd__decap_12 FILLER_8_0 ();
 sky130_fd_sc_hd__decap_12 FILLER_8_12 ();
 sky130_fd_sc_hd__decap_4 FILLER_8_24 ();
 sky130_fd_sc_hd__decap_12 FILLER_8_29 ();
 sky130_fd_sc_hd__decap_12 FILLER_8_41 ();
 sky130_fd_sc_hd__decap_12 FILLER_8_53 ();
 sky130_fd_sc_hd__decap_12 FILLER_8_65 ();
 sky130_fd_sc_hd__decap_12 FILLER_9_0 ();
 sky130_fd_sc_hd__decap_12 FILLER_9_12 ();
 sky130_fd_sc_hd__decap_12 FILLER_9_24 ();
 sky130_fd_sc_hd__decap_12 FILLER_9_36 ();
 sky130_fd_sc_hd__decap_8 FILLER_9_48 ();
 sky130_fd_sc_hd__decap_12 FILLER_9_57 ();
 sky130_fd_sc_hd__decap_8 FILLER_9_69 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_0_0 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_0_1 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_10_11 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_11_12 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_11_13 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_1_2 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_2_3 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_3_4 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_4_5 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_5_6 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_6_7 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_7_8 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_8_9 ();
 sky130_fd_sc_hd__tapvpwrvgnd_1 TAP_TAPCELL_ROW_9_10 ();
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
