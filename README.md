# Custom RISC CPU Simulator

A complete portfolio project that demonstrates a small custom RISC-like CPU from assembly source code all the way down to simulation and hardware description.

This repository includes:

- A C-based CPU simulator with fetch-decode-execute behavior.
- A lightweight two-pass assembler for `.asm` source files.
- Example assembly programs for arithmetic, loops, and Fibonacci logic.
- A matching Verilog implementation of the same instruction set.
- An Icarus Verilog testbench that generates a GTKWave-compatible VCD file.

The main project lives in [`custom-risc-cpu/`](custom-risc-cpu/).

## Why This Project Matters

This project is designed to show practical systems knowledge in a compact, reviewable codebase. It connects several important low-level computing concepts:

- Instruction set architecture design.
- Register files and memory.
- Program counters and branch control.
- Assembly parsing and label resolution.
- CPU simulation in C.
- Hardware modeling in Verilog.

It is intentionally small enough to understand quickly, but complete enough to discuss in an interview or include in a resume portfolio.

## Architecture

The custom CPU uses:

- 8 general-purpose registers: `R0` through `R7`.
- 256 words of shared instruction/data memory.
- A program counter (`PC`).
- Fixed-width 4-integer instructions:

```text
[opcode] [a] [b] [c]
```

Each assembly instruction is assembled into four integers. The simulator loads those integers into memory, fetches one instruction at a time, decodes the opcode, executes the operation, and updates the program counter.

## Instruction Set

| Instruction | Format | Purpose |
| --- | --- | --- |
| `NOP` | `NOP` | Do nothing |
| `LOAD` | `LOAD rd, addr` | Load memory into a register |
| `STORE` | `STORE rs, addr` | Store a register into memory |
| `MOVI` | `MOVI rd, imm` | Move an immediate value into a register |
| `ADD` | `ADD rd, rs1, rs2` | Add two registers |
| `SUB` | `SUB rd, rs1, rs2` | Subtract two registers |
| `JMP` | `JMP label` | Jump unconditionally |
| `BEQ` | `BEQ rs1, rs2, label` | Branch if equal |
| `BNE` | `BNE rs1, rs2, label` | Branch if not equal |
| `HALT` | `HALT` | Stop execution |

## Quick Start

Build and run the C simulator:

```sh
cd custom-risc-cpu/c-simulator
make
make run PROG=programs/add_two_numbers
```

Run another example manually:

```sh
./assembler programs/sum_1_to_10.asm programs/sum_1_to_10.bin
./cpu_sim programs/sum_1_to_10.bin --trace
```

Expected example results:

| Program | Output |
| --- | --- |
| `add_two_numbers.asm` | `MEM[250] = 12` |
| `sum_1_to_10.asm` | `MEM[250] = 55` |
| `fibonacci_10_terms.asm` | `MEM[250] = 88` |

## Verilog Simulation

Run the hardware simulation with Icarus Verilog:

```sh
cd custom-risc-cpu/verilog
iverilog -o cpu_tb testbench.v cpu.v alu.v register_file.v memory.v control.v
vvp cpu_tb
gtkwave dump.vcd
```

The testbench loads `programs/add_two_numbers.mem`, executes the CPU, prints trace information, and writes `dump.vcd` for waveform inspection.

## Debugging Features

The C simulator includes:

- Optional tracing with `--trace`.
- Register validation.
- Memory bounds checking.
- Branch target validation.
- Execution limit protection for infinite loops.
- Final register and non-zero memory dumps.

These features make it easier to debug PC updates, branch logic, loop behavior, and memory/register state.

## Resume Bullets

- Built a custom RISC-style CPU simulator in C with fetch-decode-execute control flow, branch handling, tracing, memory bounds checking, and register validation.
- Implemented a two-pass assembler that converts labeled assembly programs into integer-based machine code with clear diagnostics for malformed input.
- Designed a matching Verilog CPU implementation with ALU, register file, control unit, memory module, and waveform-generating Icarus Verilog testbench.

## Full Documentation

See [`custom-risc-cpu/README.md`](custom-risc-cpu/README.md) for the complete architecture notes, file layout, build instructions, assembler details, simulator behavior, Verilog mapping, and sample output.
