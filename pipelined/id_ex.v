module id_ex_reg (
    input             clk,
    input             reset,
    input             flush,   // 1: clear control (branch taken / bubble)

    // --- control inputs ---
    input             reg_write_in,
    input             mem_to_reg_in,
    input             mem_write_in,
    input             mem_read_in,
    input             branch_in,
    input             alu_src_in,
    input      [3:0]  alu_ctrl_in,

    // --- data inputs ---
    input      [31:0] pc_in,
    input      [31:0] read_data1_in,
    input      [31:0] read_data2_in,
    input      [31:0] imm_in,
    input      [4:0]  rs1_in,
    input      [4:0]  rs2_in,
    input      [4:0]  rd_in,
    input      [2:0]  funct3_in,

    // --- control outputs ---
    output reg        reg_write,
    output reg        mem_to_reg,
    output reg        mem_write,
    output reg        mem_read,
    output reg        branch,
    output reg        alu_src,
    output reg  [3:0] alu_ctrl,

    // --- data outputs ---
    output reg  [31:0] pc,
    output reg  [31:0] read_data1,
    output reg  [31:0] read_data2,
    output reg  [31:0] imm,
    output reg  [4:0]  rs1,
    output reg  [4:0]  rs2,
    output reg  [4:0]  rd,
    output reg  [2:0]  funct3
);

    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            reg_write  <= 1'b0;
            mem_to_reg <= 1'b0;
            mem_write  <= 1'b0;
            mem_read   <= 1'b0;
            branch     <= 1'b0;
            alu_src    <= 1'b0;
            alu_ctrl   <= 4'b0000;
            pc         <= 32'b0;
            read_data1 <= 32'b0;
            read_data2 <= 32'b0;
            imm        <= 32'b0;
            rs1        <= 5'b0;
            rs2        <= 5'b0;
            rd         <= 5'b0;
            funct3     <= 3'b000;
        end else begin
            reg_write  <= reg_write_in;
            mem_to_reg <= mem_to_reg_in;
            mem_write  <= mem_write_in;
            mem_read   <= mem_read_in;
            branch     <= branch_in;
            alu_src    <= alu_src_in;
            alu_ctrl   <= alu_ctrl_in;
            pc         <= pc_in;
            read_data1 <= read_data1_in;
            read_data2 <= read_data2_in;
            imm        <= imm_in;
            rs1        <= rs1_in;
            rs2        <= rs2_in;
            rd         <= rd_in;
            funct3     <= funct3_in;
        end
    end

endmodule
