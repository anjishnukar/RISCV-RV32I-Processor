module hazard_unit (
    input        [4:0] id_ex_rd,      // destination of instruction in EX
    input              id_ex_mem_read, // is the EX instruction a load?
    input        [4:0] if_id_rs1,     // source regs of instruction in ID
    input        [4:0] if_id_rs2,
    output reg         stall,          // 1: freeze PC + IF/ID, bubble ID/EX
    output reg         pc_write,       // PC write enable
    output reg         if_id_write     // IF/ID register write enable
);

    always @(*) begin
        // Load-use hazard: the load in EX writes rd, and the instruction
        // in ID reads that same register -> its ALU input is not ready.
        if (id_ex_mem_read && (id_ex_rd != 5'b0) &&
            (id_ex_rd == if_id_rs1 || id_ex_rd == if_id_rs2)) begin
            stall      = 1'b1;
            pc_write   = 1'b0;
            if_id_write = 1'b0;
        end else begin
            stall      = 1'b0;
            pc_write   = 1'b1;
            if_id_write = 1'b1;
        end
    end

endmodule
