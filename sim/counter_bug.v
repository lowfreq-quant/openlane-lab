// counter_bug.v — 故意引入 3 个典型 bug，用于验证 testbench 有效性
// Bug1: 复位值改成 1（应为 0）
// Bug2: 递增加 2（应为 +1）
// Bug3: tick 条件改成 0xFE（应为 0xFF）
// 用 MUTATION 宏选择注入哪个 bug
module counter (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [7:0] q,
    output wire       tick
);
`ifdef BUG_RESET
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 8'd1;          // BUG1
        else        q <= q + 8'd1;
    end
`elsif BUG_STEP
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 8'd0;
        else        q <= q + 8'd2;      // BUG2
    end
`elsif BUG_TICK
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 8'd0;
        else        q <= q + 8'd1;
    end
    assign tick = (q == 8'hFE);         // BUG3
`else
    // 正确版本
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 8'd0;
        else        q <= q + 8'd1;
    end
    assign tick = (q == 8'hFF);
`endif

`ifdef BUG_RESET
    assign tick = (q == 8'hFF);
`elsif BUG_STEP
    assign tick = (q == 8'hFF);
`endif
endmodule
