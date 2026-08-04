module control_unit (
    input  [6:0] opcode,     // instr[6:0]
    input  [2:0] funct3,     // instr[14:12]
    input        funct7_bit, // instr[30]
    output reg   reg_write,  // Enables writing to Register File
    output reg   alu_src,    // 0: Selects Register 2, 1: Selects Immediate
    output reg   mem_to_reg, // 0: ALU result to Reg, 1: Data Memory to Reg
    output reg   mem_write,  // Enables writing to Data Memory
    output reg   mem_read,   // Enables reading from Data Memory
    output reg   branch,     // High for branch instructions (e.g., BEQ)
    output reg [3:0] alu_ctrl // 4-bit signal sent straight to the ALU
);

    reg [1:0] alu_op;

    // --- MAIN DECODER ---
    always @(*) begin
        case (opcode)
            7'b0110011: begin // R-type (e.g., add, sub)
                reg_write  = 1'b1;
                alu_src    = 1'b0; // Use register data 2
                mem_to_reg = 1'b0;
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                branch     = 1'b0;
                alu_op     = 2'b10; // Look at funct3/funct7
            end
            7'b0010011: begin // I-type Arithmetic (e.g., addi)
                reg_write  = 1'b1;
                alu_src    = 1'b1; // Use the immediate value
                mem_to_reg = 1'b0;
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                branch     = 1'b0;
                alu_op     = 2'b00; // Force an addition behavior
            end
            7'b0000011: begin // I-type Load (e.g., lw - load word)
                reg_write  = 1'b1;
                alu_src    = 1'b1; // Use immediate for address offset
                mem_to_reg = 1'b1; // Route memory output back to register
                mem_write  = 1'b0;
                mem_read   = 1'b1;
                branch     = 1'b0;
                alu_op     = 2'b00; // Requires address addition
            end
            7'b0100011: begin // S-type Store (e.g., sw - store word)
                reg_write  = 1'b0;
                alu_src    = 1'b1; // Use immediate for address offset
                mem_to_reg = 1'b0; // Don't care
                mem_write  = 1'b1;
                mem_read   = 1'b0;
                branch     = 1'b0;
                alu_op     = 2'b00; // Requires address addition
            end
            7'b1100011: begin // B-type Branch (e.g., beq)
                reg_write  = 1'b0;
                alu_src    = 1'b0; // Compare two registers
                mem_to_reg = 1'b0; // Don't care
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                branch     = 1'b1;
                alu_op     = 2'b01; // Requires subtraction comparison
            end
            default: begin // Default Safe State
                reg_write  = 1'b0;
                alu_src    = 1'b0;
                mem_to_reg = 1'b0;
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                branch     = 1'b0;
                alu_op     = 2'b00;
            end
        endcase
    end

    // --- ALU DECODER ---
    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000; // Force ADD (for Fetch, Loads, Stores, addi)
            2'b01: alu_ctrl = 4'b0001; // Force SUB (for Branch comparisons)
            2'b10: begin               // R-Type tracking via funct codes
                case (funct3)
                    3'b000: alu_ctrl = (funct7_bit) ? 4'b0001 : 4'b0000; // SUB if funct7 bit high, else ADD
                    3'b111: alu_ctrl = 4'b0010; // AND
                    3'b110: alu_ctrl = 4'b0011; // OR
                    3'b100: alu_ctrl = 4'b0100; // XOR
                    3'b001: alu_ctrl = 4'b0101; // SLL (Shift Left Logical)
                    3'b101: alu_ctrl = (funct7_bit) ? 4'b0111 : 4'b0110; // SRA if high, else SRL
                    3'b010: alu_ctrl = 4'b1000; // SLT (Set Less Than)
                    default: alu_ctrl = 4'b0000;
                endcase
            end
            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule