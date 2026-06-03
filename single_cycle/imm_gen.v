module imm_gen (
    input  [31:0] instr,    // The raw 32-bit instruction
    output reg [31:0] imm_ext  // The sign-extended 32-bit immediate
);

    always @(*) begin
        case (instr[6:0])
            7'b0010011: begin // I-type Arithmetic (addi, etc.)
                imm_ext = {{20{instr[31]}}, instr[31:20]};
            end
            7'b0000011: begin // I-type Load (lw)
                imm_ext = {{20{instr[31]}}, instr[31:20]};
            end
            7'b0100011: begin // S-type Store (sw)
                imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end
            7'b1100011: begin // B-type Branch (beq)
                imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            end
            default: begin
                imm_ext = 32'b0; // Default fallback
            end
        endcase
    end

endmodule