module reg_file (
    input             clk,
    input             reset,
    input             rg_wren,      // Write Enable: 1 to write data
    input      [4:0]  rs1, rs2, rd, // Addresses for Source 1, Source 2, and Destination
    input      [31:0] write_data,   // Data to be stored in 'rd'
    output     [31:0] read_data1,   // Data output from 'rs1'
    output     [31:0] read_data2    // Data output from 'rs2'
);

    // Declare 32 registers of 32-bit width
    reg [31:0] registers [31:0];
    integer i;

    // Async Read: ALU gets data instantly when rs1/rs2 addresses change
    assign read_data1 = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
    assign read_data2 = (rs2 == 5'b0) ? 32'b0 : registers[rs2];

    // Synchronous Write: Data is stored only on the Rising Edge of the clock
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else begin
            // Write to rd if wren is high AND rd is not x0
            if (rg_wren && (rd != 5'b0)) begin
                registers[rd] <= write_data;
            end
        end
    end

endmodule
