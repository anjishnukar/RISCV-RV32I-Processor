module instr_mem (
    input  [31:0] pc_addr,
    output [31:0] instruction
);
    reg [31:0] mem [0:15];   // 16 words = 64 bytes instruction memory
    
    assign instruction = mem[pc_addr[5:2]]; // word-aligned: drop bottom 2 bits
    
    initial begin
        $readmemh("instr_mem.txt", mem); // load from hex file
    end
endmodule