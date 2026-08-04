# 5-Stage Pipelined RISC-V Processor

This project contains a **5-stage pipelined** implementation of a subset of the **RISC-V (RV32I)** instruction set, written in **Verilog** (a hardware description language). The processor fetches, decodes, executes, accesses memory, and writes results for **several instructions at the same time**, each instruction taking roughly one clock cycle per stage.

> **Note:** This directory was originally a single-cycle processor. It has been converted into a full 5-stage pipeline (see [What Changed From Single-Cycle?](#what-changed-from-single-cycle)).

## Big-Picture Analogy

Imagine a factory assembly line where a product moves through **five stations**:

| Station | What happens there |
|---------|--------------------|
| 1. Fetch    | Pull the instruction for this product off the shelf (memory) |
| 2. Decode   | Read the recipe: which parts (registers) and constants (immediates) are needed |
| 3. Execute  | Do the arithmetic / logic with the ALU |
| 4. Memory   | Optionally read or write data in the warehouse (data memory) |
| 5. Writeback| Pack the finished result back into a register |

Because the stations are in series, **five different instructions are always in the assembly line at once** — station 5 is finishing instruction #1 while station 1 is starting instruction #5. This is pipelining: throughput is much higher than a single-cycle processor (where one worker does all five steps before the next job enters the line).

The cost is **hazards**: when a later instruction needs a result that an earlier instruction hasn't finished yet. This processor handles them with *forwarding*, *stalling*, and *branch flushing* (explained below).

## What Is RV32I?

RISC-V is an open-source instruction set architecture (ISA) — a standardized list of commands a CPU understands. RV32I is the 32-bit integer base variant. "32" means 32-bit data and addresses; instructions are also 32 bits wide.

Each 32-bit instruction is divided into **fields**:
- The **opcode** (what kind of operation: arithmetic, load, store, branch)
- **Register addresses** (32 general-purpose registers x0–x31; x0 is hardwired to 0)
- A **function code** (`funct3` / `funct7`) that refines the operation (ADD vs SUB, etc.)
- An **immediate value** (a constant embedded in the instruction)

## Pipeline Block Diagram

```
 +-------------+      +-------------+      +-------------+      +-------------+      +-------------+
 |      IF     |      |      ID     |      |      EX     |      |     MEM     |      |      WB     |
 | Instruction | IF/ID| Instruction | ID/EX| Forwarding  | EX/MEM| Data        | MEM/WB| Write-Back |
 |   Fetch     |=====>|    Decode   |=====>| ALU         |=====>|  Memory     |======>|   MUX ->    |
 | (PC, ROM)   |      | (Control,   |      | Branch      |      | (loads)     |       | reg_file    |
 |             |      |  reg_file,  |      | Target      |      | (stores)    |       |             |
 |             |      |  imm_gen)   |      | ALU src MUX |      |             |       |             |
 +-------------+      +-------------+      +-------------+      +-------------+      +-------------+
        |                    |                   |                   |
        |<------- PC MUX ----|<----- hazard_unit (stall + flush)    |
        |              branch_taken (predict-not-taken)            |
```

The boxes labeled **IF/ID, ID/EX, EX/MEM, MEM/WB** are **pipeline registers** — they store an instruction's data and control signals between stages, so each stage can work on a different instruction every cycle.

## The Five Stages, Step by Step

### Stage 1 — Instruction Fetch (IF)
- **`pc.v`** — the program counter register holds the address of the current instruction. It has a write-enable input: when the pipeline stalls, the PC simply holds its value.
- **`instr_mem.v`** — a small read-only memory (16 words = 64 bytes) holding the program, loaded from `instr_mem.txt` at simulation start.
- The fetch stage also computes `PC + 4` for the sequential next address. On a taken branch the **PC mux** instead selects the branch target.
- The fetched instruction and its PC are latched into the **IF/ID** register.

### Stage 2 — Instruction Decode (ID)
- **`control.v`** — the control unit decodes the opcode into control signals (`reg_write`, `alu_src`, `mem_write`, `mem_read`, `mem_to_reg`, `branch`) and produces a precise 4-bit `alu_ctrl` from `funct3`/`funct7`.
- **`reg_file.v`** — the 32 × 32-bit register file. Reads are asynchronous (values appear immediately); writes are synchronous (committed on a clock edge). x0 always reads 0.
- **`imm_gen.v`** — builds the sign-extended immediate from the instruction's I/S/B-type fields.
- The decoded data and control are latched into the **ID/EX** register.

### Stage 3 — Execute (EX)
- **`forward_unit.v`** — detects data hazards and forwards results that are still traveling through the pipeline so the ALU gets the newest value instead of a stale register-file value.
- **`alu.v`** — performs ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT. It also produces the `zero` flag used by branches.
- **`alu_src` mux** — chooses the ALU's second operand: register `rs2` or the immediate.
- **Branch target** — computed here as `PC + imm`; the **branch decision** (`branch & zero`) is also made here (predict-not-taken).
- The results are latched into the **EX/MEM** register.

### Stage 4 — Memory Access (MEM)
- **`data_mem.v`** — a 64-word data memory. **Stores** (`sw`) write on the clock edge; **loads** (`lw`) read combinationally during this stage.
- The ALU result from EX is the memory address for both loads and stores.
- Results are latched into the **MEM/WB** register.

### Stage 5 — Write Back (WB)
- A **write-back mux** selects the value to store in the register file: the ALU result or the data memory read value (`mem_to_reg`).
- The register file write completes here.

## Hazards and How the Pipeline Handles Them

### 1. Data hazards → Forwarding (`forward_unit.v`)
If an instruction in EX reads a register that an earlier instruction is still about to write, the value may be sitting in the **EX/MEM** or **MEM/WB** pipeline register. The forwarding unit checks the register numbers and, when they match, feeds the newer value directly into the ALU inputs (bypassing the stale register-file value).

- **EX/MEM** result takes priority (newest producer).
- The register file is still written normally; forwarding just removes the need to wait.

### 2. Load-use hazards → Stall (`hazard_unit.v`)
If the instruction in EX is a **load** (`lw`) and the instruction in ID needs the register it is loading, the value cannot be forwarded in time. The hazard unit **freezes** the PC and the IF/ID register for one cycle and injects a **bubble** (a no-op) into the ID/EX register. On the next cycle the load result is available to be forwarded from MEM/WB.

### 3. Control hazards → Flush (branch, predict-not-taken)
The processor assumes **branches are not taken**. When a branch executes, the two instructions fetched right after it are the wrong ones, so they are **flushed** (cleared) from the IF/ID and ID/EX registers and the PC is redirected to the branch target. This costs 2 wasted cycles per taken branch.

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
00500093 // addi x1, x0, 5    -> x1 = 5
00A00113 // addi x2, x0, 10   -> x2 = 10
00102023 // sw   x1, 0(x0)    -> mem[0] = 5          (store)
00002283 // lw   x5, 0(x0)    -> x5 = 5              (load)
00228333 // add  x6, x5, x2   -> x6 = 15             (LOAD-USE -> 1 stall)
002081B3 // add  x3, x1, x2   -> x3 = 15             (RAW -> forwarding)
00618863 // beq  x3, x6, +16  -> taken -> PC = 0x28  (branch flushes 2)
00100413 // addi x8, x0, 1    -> flushed (never runs)
00200413 // addi x8, x0, 2    -> flushed (never runs)
00300413 // addi x8, x0, 3    -> flushed (never runs)
06300393 // addi x7, x0, 99   -> x7 = 99             (branch target)
003384B3 // add  x9, x7, x3   -> x9 = 114            (RAW -> forwarding)
00902223 // sw   x9, 4(x0)    -> mem[1] = 114        (store)
00402503 // lw   x10, 4(x0)   -> x10 = 114           (load)
00150513 // addi x10, x10, 1  -> x10 = 115           (LOAD-USE -> 1 stall)
00000000 // padding / no-op
```

This small program deliberately exercises **every hazard the processor supports**:
- **RAW data hazard** → `add x3, x1, x2` (and `add x9`) must use forwarded results.
- **Load-use hazard** → `add x6, x5, x2` uses x5 loaded one instruction earlier (stall), and `addi x10, x10, 1` uses x10 loaded one instruction earlier (stall).
- **Control hazard** → `beq x3, x6` is taken and the three `addi x8` instructions are flushed, so x8 stays 0.

## File Reference

| File              | Purpose                                                        |
|-------------------|----------------------------------------------------------------|
| `riscv_top.v`     | Top-level module — wires all five stages together              |
| `pc.v`            | Program Counter (with write-enable for stalls)                 |
| `instr_mem.v`     | Instruction memory (ROM, 16 words, loaded from text file)      |
| `instr_mem.txt`   | Hex-encoded program to execute                                 |
| `if_id.v`         | IF/ID pipeline register (supports stall and flush)             |
| `control.v`       | Main decoder + ALU decoder (control signals)                   |
| `reg_file.v`      | Register file (32 × 32-bit registers)                          |
| `imm_gen.v`       | Immediate value generator (sign-extends I/S/B immediates)      |
| `id_ex.v`         | ID/EX pipeline register (supports flush / bubble)              |
| `hazard_unit.v`   | Load-use hazard detection (stalls PC + IF/ID)                  |
| `forward_unit.v`  | Data-hazard forwarding (EX and MEM/WB to ALU)                  |
| `alu.v`           | ALU — performs arithmetic and logic operations                 |
| `ex_mem.v`        | EX/MEM pipeline register                                       |
| `data_mem.v`      | Data memory (64 words) for loads and stores                    |
| `mem_wb.v`        | MEM/WB pipeline register                                       |
| `cpu_tb.v`        | Testbench for the full CPU                                     |
| `alu_tb.v`        | Testbench for the ALU                                          |
| `fetch_tb.v`      | Testbench for the fetch stage (PC + instruction memory)        |
| `reg_test.v`      | Testbench for the register file                                |
| `*.vcd`           | Waveform dump files (simulation output, viewable in GTKWave)   |
| `*_sim` / `*_sim.exe` | Compiled simulation executables (generated by iverilog)   |

## What Changed From Single-Cycle?

- The single datapath was split into five stages with four pipeline registers (`if_id.v`, `id_ex.v`, `ex_mem.v`, `mem_wb.v`).
- Added a **data memory** (`data_mem.v`) and the MEM stage so loads/stores work.
- Added a **hazard unit** (load-use stall) and a **forwarding unit** (data bypass).
- Added **branch execution** with predict-not-taken and flushing.
- The `pc.v` gained a write-enable, and `instr_mem.v`'s output bug was fixed.

---

# How to Simulate

These instructions assume you have **Icarus Verilog (iverilog)** and **GTKWave** installed and on your `PATH`.

Open a terminal, navigate into the `pipelined` folder, and run the commands below.

## 1. Simulate the Full CPU

**Step 1 — Compile all modules into an executable:**

```powershell
iverilog -o riscv_core_sim riscv_top.v pc.v instr_mem.v control.v reg_file.v imm_gen.v alu.v if_id.v id_ex.v ex_mem.v mem_wb.v hazard_unit.v forward_unit.v data_mem.v cpu_tb.v
```

**Step 2 — Run the simulation (produces `cpu_execution.vcd`):**

```powershell
vvp riscv_core_sim
```

You should see output like this:

```
VCD info: dumpfile cpu_execution.vcd opened for output.
--- Execution Simulation Complete ---
x1  = 5  (expect 5)
x2  = 10  (expect 10)
x3  = 15  (expect 15)
x5  = 5  (expect 5)
x6  = 15  (expect 15)
x7  = 99  (expect 99)
x8  = 0  (expect 0, flushed instructions)
x9  = 114  (expect 114)
x10 = 115  (expect 115)
mem[0] = 5  (expect 5)
mem[1] = 114  (expect 114)
```

If the register values match the `(expect ...)` comments, the pipeline is working correctly.

**Step 3 — View the waveforms in GTKWave:**

```powershell
gtkwave cpu_execution.vcd
```

## 2. Viewing Results in GTKWave (Step by Step)

1. After running `vvp`, a file named **`cpu_execution.vcd`** appears in the folder.
2. Open it with **`gtkwave cpu_execution.vcd`**.
3. In the **SST** (signal tree) panel on the left:
   - Expand **`cpu_tb`**, then **`uut`** (the `riscv_top` instance).
   - Expand each sub-module (`my_pc`, `my_instr_mem`, `if_id`, `id_ex`, `ex_mem`, `mem_wb`, `my_alu`, `my_data_mem`, `my_reg_file`, etc.) to browse all internal signals.
4. Add signals to the waveform viewer by **double-clicking** them:
   - `clk` and `reset` (in `cpu_tb`)
   - `pc_current` (program counter over time)
   - `if_id_instr` (instruction currently in decode)
   - `idex_rd`, `idex_reg_write` (instruction in execute)
   - `alu_result` (results coming out of the ALU)
   - `mem_wb_rd`, `wb_write_data` (write-back activity)
   - `branch_taken` and `stall` (hazard handling in action)
5. To see register values, in the SST expand **`my_reg_file`** and double-click **`registers[1]`**, `registers[3]`, etc. (GTKWave shows memories/arrays as a table).
6. To see memory contents, expand **`my_data_mem`** and double-click **`mem[0]`**, `mem[1]`, etc.
7. Use the toolbar buttons / **Ctrl+Z** to zoom out and the time cursor (click and drag on the waveform) to inspect individual cycles.
8. Watch how **five different instructions** occupy the five stages at the same time — that is the pipeline working.

## 3. Simulate the Individual Testbenches

### ALU Testbench

```powershell
iverilog -o alu_sim alu_tb.v alu.v
vvp alu_sim
gtkwave alu_test.vcd
```

### Fetch-Stage Testbench (PC + instruction memory)

```powershell
iverilog -o fetch_sim fetch_tb.v pc.v instr_mem.v
vvp fetch_sim
gtkwave fetch_test.vcd
```

### Register-File Testbench

```powershell
iverilog -o reg_sim reg_test.v reg_file.v
vvp reg_sim
gtkwave reg_test.vcd
```

> The `.vcd` files and `*_sim` executables are generated artifacts and are git-ignored.

---

## Limitations & Next Steps

- **Only `beq` is implemented** for branches. Adding `bne`, `blt`, `bge` only requires extending the ALU decoder and using other ALU flags.
- **No jumps** (`jal`, `jalr`) — the PC mux would need a third input and the return address would need saving.
- **Simple hazard policy**: one load-use stall cycle and 2-cycle branch flush. A real design could compute branch conditions earlier (in ID) to cut the flush penalty to 1 cycle.
- **Byte/loads of other widths** (`lb`, `sb`, `lhu`) are not implemented.
- **No exception/interrupt handling** or CSR support.
