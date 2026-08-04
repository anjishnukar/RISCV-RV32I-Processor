module if_id_reg (
    input             clk,
    input             reset,
    input             stall,   // 1: hold values (load-use stall)
    input             flush,   // 1: insert a bubble (branch taken)
    input      [31:0] pc_in,   // current instruction address (from IF)
    input      [31:0] instr_in,// fetched instruction
    output reg [31:0] pc_out,  // instruction address (used by ID)
    output reg [31:0] instr_out // instruction being decoded
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out    <= 32'b0;
            instr_out <= 32'b0;
        end else if (flush) begin
            // Bubble: zero instruction decodes as a harmless no-op
            pc_out    <= 32'b0;
            instr_out <= 32'b0;
        end else if (!stall) begin
            pc_out    <= pc_in;
            instr_out <= instr_in;
        end
        // if stalled: hold both registers (do nothing)
    end

endmodule
