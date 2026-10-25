# 复杂 SDC：多周期 / 假路径 / IO 预算
# 时钟 125 MHz
create_clock -name clk -period 8.0 [get_ports clk]
set_clock_uncertainty 0.10 [get_clocks clk]

# 复位异步：假路径
set_false_path -from [get_ports rst_n]

# 输出：q/tick 外部预算 1 ns
set_output_delay 1.0 -clock clk [get_ports q*]
set_output_delay 1.0 -clock clk [get_ports tick]

# 可选：tick 慢速观察口，多周期（默认注释）
# set_multicycle_path 2 -to [get_ports tick]
