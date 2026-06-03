module instr_mem (
    input  [31:0] pc_addr,
    output [31:0] instruction
);
    reg [31:0] mem [0:255];  // 256 words = 1KB instruction memory
    
    assign instr = mem[pc_addr[9:2]]; // word-aligned: drop bottom 2 bits
    
    initial begin
        $readmemh("instr_mem.txt", mem); // load from hex file
    end
endmodule