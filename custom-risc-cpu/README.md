# Custom RISC CPU Simulator

This is a portfolio-ready computer architecture project that implements a small RISC-like CPU in three layers:

- A C fetch-decode-execute simulator.
- A lightweight two-pass assembler for `.asm` programs.
- A matching Verilog CPU implementation with a testbench and GTKWave waveform output.

The goal is to show the full path from assembly source code to machine code to CPU execution, while keeping the code readable enough for learning, debugging, and interviews.

## Project Layout

```text
custom-risc-cpu/
  README.md
  c-simulator/
    instructions.h
    registers.h
    registers.c
    memory.h
    memory.c
    cpu_sim.c
    assembler.c
    Makefile
    programs/
      add_two_numbers.asm
      sum_1_to_10.asm
      fibonacci_10_terms.asm
  verilog/
    cpu.v
    alu.v
    register_file.v
    memory.v
    control.v
    testbench.v
    programs/
      add_two_numbers.mem
```

## Architecture Overview

The CPU is intentionally small but complete:

- 8 general-purpose registers: `R0` through `R7`.
- 256-word memory shared by program instructions and data.
- A program counter (`PC`) that points into memory.
- Fixed-width instructions stored as 4 integers:

```text
[opcode] [a] [b] [c]
```

The simulator and Verilog design use the same flattened instruction format. Since each instruction is four memory words, labels are assembled into word-aligned PC targets.

## Instruction Set

| Mnemonic | Format | Description |
| --- | --- | --- |
| `NOP` | `NOP` | Do nothing. |
| `LOAD` | `LOAD rd, addr` | Load `MEM[addr]` into register `rd`. |
| `STORE` | `STORE rs, addr` | Store register `rs` into `MEM[addr]`. |
| `MOVI` | `MOVI rd, imm` | Move an immediate integer into `rd`. |
| `ADD` | `ADD rd, rs1, rs2` | Add `rs1 + rs2` into `rd`. |
| `SUB` | `SUB rd, rs1, rs2` | Subtract `rs1 - rs2` into `rd`. |
| `JMP` | `JMP label` | Jump to a label. |
| `BEQ` | `BEQ rs1, rs2, label` | Branch if registers are equal. |
| `BNE` | `BNE rs1, rs2, label` | Branch if registers are not equal. |
| `HALT` | `HALT` | Stop execution. |

Opcode values:

```text
NOP=0 LOAD=1 STORE=2 MOVI=3 ADD=4 SUB=5 JMP=6 BEQ=7 BNE=8 HALT=9
```

## C Simulator

The C simulator loads a `.bin` file containing newline-separated integers. It then repeatedly:

1. Fetches four integers from memory at `PC`.
2. Decodes the opcode and operands.
3. Validates registers, memory addresses, and branch targets.
4. Executes the instruction.
5. Updates `PC`.

Safety features include:

- Memory bounds checking.
- Register validation.
- Word-aligned jump target validation.
- A 10,000-step execution limit to prevent accidental infinite loops.
- Optional instruction tracing with `--trace`.

## Assembler

The assembler is a small two-pass assembler:

1. Pass one scans labels and records their PC addresses.
2. Pass two validates instructions and emits integer machine code.

It supports:

- Labels such as `loop:`.
- Comments beginning with `;`.
- Comma-separated or whitespace-separated operands.
- Clear errors for unknown opcodes, invalid registers, invalid memory addresses, malformed instructions, and missing labels.

Example assembly:

```asm
MOVI R1, 5
MOVI R2, 7
ADD R3, R1, R2
STORE R3, 250
HALT
```

## Build And Run

From a fresh clone:

```sh
cd custom-risc-cpu/c-simulator
make
```

Run the default example:

```sh
make run PROG=programs/add_two_numbers
```

Assemble and run manually:

```sh
./assembler programs/sum_1_to_10.asm programs/sum_1_to_10.bin
./cpu_sim programs/sum_1_to_10.bin --trace
```

Clean generated files:

```sh
make clean
```

## Sample Output

`add_two_numbers.asm` computes `5 + 7` and stores the result in `MEM[250]`.

```text
Program halted after 5 steps.
Registers:
  R0 = 0
  R1 = 5
  R2 = 7
  R3 = 12
  R4 = 0
  R5 = 0
  R6 = 0
  R7 = 0
Non-zero memory:
  MEM[1] = 1
  ...
  MEM[250] = 12
```

The memory dump includes non-zero program words because instructions and data share the same 256-word memory.

Expected program results:

| Program | Result |
| --- | --- |
| `add_two_numbers.asm` | `MEM[250] = 12` |
| `sum_1_to_10.asm` | `MEM[250] = 55` |
| `fibonacci_10_terms.asm` | `MEM[250] = 88` |

## Verilog Implementation

The Verilog CPU maps directly to the C simulator:

- `cpu.v` implements the top-level program counter and datapath.
- `control.v` decodes opcodes into control signals.
- `alu.v` implements add, subtract, and pass-through operations.
- `register_file.v` implements eight 32-bit registers.
- `memory.v` implements 256-word shared instruction/data memory.
- `testbench.v` loads `programs/add_two_numbers.mem`, runs the CPU, and generates `dump.vcd`.

Run with Icarus Verilog:

```sh
cd custom-risc-cpu/verilog
iverilog -o cpu_tb testbench.v cpu.v alu.v register_file.v memory.v control.v
vvp cpu_tb
gtkwave dump.vcd
```

The Verilog testbench prints the PC, instruction fields, register read values, and `MEM[250]` during simulation. It also stops after a cycle limit to catch broken branch logic.

## Debugging Notes

- PC updates are the most important behavior to inspect. Normal instructions advance by 4 words, while `JMP`, `BEQ`, and `BNE` replace `PC` with a label target.
- Branches compare register values, not register numbers.
- `--trace` is useful when checking whether a loop exits on the expected iteration.
- Shared instruction/data memory means storing into low addresses can overwrite a running program. The example programs store results at `MEM[250]` to avoid that.
- If a program hangs, check label placement, branch condition registers, and whether the loop counter changes before the branch target repeats.

## Resume Bullets

- Built a custom RISC-style CPU simulator in C with fetch-decode-execute control flow, register/memory validation, branch handling, tracing, and infinite-loop protection.
- Implemented a two-pass assembler that translates labeled assembly programs into integer machine code with clear diagnostics for malformed source input.
- Designed a matching Verilog CPU datapath with ALU, register file, control unit, shared memory, and Icarus Verilog testbench with GTKWave waveform generation.
