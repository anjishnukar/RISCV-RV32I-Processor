# Single-Cycle RISC-V Processor

This folder contains a **single-cycle** implementation of a subset of the RISC-V (RV32I) instruction set architecture, written in **Verilog** (a hardware description language used to design digital circuits). Every instruction takes exactly **one clock cycle** to execute from start to finish.

## Big-Picture Analogy

Imagine a factory assembly line where a single worker does every step of building a product before the next product enters the line. That is a single-cycle processor: one instruction is fetched, decoded, executed, and its results are written back all within one tick of the clock. This is simple to understand but slow, because the clock speed is limited by the slowest instruction (every instruction has to wait for the longest possible path to finish).

## What Is RV32I?

RISC-V is an open-source instruction set architecture (ISA) — a standardized list of commands a CPU understands. RV32I is the 32-bit integer base variant. The "32" means it works with 32-bit-wide data and addresses. Instructions are also 32 bits wide.

Each 32-bit instruction is divided into **fields** that encode:
- The **opcode** (what kind of operation, e.g., arithmetic, load, store, branch)
- One or more **register addresses** (RISC-V has 32 general-purpose registers, each holding 32 bits, numbered x0 through x31; x0 is hardwired to zero)
- A **function code** (`funct3` and `funct7`) that refines the operation (e.g., ADD vs SUB)
- An **immediate value** (a constant embedded in the instruction itself)

## How the Processor Works, Step by Step

The processor is built from several **modules** (Verilog's word for a hardware component). They are wired together in `riscv_top.v`. Here is the flow every instruction follows:

### 1. Program Counter (`pc.v`)

The PC is a 32-bit register (a memory cell that holds a value) storing the **memory address of the current instruction**. On every rising edge of the clock, it updates to the next address. On reset, it starts at address 0.

### 2. Instruction Memory (`instr_mem.v` + `instr_mem.txt`)

The instruction memory is an array of 256 32-bit words (1 KB total). It takes the PC's address and outputs the 32-bit instruction stored there. The instructions are loaded from the text file `instr_mem.txt` at the start of simulation.

### 3. Control Unit (`control.v`)

The control unit looks at the instruction's **opcode** (bits 6:0) and decides what every other component should do. It has two sub-parts:

- **Main Decoder** — decodes the opcode to produce control signals:
  - `reg_write`: should we write a result into the register file?
  - `alu_src`: should the ALU's second input come from a register or from an immediate value?
  - `mem_write` / `mem_read`: are we writing to or reading from memory?
  - `branch`: is this a branch instruction?
  - `alu_op`: a 2-bit code that tells the ALU decoder what to do

- **ALU Decoder** — takes `alu_op` plus `funct3` and `funct7` bits to produce a precise 4-bit `alu_ctrl` signal:
  - `0000` = ADD, `0001` = SUB, `0010` = AND, `0011` = OR, `0100` = XOR
  - `0101` = shift left logical (SLL), `0110` = shift right logical (SRL)
  - `0111` = shift right arithmetic (SRA), `1000` = set less than (SLT)

### 4. Register File (`reg_file.v`)

The register file holds the 32 general-purpose registers (x0–x31). It provides two **asynchronous** reads (data appears immediately when an address changes) and one **synchronous** write (data is stored only on a clock edge). Register x0 is hardwired to always return 0, matching the RISC-V spec.

### 5. Immediate Generator (`imm_gen.v`)

Many RISC-V instructions embed a constant (immediate) inside the instruction word itself. The format varies by instruction type:
- **I-type** (arithmetic immediates, loads): immediate is bits [31:20], sign-extended to 32 bits
- **S-type** (stores): immediate is split across bits [31:25] and [11:7], sign-extended
- **B-type** (branches): immediate is scattered across bits [31], [7], [30:25], [11:8], plus a trailing 0

All immediates are **sign-extended** — the top bit of the immediate field (bit 31 of the instruction) is copied into the upper bits to preserve negative values.

### 6. ALU Source MUX

A multiplexer (a selector circuit) chooses the ALU's second operand:
- If `alu_src = 0`, use the value from register rs2
- If `alu_src = 1`, use the sign-extended immediate

### 7. ALU — Arithmetic Logic Unit (`alu.v`)

The ALU performs the actual computation. It takes two 32-bit inputs and a 4-bit control signal, and outputs a 32-bit result plus a `zero` flag (high when the result is zero). Supported operations: ADD, SUB, AND, OR, XOR, shift left/right logical, shift right arithmetic, and set-less-than.

### 8. (Future) Data Memory

The current implementation computes addresses and results but does not yet include a data memory module for loads and stores. The `mem_write`, `mem_read`, and `mem_to_reg` signals are defined in the controller and ready to be wired to a data memory when one is added.

## Supported Instruction Types

| Type        | Opcode    | Examples        | Description                              |
|-------------|-----------|-----------------|------------------------------------------|
| R-type      | `0110011` | add, sub, and   | Two register sources, one register dest  |
| I-type      | `0010011` | addi            | One register + immediate, register dest  |
| Load (I)    | `0000011` | lw              | Load from memory address to register     |
| Store (S)   | `0100011` | sw              | Store register value to memory address   |
| Branch (B)  | `1100011` | beq             | Compare two registers, conditionally jump|

## The Test Program (`instr_mem.txt`)

```
00500093   // addi x1, x0, 5   → x1 = 5
00A00113   // addi x2, x0, 10  → x2 = 10
002081B3   // add  x3, x1, x2  → x3 = x1 + x2 = 15
00000000   // (padding / no-op)
```

This program:
1. Loads 5 into register x1
2. Loads 10 into register x2
3. Adds x1 and x2, storing the result (15) in x3

## Testbenches (How We Verify It Works)

Verilog testbenches are programs that simulate the hardware to check for correctness. They are not synthesizable — they exist only for testing.

| File          | What It Tests                                        |
|---------------|------------------------------------------------------|
| `cpu_tb.v`    | The full CPU (`riscv_top`) — runs the test program   |
| `alu_tb.v`    | The ALU in isolation — checks add, sub, and, sll     |
| `fetch_tb.v`  | PC + instruction memory together — verifies fetch    |
| `reg_test.v`  | Register file read/write behavior                    |

Each testbench:
- Generates a clock signal (usually 10–20ns period)
- Applies reset, then releases it
- Feeds in stimulus (input values) and displays / logs results
- Dumps a `.vcd` file (Value Change Dump) that can be viewed with **GTKWave** to see waveforms

## How to Simulate

These instructions assume you have **Icarus Verilog (iverilog)** installed.

```powershell
# Simulate the full CPU
iverilog -o riscv_core_sim riscv_top.v pc.v instr_mem.v control.v reg_file.v imm_gen.v alu.v cpu_tb.v
vvp riscv_core_sim

# View waveforms (open the .vcd file in GTKWave)
gtkwave cpu_execution.vcd
```

The same pattern works for the individual testbenches.

## File Reference

| File              | Purpose                                               |
|-------------------|-------------------------------------------------------|
| `riscv_top.v`     | Top-level module — wires all components together      |
| `pc.v`            | Program Counter register                              |
| `instr_mem.v`     | Instruction memory (ROM, loaded from text file)       |
| `instr_mem.txt`   | Hex-encoded program to execute                        |
| `control.v`       | Main controller (decodes opcodes, generates signals)  |
| `reg_file.v`      | Register file (32 × 32-bit registers)                 |
| `imm_gen.v`       | Immediate value generator (sign-extends immediates)   |
| `alu.v`           | ALU — performs arithmetic and logic operations        |
| `cpu_tb.v`        | Testbench for the full CPU                            |
| `alu_tb.v`        | Testbench for the ALU                                 |
| `fetch_tb.v`      | Testbench for the instruction fetch stage             |
| `reg_test.v`      | Testbench for the register file                       |
| `*.vcd`           | Waveform dump files (simulation output, viewable in GTKWave) |
| `*_sim`           | Compiled simulation executables (generated by iverilog) |

## Limitations & Next Steps

- **No data memory**: Load and store instructions decode correctly but there is no data memory module yet. The `mem_to_reg` mux also needs to be wired to it.
- **No branch/jump logic**: The PC currently increments by 4 unconditionally. The `branch` signal from the controller and the ALU's `zero` output should drive a mux that selects between `pc + 4` and a branch target address.
- **Single-cycle design**: Every instruction takes one clock cycle. Real processors use pipelining to overlap instruction execution and achieve higher clock speeds.
