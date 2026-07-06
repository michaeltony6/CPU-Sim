#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
C_SIM_DIR="$ROOT_DIR/c-simulator"
VERILOG_DIR="$ROOT_DIR/verilog"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

if ! command -v iverilog >/dev/null 2>&1; then
    echo "error: iverilog is required for golden model comparison"
    exit 1
fi

cd "$C_SIM_DIR"
make >/dev/null

programs="
add_two_numbers
sum_1_to_10
fibonacci_10_terms
isa_v2_demo
multiply_repeated_add
factorial_5
max_array
memory_copy
subroutine_square
"

pipeline_supported="
add_two_numbers
sum_1_to_10
fibonacci_10_terms
multiply_repeated_add
factorial_5
max_array
memory_copy
"

contains_name() {
    needle=$1
    shift
    for item in "$@"; do
        if [ "$item" = "$needle" ]; then
            return 0
        fi
    done
    return 1
}

expected_field() {
    file=$1
    kind=$2
    field_index=$3
    awk -v kind="$kind" -v field_index="$field_index" '$1 == kind && $2 == field_index { print $3 }' "$file"
}

compare_single_cycle_state() {
    name=$1
    bin=$2
    state=$3

    cd "$VERILOG_DIR"
    iverilog -o "$TMP_DIR/state_tb_$name" -Pstate_testbench.PROGRAM_FILE="\"$bin\"" \
        state_testbench.v cpu.v alu.v register_file.v memory.v control.v
    vvp "$TMP_DIR/state_tb_$name" > "$TMP_DIR/$name.state.out"

    if grep 'STATE fault\|STATE timeout' "$TMP_DIR/$name.state.out" >/dev/null; then
        echo "error: single-cycle Verilog failed for $name"
        cat "$TMP_DIR/$name.state.out"
        exit 1
    fi

    for reg in 0 1 2 3 4 5 6 7; do
        expected=$(expected_field "$state" REG "$reg")
        actual=$(awk -v reg="$reg" '$1 == "STATE" && $2 == "REG" && $3 == reg { print $4 }' "$TMP_DIR/$name.state.out")
        if [ "$expected" != "$actual" ]; then
            echo "error: $name R$reg mismatch: C=$expected Verilog=$actual"
            exit 1
        fi
    done

    expected_mem250=$(expected_field "$state" MEM 250)
    actual_mem250=$(awk '$1 == "STATE" && $2 == "MEM" && $3 == 250 { print $4 }' "$TMP_DIR/$name.state.out")
    if [ "$expected_mem250" != "$actual_mem250" ]; then
        echo "error: $name MEM[250] mismatch: C=$expected_mem250 Verilog=$actual_mem250"
        exit 1
    fi
}

run_pipeline_check() {
    name=$1
    bin=$2
    expected=$3

    cd "$VERILOG_DIR"
    iverilog -o "$TMP_DIR/pipeline_tb_$name" -Ppipeline_testbench.PROGRAM_FILE="\"$bin\"" \
        -Ppipeline_testbench.EXPECTED_MEM250="$expected" \
        pipeline_testbench.v pipeline_cpu.v hazard_unit.v
    vvp "$TMP_DIR/pipeline_tb_$name" > "$TMP_DIR/$name.pipeline.out"

    if ! grep "PIPELINE MEM\\[250\\] = $expected" "$TMP_DIR/$name.pipeline.out" >/dev/null; then
        echo "error: pipeline Verilog failed for $name"
        cat "$TMP_DIR/$name.pipeline.out"
        exit 1
    fi
}

printf '%-24s %-12s %-12s\n' "program" "single-cycle" "pipeline"
printf '%-24s %-12s %-12s\n' "------------------------" "------------" "--------"

for name in $programs; do
    bin="$TMP_DIR/$name.mem"
    state="$TMP_DIR/$name.state"

    cd "$C_SIM_DIR"
    ./assembler "programs/$name.asm" "$bin" >/dev/null
    ./cpu_sim "$bin" --dump-state "$state" >/dev/null
    expected_mem250=$(expected_field "$state" MEM 250)

    compare_single_cycle_state "$name" "$bin" "$state"

    pipeline_result="skipped"
    # shellcheck disable=SC2086
    if contains_name "$name" $pipeline_supported; then
        run_pipeline_check "$name" "$bin" "$expected_mem250"
        pipeline_result="passed"
    fi

    printf '%-24s %-12s %-12s\n' "$name" "passed" "$pipeline_result"
done

echo "Golden model comparisons passed."
