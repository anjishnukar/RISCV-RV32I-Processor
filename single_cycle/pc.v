module pc (
    input             clk,
    input             reset,
    input      [31:0] pc_next,  // Next instruction address (from adder/branch logic)
    output reg [31:0] pc_out    // Current instruction address
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out <= 32'b0;    // Reset vector: Start execution at address 0
        end else begin
            pc_out <= pc_next;   // Update to the next program address
        end
    end

endmodule