# 时序约束：10 MHz 时钟（100 ns 周期）—— 先跑通，再收紧
# 125 MHz（8 ns）—— SPEF+ss 留余量；tt 极限约 667 MHz，见 runs/18_p7
create_clock -name clk -period 8.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]
set_input_delay  2.0 -clock clk [get_ports rst_n]
set_output_delay 2.0 -clock clk [get_ports q*]
set_output_delay 2.0 -clock clk [get_ports tick]
