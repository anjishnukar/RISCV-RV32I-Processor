module riscv_top (
    input clk,
    input reset
);

    // Internal Wires
    wire [31:0] pc_current;
    wire [31:0] pc_next;
    wire [31:0] instr;
    
    // Control Signals
    wire reg_write, alu_src, mem_to_reg, mem_write, mem_read, branch;
    wire [3:0] alu_ctrl;
    
    // Data Wires
    wire [31:0] rd_data1, rd_data2;
    wire [31:0] imm_ext;
    wire [31:0] alu_operand2;
    wire [31:0] alu_result;
    wire alu_zero;

    // 1. Program Counter Logic (Simple incremental for now: PC = PC + 4)
    assign pc_next = pc_current + 32'd4;
    
    pc my_pc (
        .clk(clk),
        .reset(reset),
        .pc_next(pc_next),
        .pc_out(pc_current)
    );

    // 2. Instruction Fetch
    instr_mem my_instr_mem (
        .pc_addr(pc_current),
        .instruction(instr)
    );

    // 3. Control Unit
    control_unit my_control (
        .opcode(instr[6:0]),
        .funct3(instr[14:12]),
        .funct7_bit(instr[30]),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .branch(branch),
        .alu_ctrl(alu_ctrl)
    );

    // 4. Register File
    reg_file my_reg_file (
        .clk(clk),
        .reset(reset),
        .rg_wren(reg_write),
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd(instr[11:7]),
        .write_data(alu_result), // Direct loopback for single-cycle ALU execution
        .read_data1(rd_data1),
        .read_data2(rd_data2)
    );

    // 5. Immediate Generator
    imm_gen my_imm_gen (
        .instr(instr),
        .imm_ext(imm_ext)
    );

    // 6. ALU Source Multiplexer (MUX)
    // If alu_src is 1, select immediate. If 0, select register data 2.
    assign alu_operand2 = (alu_src) ? imm_ext : rd_data2;

    // 7. Execution Engine (ALU)
    alu my_alu (
        .a(rd_data1),
        .b(alu_operand2),
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(alu_zero)
    );

endmodule