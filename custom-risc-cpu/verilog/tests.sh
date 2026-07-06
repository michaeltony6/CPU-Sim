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
for source in programs/*.asm; do
    name=$(basename "$source" .asm)
    ./assembler "$source" "$VERILOG_DIR/programs/$name.mem" >/dev/null
done

cd "$VERILOG_DIR"
run_single_cycle() {
    name=$1
    expected=$2
    out="cpu_tb_$name"
    iverilog -o "$out" -Ptestbench.PROGRAM_FILE="\"programs/$name.mem\"" -Ptestbench.EXPECTED_MEM250="$expected" \
        testbench.v cpu.v alu.v register_file.v memory.v control.v
    vvp "$out" | grep "MEM\\[250\\] = $expected" >/dev/null
}

run_pipeline() {
    name=$1
    expected=$2
    out="pipeline_tb_$name"
    iverilog -o "$out" -Ppipeline_testbench.PROGRAM_FILE="\"programs/$name.mem\"" -Ppipeline_testbench.EXPECTED_MEM250="$expected" \
        pipeline_testbench.v pipeline_cpu.v hazard_unit.v
    vvp "$out" | grep "PIPELINE MEM\\[250\\] = $expected" >/dev/null
}

run_single_cycle add_two_numbers 12
run_single_cycle sum_1_to_10 55
run_single_cycle fibonacci_10_terms 88
run_single_cycle isa_v2_demo 20
run_single_cycle multiply_repeated_add 42
run_single_cycle factorial_5 120
run_single_cycle max_array 42
run_single_cycle memory_copy 44
run_single_cycle subroutine_square 81

run_pipeline add_two_numbers 12
run_pipeline sum_1_to_10 55
run_pipeline fibonacci_10_terms 88
run_pipeline multiply_repeated_add 42
run_pipeline factorial_5 120
run_pipeline max_array 42
run_pipeline memory_copy 44

iverilog -o fault_tb fault_testbench.v cpu.v alu.v register_file.v memory.v control.v
vvp fault_tb | grep 'CPU faulted as expected' >/dev/null

iverilog -o hazard_tb hazard_unit_testbench.v hazard_unit.v pipeline_register.v
vvp hazard_tb | grep 'HAZARD UNIT TESTS PASSED' >/dev/null

rm -f cpu_tb_* pipeline_tb_* fault_tb hazard_tb dump.vcd fault_dump.vcd hazard_dump.vcd pipeline_dump.vcd
echo "All Verilog tests passed."
