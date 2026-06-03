`timescale 1ns / 1ps

module fetch_tb;
    reg clk;
    reg reset;
    wire [31:0] current_pc;
    wire [31:0] next_pc;
    wire [31:0] instr;

    // Instantiate PC
    pc my_pc (
        .clk(clk), .reset(reset), .pc_next(next_pc), .pc_out(current_pc)
    );

    // Instantiate Instruction Memory
    instr_mem my_mem (
        .pc_addr(current_pc), .instruction(instr)
    );

    // Simple single-cycle calculation: Next PC is always Current PC + 4
    assign next_pc = current_pc + 32'd4;

    // Clock generator (10ns period)
    always #5 clk = ~clk;

    initial begin
        $dumpfile("fetch_test.vcd");
        $dumpvars(0, fetch_tb);

        clk = 0; reset = 1;
        #12 reset = 0; // Release reset just after a clock edge

        #40; // Let it run for 4 clock cycles to pull instructions
        $finish;
    end
endmodule