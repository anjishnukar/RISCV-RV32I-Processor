module ex_mem_reg (
    input             clk,
    input             reset,

    // --- control inputs ---
    input             reg_write_in,
    input             mem_to_reg_in,
    input             mem_write_in,
    input             mem_read_in,
    input             branch_in,

    // --- data inputs ---
    input             zero_in,
    input      [31:0] alu_result_in,
    input      [31:0] read_data2_in,
    input      [31:0] branch_target_in,
    input      [4:0]  rd_in,

    // --- control outputs ---
    output reg        reg_write,
    output reg        mem_to_reg,
    output reg        mem_write,
    output reg        mem_read,
    output reg        branch,

    // --- data outputs ---
    output reg        zero,
    output reg  [31:0] alu_result,
    output reg  [31:0] read_data2,
    output reg  [31:0] branch_target,
    output reg  [4:0]  rd
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_write     <= 1'b0;
            mem_to_reg    <= 1'b0;
            mem_write     <= 1'b0;
            mem_read      <= 1'b0;
            branch        <= 1'b0;
            zero          <= 1'b0;
            alu_result    <= 32'b0;
            read_data2    <= 32'b0;
            branch_target <= 32'b0;
            rd            <= 5'b0;
        end else begin
            reg_write     <= reg_write_in;
            mem_to_reg    <= mem_to_reg_in;
            mem_write     <= mem_write_in;
            mem_read      <= mem_read_in;
            branch        <= branch_in;
            zero          <= zero_in;
            alu_result    <= alu_result_in;
            read_data2    <= read_data2_in;
            branch_target <= branch_target_in;
            rd            <= rd_in;
        end
    end

endmodule
