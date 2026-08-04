module forward_unit (
    input        [4:0] id_ex_rs1,      // ALU source 1 register
    input        [4:0] id_ex_rs2,      // ALU source 2 register
    input        [4:0] ex_mem_rd,      // dest of instr in MEM
    input        [4:0] mem_wb_rd,      // dest of instr in WB
    input              ex_mem_reg_write, // does the MEM instr write a reg?
    input              mem_wb_reg_write, // does the WB instr write a reg?
    output reg   [1:0] forward_a,      // select for ALU input A
    output reg   [1:0] forward_b       // select for ALU input B
);

    // 00 = no forwarding (use value read from register file)
    // 10 = forward from EX/MEM pipeline register (1-stage-old result)
    // 01 = forward from MEM/WB pipeline register (2-stage-old result)

    always @(*) begin
        // --- ALU input A (rs1) ---
        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;          // newest producer wins
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // --- ALU input B (rs2) ---
        if (ex_mem_reg_write && (ex_mem_rd != 5'b0) && (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'b0) && (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end

endmodule
