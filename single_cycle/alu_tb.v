`timescale 1ns / 1ps

module alu_tb;
    reg  [31:0] a, b;
    reg  [3:0]  ctrl;
    wire [31:0] res;
    wire        z;

    // Instantiate the ALU
    alu uut (
        .a(a), .b(b), .alu_ctrl(ctrl), .result(res), .zero(z)
    );

    initial begin
        // For GTKWave viewing
        $dumpfile("alu_test.vcd");
        $dumpvars(0, alu_tb);

        // Test 1: Addition (5 + 10)
        a = 32'd5; b = 32'd10; ctrl = 4'b0000;
        #10; $display("ADD: %d + %d = %d", a, b, res);

        // Test 2: Subtraction (20 - 7)
        a = 32'd20; b = 32'd7; ctrl = 4'b0001;
        #10; $display("SUB: %d - %d = %d", a, b, res);

        // Test 3: Logical AND (0xFFFF0000 & 0x00FFFF00)
        a = 32'hFFFF0000; b = 32'h00FFFF00; ctrl = 4'b0010;
        #10; $display("AND: %h & %h = %h", a, b, res);

        // Test 4: Shift Left (1 << 4)
        a = 32'd1; b = 32'd4; ctrl = 4'b0101;
        #10; $display("SLL: %d << %d = %d", a, b, res);

        $finish;
    end
endmodule