`timescale 1ns / 1ps

module cpu_tb;
    reg clk;
    reg reset;

    // Instantiate your complete processor core
    riscv_top uut (
        .clk(clk),
        .reset(reset)
    );

    // Generate Clock (50MHz frequency -> 20ns period)
    always #10 clk = ~clk;

    initial begin
        // Setup GTKWave trace files
        $dumpfile("cpu_execution.vcd");
        $dumpvars(0, cpu_tb);

        // Assert System Reset to force starting state
        clk = 0; reset = 1;
        #25;

        // Release Reset to begin instruction execution loop
        reset = 0;

        // Run long enough for all instructions to drain through the pipeline
        // (~15 instructions + 2 load-use stalls + branch flush = ~40 cycles)
        #400;

        $display("--- Execution Simulation Complete ---");

        // Print final register file values (hierarchical reference into UUT)
        $display("x1  = %0d  (expect 5)",   uut.my_reg_file.registers[1]);
        $display("x2  = %0d  (expect 10)",  uut.my_reg_file.registers[2]);
        $display("x3  = %0d  (expect 15)",  uut.my_reg_file.registers[3]);
        $display("x5  = %0d  (expect 5)",   uut.my_reg_file.registers[5]);
        $display("x6  = %0d  (expect 15)",  uut.my_reg_file.registers[6]);
        $display("x7  = %0d  (expect 99)",  uut.my_reg_file.registers[7]);
        $display("x8  = %0d  (expect 0, flushed instructions)", uut.my_reg_file.registers[8]);
        $display("x9  = %0d  (expect 114)", uut.my_reg_file.registers[9]);
        $display("x10 = %0d  (expect 115)", uut.my_reg_file.registers[10]);

        // Print final data memory values
        $display("mem[0] = %0d  (expect 5)",   uut.my_data_mem.mem[0]);
        $display("mem[1] = %0d  (expect 114)", uut.my_data_mem.mem[1]);

        $finish;
    end
endmodule
