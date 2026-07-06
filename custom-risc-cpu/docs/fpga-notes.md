# FPGA Readiness Notes

This project is written for simulation first, but the structure is intentionally close to an FPGA-ready teaching core.

## What Is Already Hardware-Friendly

- The Verilog CPU is split into understandable hardware modules: ALU, control, register file, memory, single-cycle CPU, hazard unit, and pipelined CPU.
- The pipelined CPU has explicit IF/ID, ID/EX, EX/MEM, and MEM/WB state.
- The ISA uses fixed-width instructions, which keeps fetch/decode logic simple.
- The memory image format is plain integers, making it easy to convert into FPGA block-RAM initialization formats.

## Simulation-Only Pieces

These are useful for Icarus Verilog and GTKWave, but would need replacement or synthesis-specific handling for an FPGA target:

- `$fopen`, `$fscanf`, `$display`, `$finish`
- VCD generation with `$dumpfile` and `$dumpvars`
- Testbench-only expected-value checks
- Direct hierarchical reads such as `dut.mem[250]`

## FPGA Bring-Up Path

1. Convert `.mem` files into the initialization format expected by the FPGA toolchain.
2. Replace simulation file loading with a block RAM initialization flow.
3. Expose memory-mapped output (`MEM[255]`) to LEDs, UART, or a debug bus.
4. Add a clock divider or enable signal for visible single-step execution.
5. Add reset synchronization for the target board.
6. Keep the C simulator as the golden reference for every program before loading it onto hardware.

## Suggested Board Demo

A strong board demo would run `add_two_numbers.asm`, `sum_1_to_10.asm`, and `memory_copy.asm`, then expose:

- `MEM[250]` on LEDs or UART.
- Current PC on LEDs or seven-segment display.
- Halt/fault status as dedicated LEDs.
- Optional single-step button to advance one cycle at a time.

