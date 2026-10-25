// counter_tb — 自检 testbench：功能正确性
// 期望：
//   1) 复位后 q=0
//   2) 每个时钟 q 递增 1
//   3) q==0xFF 时 tick=1，其余 tick=0
//   4) 一圈 256 个时钟后 tick 再次为 1
//
// 后仿：用 +SDF=<file> 传入 SDF，或编译时 -DSDF 并放在当前目录的 counter.sdf。
// 带延迟后输出不会在时钟沿立刻稳定，所以采样时间用 SETTLE 控制（默认 1ns）。
`timescale 1ns/1ps
module counter_tb;
    reg clk = 0;
    reg rst_n = 0;
    wire [7:0] q;
    wire tick;

    counter dut (.clk(clk), .rst_n(rst_n), .q(q), .tick(tick));

    always #50 clk = ~clk;   // 100ns 周期，与 SDC 一致

`ifdef SDF
    `define SETTLE 20
    reg [1023:0] sdf_file;
    initial begin
        if (!$value$plusargs("SDF=%s", sdf_file))
            sdf_file = "counter.sdf";
        $display("SDF annotate: %0s", sdf_file);
        $sdf_annotate(sdf_file, dut);
    end
`else
    `define SETTLE 1
`endif

    integer errors = 0;
    integer i;
    reg [7:0] expect_q;
    reg       expect_tick;

    task check;
        input [255:0] msg;
        begin
            if (q !== expect_q || tick !== expect_tick) begin
                $display("FAIL @%0t %0s : q=%0d(exp %0d) tick=%b(exp %b)",
                         $time, msg, q, expect_q, tick, expect_tick);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // 复位
        rst_n = 0;
        @(negedge clk);
        @(negedge clk);
        expect_q = 8'd0; expect_tick = 1'b0;
        check("after reset");
        rst_n = 1;

        // 跑满 256 个时钟，每步校验
        expect_q = 8'd0;
        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clk);
            #(`SETTLE); // 等非阻塞赋值（后仿还要等门延迟）
            expect_q = expect_q + 8'd1;
            expect_tick = (expect_q == 8'hFF);
            check("count step");
        end

        // 再多跑一圈，确认 tick 周期性
        @(posedge clk); #(`SETTLE);
        expect_q = 8'd01; expect_tick = 1'b0;
        check("wrap around");

        if (errors == 0)
            $display("PASS: all checks OK (256+ steps)");
        else
            $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
