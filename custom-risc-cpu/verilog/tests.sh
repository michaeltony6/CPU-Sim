#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
C_SIM_DIR="$ROOT_DIR/c-simulator"
VERILOG_DIR="$ROOT_DIR/verilog"

if ! command -v iverilog >/dev/null 2>&1; then
    echo "error: iverilog is required for Verilog tests"
    exit 1
fi

cd "$C_SIM_DIR"
make >/dev/null
./assembler programs/add_two_numbers.asm "$VERILOG_DIR/programs/add_two_numbers.mem" >/dev/null
./assembler programs/sum_1_to_10.asm "$VERILOG_DIR/programs/sum_1_to_10.mem" >/dev/null
./assembler programs/fibonacci_10_terms.asm "$VERILOG_DIR/programs/fibonacci_10_terms.mem" >/dev/null
./assembler programs/isa_v2_demo.asm "$VERILOG_DIR/programs/isa_v2_demo.mem" >/dev/null

cd "$VERILOG_DIR"
iverilog -o cpu_tb_add -Ptestbench.PROGRAM_FILE='"programs/add_two_numbers.mem"' -Ptestbench.EXPECTED_MEM250=12 \
    testbench.v cpu.v alu.v register_file.v memory.v control.v
vvp cpu_tb_add | grep 'MEM\[250\] = 12' >/dev/null

iverilog -o cpu_tb_sum -Ptestbench.PROGRAM_FILE='"programs/sum_1_to_10.mem"' -Ptestbench.EXPECTED_MEM250=55 \
    testbench.v cpu.v alu.v register_file.v memory.v control.v
vvp cpu_tb_sum | grep 'MEM\[250\] = 55' >/dev/null

iverilog -o cpu_tb_fib -Ptestbench.PROGRAM_FILE='"programs/fibonacci_10_terms.mem"' -Ptestbench.EXPECTED_MEM250=88 \
    testbench.v cpu.v alu.v register_file.v memory.v control.v
vvp cpu_tb_fib | grep 'MEM\[250\] = 88' >/dev/null

iverilog -o cpu_tb_v2 -Ptestbench.PROGRAM_FILE='"programs/isa_v2_demo.mem"' -Ptestbench.EXPECTED_MEM250=20 \
    testbench.v cpu.v alu.v register_file.v memory.v control.v
vvp cpu_tb_v2 | grep 'MEM\[250\] = 20' >/dev/null

iverilog -o fault_tb fault_testbench.v cpu.v alu.v register_file.v memory.v control.v
vvp fault_tb | grep 'CPU faulted as expected' >/dev/null

iverilog -o hazard_tb hazard_unit_testbench.v hazard_unit.v pipeline_register.v
vvp hazard_tb | grep 'HAZARD UNIT TESTS PASSED' >/dev/null

rm -f cpu_tb_add cpu_tb_sum cpu_tb_fib cpu_tb_v2 fault_tb hazard_tb dump.vcd fault_dump.vcd hazard_dump.vcd
echo "All Verilog tests passed."
