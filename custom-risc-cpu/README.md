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
  Makefile
  c-simulator/
    instructions.h
    registers.h
    registers.c
    memory.h
    memory.c
    cpu_sim.c
    assembler.c
    disassembler.c
    profiler.c
    debugger.c
    Makefile
    tests.sh
    programs/
      add_two_numbers.asm
      sum_1_to_10.asm
      fibonacci_10_terms.asm
      isa_v2_demo.asm
  scripts/
    run_all_examples.sh
    debug_isa_v2.sh
    language_mix.sh
  web-debugger/
    index.html
    styles.css
    app.js
    cpu_core.js
    tests.js
    Makefile
  verilog/
    cpu.v
    alu.v
    register_file.v
    memory.v
    control.v
    testbench.v
    fault_testbench.v
    hazard_unit.v
    hazard_unit_testbench.v
    pipeline_register.v
    tests.sh
    programs/
      add_two_numbers.mem
      sum_1_to_10.mem
      fibonacci_10_terms.mem
      isa_v2_demo.mem
      invalid_register.mem
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
| `ADDI` | `ADDI rd, rs, imm` | Add an immediate integer to a register. |
| `AND` | `AND rd, rs1, rs2` | Bitwise AND. |
| `OR` | `OR rd, rs1, rs2` | Bitwise OR. |
| `XOR` | `XOR rd, rs1, rs2` | Bitwise XOR. |
| `SHL` | `SHL rd, rs, imm` | Logical shift left by `imm` bits. |
| `SHR` | `SHR rd, rs, imm` | Logical shift right by `imm` bits. |
| `LOADR` | `LOADR rd, addrReg` | Load from the memory address stored in a register. |
| `STORER` | `STORER rs, addrReg` | Store to the memory address stored in a register. |
| `JLT` | `JLT rs1, rs2, label` | Signed branch if `rs1 < rs2`. |
| `JGT` | `JGT rs1, rs2, label` | Signed branch if `rs1 > rs2`. |
| `PUSH` | `PUSH rs` | Push register value onto the stack. |
| `POP` | `POP rd` | Pop stack value into a register. |
| `CALL` | `CALL label` | Push return address and jump to a subroutine. |
| `RET` | `RET` | Return from a subroutine. |

Opcode values:

```text
NOP=0 LOAD=1 STORE=2 MOVI=3 ADD=4 SUB=5 JMP=6 BEQ=7 BNE=8 HALT=9
ADDI=10 AND=11 OR=12 XOR=13 SHL=14 SHR=15 LOADR=16 STORER=17
JLT=18 JGT=19 PUSH=20 POP=21 CALL=22 RET=23
```

`R7` is the stack pointer by convention. It starts at `256`, and stack operations pre-decrement before writing. `MEM[255]` acts as a memory-mapped output location.

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
- Strict `.bin` parsing so malformed machine-code files are rejected instead of partially loaded.
- Zero, negative, and carry/overflow-style status flags updated by value-producing instructions.
- Stack/subroutine support with `PUSH`, `POP`, `CALL`, and `RET`.
- Memory-mapped output through `MEM[255]`.

## Assembler

The assembler is a small two-pass assembler:

1. Pass one scans labels and records their PC addresses.
2. Pass two validates instructions and emits integer machine code.

It supports:

- Labels such as `loop:`.
- Comments beginning with `;`.
- Comma-separated or whitespace-separated operands.
- Clear errors for unknown opcodes, invalid registers, invalid memory addresses, malformed instructions, and missing labels.
- Label validation for length and allowed characters.
- Branch target validation for numeric jump/branch addresses.

The disassembler reads newline-separated integer `.bin` files and prints readable instructions with PC addresses. This makes it easy to inspect generated machine code or debug assembler output.

The native profiler runs a program and reports execution metrics such as opcode counts, register reads/writes, memory reads/writes, branch behavior, stack depth, call/return activity, MMIO output count, and final `MEM[250]`.

The native debugger supports both interactive and scripted sessions with commands for stepping, running, breakpoints, register dumps, memory inspection, and disassembly windows. This gives the project a terminal workflow that complements the browser debugger.

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

Open the interactive browser debugger:

```sh
cd custom-risc-cpu/web-debugger
python3 -m http.server 8000
```

Then visit `http://localhost:8000`. The debugger can assemble source, step instructions, run until halt, pause at breakpoints, highlight changed registers/memory, show trace output, and export `.bin` machine code.
It also includes a five-stage pipeline mode that shows IF, ID, EX, MEM, and WB cycle by cycle with data-hazard stalls, branch flushes, retired instruction count, and CPI.

![Interactive CPU Debugger](docs/images/web-debugger.png)

Run the default example:

```sh
make run PROG=programs/add_two_numbers
```

Assemble and run manually:

```sh
./assembler programs/sum_1_to_10.asm programs/sum_1_to_10.bin
./cpu_sim programs/sum_1_to_10.bin --trace
./disassembler programs/sum_1_to_10.bin
./profiler programs/sum_1_to_10.bin
./debugger programs/sum_1_to_10.bin
```

Run every assembly example through the C toolchain:

```sh
cd custom-risc-cpu
./scripts/run_all_examples.sh
```

Run a scripted terminal-debugger demo:

```sh
./scripts/debug_isa_v2.sh
```

Check the local source language mix:

```sh
./scripts/language_mix.sh
```

Clean generated files:

```sh
make clean
```

Run the C simulator and assembler test suite:

```sh
make test
```

Run every regression suite from the project root:

```sh
cd custom-risc-cpu
make test
```

Run the web debugger CPU core test suite:

```sh
cd custom-risc-cpu/web-debugger
make test
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
| `isa_v2_demo.asm` | `MEM[250] = 20` |

## Verilog Implementation

The Verilog CPU maps directly to the C simulator:

- `cpu.v` implements the top-level program counter and datapath.
- `control.v` decodes opcodes into control signals.
- `alu.v` implements add, subtract, and pass-through operations.
- `register_file.v` implements eight 32-bit registers.
- `memory.v` implements 256-word shared instruction/data memory.
- `testbench.v` loads `programs/add_two_numbers.mem`, runs the CPU, and generates `dump.vcd`.
- `fault_testbench.v` verifies that invalid operands halt the CPU with a visible fault.
- `hazard_unit.v` models data forwarding, load-use stalls, and branch flush control for a pipelined version.
- `pipeline_register.v` provides reusable valid/data pipeline storage with stall and flush controls.
- `hazard_unit_testbench.v` verifies forwarding priority, load-use stalls, branch flushes, and pipeline-register behavior.

Run with Icarus Verilog:

```sh
cd custom-risc-cpu/verilog
iverilog -o cpu_tb testbench.v cpu.v alu.v register_file.v memory.v control.v
vvp cpu_tb
gtkwave dump.vcd
```

The Verilog testbench prints the PC, instruction fields, register read values, and `MEM[250]` during simulation. It also stops after a cycle limit to catch broken branch logic.

Run the Verilog regression tests:

```sh
cd custom-risc-cpu/verilog
./tests.sh
```

The Verilog implementation includes simulation-time fault checks for invalid register numbers, invalid memory addresses, invalid branch targets, and invalid PC values. The `$fopen`, `$fscanf`, `$display`, and VCD dump features are intended for simulation and debugging rather than direct synthesis.

The hazard unit is a standalone hardware module that maps directly to the browser pipeline visualizer. It is not wired into the single-cycle CPU top level yet, but it documents and tests the control policy needed for a future pipelined Verilog CPU.

## Debugging Notes

- PC updates are the most important behavior to inspect. Normal instructions advance by 4 words, while `JMP`, `BEQ`, and `BNE` replace `PC` with a label target.
- Branches compare register values, not register numbers.
- `--trace` is useful when checking whether a loop exits on the expected iteration.
- Shared instruction/data memory means storing into low addresses can overwrite a running program. The example programs store results at `MEM[250]` to avoid that.
- If a program hangs, check label placement, branch condition registers, and whether the loop counter changes before the branch target repeats.
- If the Verilog CPU halts with `fault=1`, inspect the decoded instruction fields for an invalid register number, memory address, branch target, or PC.
- Use `./profiler program.bin` when you want opcode counts, branch statistics, stack usage, and memory/register traffic without reading every trace line.
- Use `./debugger program.bin commands.txt` to make repeatable terminal debugging sessions for demos or regression checks.
- In the web debugger, use breakpoints on loop labels and watch the highlighted register/memory cells after each step.
- For stack programs, initialize or preserve `R7` as the stack pointer. It starts at `256`, and the first `PUSH` or `CALL` writes to `MEM[255]`.
- In pipeline mode, use **Pipeline Cycle** to advance one hardware cycle at a time. Yellow rows indicate data stalls; red rows indicate branch/control flushes.

## Known Limitations

- The ISA is still intentionally small: there are no interrupts, byte-addressed loads, or caches.
- The Verilog memory loader and trace output are simulation conveniences, not a complete FPGA memory-initialization flow.
- The C simulator and Verilog CPU share behavior for the supported ISA, but the C simulator remains the reference model for detailed error messages.
- The web debugger is a static educational tool and mirrors the ISA behavior in JavaScript; it is not a replacement for the C reference simulator.
- The pipeline visualizer and standalone Verilog hazard unit show the pipeline control policy, but the top-level Verilog CPU remains single-cycle.

## Resume Bullets

- Built a custom RISC-style CPU simulator in C with fetch-decode-execute control flow, register/memory validation, branch handling, tracing, and infinite-loop protection.
- Implemented a two-pass assembler that translates labeled assembly programs into integer machine code with clear diagnostics for malformed source input.
- Designed and tested a matching Verilog CPU datapath with ALU, register file, control unit, shared memory, fault detection, and GTKWave waveform generation.
- Created an interactive browser debugger with assembly editing, breakpoints, step/run controls, trace output, state-change highlighting, and machine-code export.
- Expanded the CPU with bitwise logic, shifts, immediate arithmetic, register-indirect memory, signed branches, stack operations, subroutine calls, status flags, and memory-mapped output.
- Added a five-stage pipeline visualization mode with IF/ID/EX/MEM/WB stages, data stalls, branch flushes, retired instruction counts, and CPI metrics.
- Added native C profiling/debugging tools, shell automation scripts, and Verilog pipeline-control modules with regression tests.
