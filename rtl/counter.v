// 最小可综合计数器 —— 用来走通 RTL→GDS 每一步
// 8-bit 自由跑计数器，同步复位
module counter (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [7:0] q,
    output wire       tick   // 计满一圈的脉冲
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 8'd0;
        else
            q <= q + 8'd1;
    end

    assign tick = (q == 8'hFF);
endmodule
