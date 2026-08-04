module data_mem (
    input             clk,
    input             mem_read,   // enable read (load)
    input             mem_write,  // enable write (store)
    input      [31:0] addr,       // word address from ALU
    input      [31:0] write_data, // data to store (rt2 value)
    output reg  [31:0] read_data  // data loaded
);
    reg [31:0] mem [0:63];        // 64 words = 256 bytes data memory
    integer i;

    initial begin
        for (i = 0; i < 64; i = i + 1) mem[i] = 32'b0;
    end

    // Synchronous write: stores commit on the rising clock edge
    always @(posedge clk) begin
        if (mem_write) mem[addr[7:2]] <= write_data;
    end

    // Combinational read: value available during the MEM stage
    always @(*) begin
        read_data = mem[addr[7:2]];
    end

endmodule
