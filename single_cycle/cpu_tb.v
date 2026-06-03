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

        // Run long enough to loop through your program.txt file
        #100;
        
        $display("--- Execution Simulation Complete ---");
        $finish;
    end
endmodule