module mem_wb_reg (
    input             clk,
    input             reset,

    // --- control inputs ---
    input             reg_write_in,
    input             mem_to_reg_in,

    // --- data inputs ---
    input      [31:0] read_data_in,
    input      [31:0] alu_result_in,
    input      [4:0]  rd_in,

    // --- control outputs ---
    output reg        reg_write,
    output reg        mem_to_reg,

    // --- data outputs ---
    output reg  [31:0] read_data,
    output reg  [31:0] alu_result,
    output reg  [4:0]  rd
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_write  <= 1'b0;
            mem_to_reg <= 1'b0;
            read_data  <= 32'b0;
            alu_result <= 32'b0;
            rd         <= 5'b0;
        end else begin
            reg_write  <= reg_write_in;
            mem_to_reg <= mem_to_reg_in;
            read_data  <= read_data_in;
            alu_result <= alu_result_in;
            rd         <= rd_in;
        end
    end

endmodule
