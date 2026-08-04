module pc (
    input             clk,
    input             reset,
    input             pc_write, // 0: hold the PC (stall)
    input      [31:0] pc_next,  // Next instruction address (from branch/adder logic)
    output reg [31:0] pc_out    // Current instruction address
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= 32'b0;    // Reset vector: Start execution at address 0
        end else if (pc_write) begin
            pc_out <= pc_next;   // Update to the next program address
        end
    end

endmodule
