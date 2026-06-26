#!/bin/sh
set -eu

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

make clean >/dev/null
make >/dev/null

check_result() {
    name=$1
    expected=$2

    ./assembler "programs/$name.asm" "$tmp_dir/$name.bin" >/dev/null
    output=$(./cpu_sim "$tmp_dir/$name.bin")
    printf '%s\n' "$output" | grep "MEM\\[250\\] = $expected" >/dev/null
}

expect_assembler_fail() {
    name=$1
    source=$2
    expected_error=$3

    printf '%s\n' "$source" > "$tmp_dir/$name.asm"
    if ./assembler "$tmp_dir/$name.asm" "$tmp_dir/$name.bin" >"$tmp_dir/$name.out" 2>&1; then
        echo "expected assembler failure for $name"
        cat "$tmp_dir/$name.out"
        exit 1
    fi
    grep "$expected_error" "$tmp_dir/$name.out" >/dev/null
}

expect_sim_fail() {
    name=$1
    contents=$2
    expected_error=$3

    printf '%s\n' "$contents" > "$tmp_dir/$name.bin"
    if ./cpu_sim "$tmp_dir/$name.bin" >"$tmp_dir/$name.out" 2>&1; then
        echo "expected simulator failure for $name"
        cat "$tmp_dir/$name.out"
        exit 1
    fi
    grep "$expected_error" "$tmp_dir/$name.out" >/dev/null
}

check_result add_two_numbers 12
check_result sum_1_to_10 55
check_result fibonacci_10_terms 88
check_result isa_v2_demo 20

./assembler programs/isa_v2_demo.asm "$tmp_dir/isa_v2_demo.bin" >/dev/null
./disassembler "$tmp_dir/isa_v2_demo.bin" > "$tmp_dir/isa_v2_demo.disasm"
grep 'ADDI R2, R1, 3' "$tmp_dir/isa_v2_demo.disasm" >/dev/null
grep 'CALL 100' "$tmp_dir/isa_v2_demo.disasm" >/dev/null

expect_assembler_fail bad_register 'MOVI R8, 1' 'invalid register'
expect_assembler_fail bad_opcode 'NOPE R1, 1' 'unknown opcode'
expect_assembler_fail bad_label 'bad-label: HALT' 'invalid label'
expect_assembler_fail unknown_label 'JMP missing' 'unknown label'
expect_assembler_fail bad_target 'JMP 3' 'invalid branch target'
expect_assembler_fail bad_address 'LOAD R1, 300' 'invalid memory address'
expect_assembler_fail bad_shift 'SHL R1, R2, 32' 'invalid shift amount'

expect_sim_fail bad_token '9
oops' 'invalid integer token'
expect_sim_fail bad_runtime_register '3
8
1
0' 'invalid register'

echo "All C simulator and assembler tests passed."
