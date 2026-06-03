`timescale 1ns / 1ps

module top_test;
    reg clk, reset, wren;
    reg [4:0] rs1, rs2, rd;
    reg [31:0] w_data;
    wire [31:0] out1, out2;

    // Instantiate Register File
    reg_file rf (
        .clk(clk), .reset(reset), .rg_wren(wren),
        .rs1(rs1), .rs2(rs2), .rd(rd),
        .write_data(w_data), .read_data1(out1), .read_data2(out2)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("reg_test.vcd");
        $dumpvars(0, top_test);
        
        clk = 0; reset = 1; wren = 0;
        #10 reset = 0;

        // Step 1: Write 32'd5 to Register x1
        rd = 5'd1; w_data = 32'd5; wren = 1;
        #10; 
        
        // Step 2: Write 32'd10 to Register x2
        rd = 5'd2; w_data = 32'd10; wren = 1;
        #10;
        
        // Step 3: Stop writing, Read x1 and x2
        wren = 0;
        rs1 = 5'd1; rs2 = 5'd2;
        #10;
        
        $display("Register x1: %d, Register x2: %d", out1, out2);
        $finish;
    end
endmodule