module riscv_top (
    input clk,
    input reset
);

    // ============================================================
    // 5-STAGE PIPELINED RISC-V CORE (RV32I subset)
    //   IF -> ID -> EX -> MEM -> WB
    // ============================================================

    // ------------------------------------------------------------------
    // STAGE 1: INSTRUCTION FETCH (IF)
    // ------------------------------------------------------------------
    wire [31:0] pc_current;
    wire [31:0] pc_plus4;
    wire [31:0] pc_next;
    wire [31:0] instr;
    wire        stall;
    wire        pc_write;
    wire        if_id_write;

    assign pc_plus4 = pc_current + 32'd4;

    // PC mux: branch target (taken) or next sequential address
    assign pc_next = branch_taken ? branch_target : pc_plus4;

    pc my_pc (
        .clk(clk),
        .reset(reset),
        .pc_write(pc_write),
        .pc_next(pc_next),
        .pc_out(pc_current)
    );

    instr_mem my_instr_mem (
        .pc_addr(pc_current),
        .instruction(instr)
    );

    // ------------------------------------------------------------------
    // IF/ID PIPELINE REGISTER
    // ------------------------------------------------------------------
    wire [31:0] if_id_pc;
    wire [31:0] if_id_instr;

    if_id_reg if_id (
        .clk(clk),
        .reset(reset),
        .stall(~if_id_write),   // 1 while stalled (freeze)
        .flush(branch_taken),   // kill the wrongly-fetched instruction
        .pc_in(pc_current),
        .instr_in(instr),
        .pc_out(if_id_pc),
        .instr_out(if_id_instr)
    );

    // ------------------------------------------------------------------
    // STAGE 2: INSTRUCTION DECODE (ID)
    // ------------------------------------------------------------------
    wire reg_write, alu_src, mem_to_reg, mem_write, mem_read, branch;
    wire [3:0] alu_ctrl;
    wire [31:0] rd_data1, rd_data2;
    wire [31:0] imm_ext;

    control_unit my_control (
        .opcode(if_id_instr[6:0]),
        .funct3(if_id_instr[14:12]),
        .funct7_bit(if_id_instr[30]),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .branch(branch),
        .alu_ctrl(alu_ctrl)
    );

    reg_file my_reg_file (
        .clk(clk),
        .reset(reset),
        .rg_wren(wb_reg_write),
        .rs1(if_id_instr[19:15]),
        .rs2(if_id_instr[24:20]),
        .rd(wb_rd),
        .write_data(wb_write_data),
        .read_data1(rd_data1),
        .read_data2(rd_data2)
    );

    imm_gen my_imm_gen (
        .instr(if_id_instr),
        .imm_ext(imm_ext)
    );

    // ------------------------------------------------------------------
    // ID/EX PIPELINE REGISTER
    // Control is forced to zero on a stall so a BUBBLE enters EX.
    // ------------------------------------------------------------------
    wire        idex_reg_write, idex_mem_to_reg, idex_mem_write, idex_mem_read;
    wire        idex_branch, idex_alu_src;
    wire [3:0]  idex_alu_ctrl;
    wire [31:0] idex_pc, idex_rd1, idex_rd2, idex_imm;
    wire [4:0]  idex_rs1, idex_rs2, idex_rd;
    wire [2:0]  idex_funct3;

    id_ex_reg id_ex (
        .clk(clk),
        .reset(reset),
        .flush(branch_taken),       // kill the branch instruction itself
        .reg_write_in(reg_write & ~stall),
        .mem_to_reg_in(mem_to_reg & ~stall),
        .mem_write_in(mem_write & ~stall),
        .mem_read_in(mem_read & ~stall),
        .branch_in(branch & ~stall),
        .alu_src_in(alu_src & ~stall),
        .alu_ctrl_in(stall ? 4'b0000 : alu_ctrl),
        .pc_in(if_id_pc),
        .read_data1_in(rd_data1),
        .read_data2_in(rd_data2),
        .imm_in(imm_ext),
        .rs1_in(if_id_instr[19:15]),
        .rs2_in(if_id_instr[24:20]),
        .rd_in(if_id_instr[11:7]),
        .funct3_in(if_id_instr[14:12]),
        .reg_write(idex_reg_write),
        .mem_to_reg(idex_mem_to_reg),
        .mem_write(idex_mem_write),
        .mem_read(idex_mem_read),
        .branch(idex_branch),
        .alu_src(idex_alu_src),
        .alu_ctrl(idex_alu_ctrl),
        .pc(idex_pc),
        .read_data1(idex_rd1),
        .read_data2(idex_rd2),
        .imm(idex_imm),
        .rs1(idex_rs1),
        .rs2(idex_rs2),
        .rd(idex_rd),
        .funct3(idex_funct3)
    );

    // ------------------------------------------------------------------
    // STAGE 3: EXECUTE (EX) — forwarding, ALU mux, ALU, branch target
    // ------------------------------------------------------------------
    wire [1:0] forward_a, forward_b;
    wire [31:0] ex_mem_alu_result;
    wire [31:0] mem_wb_alu_result, mem_wb_read_data;
    wire        mem_wb_mem_to_reg;
    wire [31:0] wb_write_data;
    wire        wb_reg_write;
    wire [4:0]  wb_rd;

    forward_unit my_forward_unit (
        .id_ex_rs1(idex_rs1),
        .id_ex_rs2(idex_rs2),
        .ex_mem_rd(ex_mem_rd),
        .mem_wb_rd(mem_wb_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_reg_write(mem_wb_reg_write),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    wire [31:0] fwd_rd1 = (forward_a == 2'b10) ? ex_mem_alu_result :
                           (forward_a == 2'b01) ? wb_write_data :
                                                  idex_rd1;
    wire [31:0] fwd_rd2 = (forward_b == 2'b10) ? ex_mem_alu_result :
                           (forward_b == 2'b01) ? wb_write_data :
                                                  idex_rd2;

    // ALU source mux: register value vs. immediate
    wire [31:0] alu_operand2 = idex_alu_src ? idex_imm : fwd_rd2;

    wire [31:0] alu_result;
    wire        alu_zero;

    alu my_alu (
        .a(fwd_rd1),
        .b(alu_operand2),
        .alu_ctrl(idex_alu_ctrl),
        .result(alu_result),
        .zero(alu_zero)
    );

    // Branch target: PC of the branch + sign-extended immediate
    wire [31:0] branch_target = idex_pc + idex_imm;

    // Branch decision (predict-not-taken): taken only when the
    // branch flag is set AND the ALU comparison says equal.
    wire branch_taken = idex_branch & alu_zero;

    // ------------------------------------------------------------------
    // EX/MEM PIPELINE REGISTER
    // ------------------------------------------------------------------
    wire        ex_mem_reg_write, ex_mem_mem_to_reg, ex_mem_mem_write;
    wire        ex_mem_mem_read, ex_mem_branch;
    wire        ex_mem_zero;
    wire [31:0] ex_mem_read_data2, ex_mem_branch_target;
    wire [4:0]  ex_mem_rd;

    ex_mem_reg ex_mem (
        .clk(clk),
        .reset(reset),
        .reg_write_in(idex_reg_write),
        .mem_to_reg_in(idex_mem_to_reg),
        .mem_write_in(idex_mem_write),
        .mem_read_in(idex_mem_read),
        .branch_in(idex_branch),
        .zero_in(alu_zero),
        .alu_result_in(alu_result),
        .read_data2_in(fwd_rd2),        // store data, after forwarding
        .branch_target_in(branch_target),
        .rd_in(idex_rd),
        .reg_write(ex_mem_reg_write),
        .mem_to_reg(ex_mem_mem_to_reg),
        .mem_write(ex_mem_mem_write),
        .mem_read(ex_mem_mem_read),
        .branch(ex_mem_branch),
        .zero(ex_mem_zero),
        .alu_result(ex_mem_alu_result),
        .read_data2(ex_mem_read_data2),
        .branch_target(ex_mem_branch_target),
        .rd(ex_mem_rd)
    );

    // ------------------------------------------------------------------
    // STAGE 4: MEMORY ACCESS (MEM) — data memory
    // ------------------------------------------------------------------
    wire [31:0] mem_read_data;

    data_mem my_data_mem (
        .clk(clk),
        .mem_read(ex_mem_mem_read),
        .mem_write(ex_mem_mem_write),
        .addr(ex_mem_alu_result),
        .write_data(ex_mem_read_data2),
        .read_data(mem_read_data)
    );

    // ------------------------------------------------------------------
    // MEM/WB PIPELINE REGISTER
    // ------------------------------------------------------------------
    wire        mem_wb_reg_write;
    wire [4:0]  mem_wb_rd;

    mem_wb_reg mem_wb (
        .clk(clk),
        .reset(reset),
        .reg_write_in(ex_mem_reg_write),
        .mem_to_reg_in(ex_mem_mem_to_reg),
        .read_data_in(mem_read_data),
        .alu_result_in(ex_mem_alu_result),
        .rd_in(ex_mem_rd),
        .reg_write(mem_wb_reg_write),
        .mem_to_reg(mem_wb_mem_to_reg),
        .read_data(mem_wb_read_data),
        .alu_result(mem_wb_alu_result),
        .rd(mem_wb_rd)
    );

    // ------------------------------------------------------------------
    // STAGE 5: WRITE BACK (WB)
    // ------------------------------------------------------------------
    assign wb_write_data = mem_wb_mem_to_reg ? mem_wb_read_data : mem_wb_alu_result;
    assign wb_reg_write  = mem_wb_reg_write;
    assign wb_rd         = mem_wb_rd;

    // ------------------------------------------------------------------
    // HAZARD DETECTION (load-use stall)
    // ------------------------------------------------------------------
    hazard_unit my_hazard_unit (
        .id_ex_rd(idex_rd),
        .id_ex_mem_read(idex_mem_read),
        .if_id_rs1(if_id_instr[19:15]),
        .if_id_rs2(if_id_instr[24:20]),
        .stall(stall),
        .pc_write(pc_write),
        .if_id_write(if_id_write)
    );

endmodule
