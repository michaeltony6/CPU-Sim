#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
C_SIM_DIR="$ROOT_DIR/c-simulator"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

printf 'Building C tools...\n'
cd "$C_SIM_DIR"
make >/dev/null

printf '\nRunning assembly programs through the full C toolchain:\n'
printf '%-24s %-10s %-10s %-10s\n' "program" "mem[250]" "steps" "branches"
printf '%-24s %-10s %-10s %-10s\n' "------------------------" "--------" "-----" "--------"

for source in programs/*.asm; do
    name=$(basename "$source" .asm)
    bin="$TMP_DIR/$name.bin"
    disasm="$TMP_DIR/$name.disasm"
    profile="$TMP_DIR/$name.profile"

    ./assembler "$source" "$bin" >/dev/null
    ./cpu_sim "$bin" > "$TMP_DIR/$name.sim"
    ./disassembler "$bin" > "$disasm"
    ./profiler "$bin" > "$profile"

    result=$(awk -F'= ' '/MEM\[250\] =/ { value = $2 } END { print value + 0 }' "$TMP_DIR/$name.sim")
    steps=$(awk -F': ' '/^steps:/ { print $2 }' "$profile")
    branches=$(awk -F': ' '/^branches:/ { print $2 }' "$profile")

    printf '%-24s %-10s %-10s %-10s\n' "$name" "$result" "$steps" "$branches"
done

printf '\nTip: run one program with tracing for a detailed execution log:\n'
printf '  cd %s && ./cpu_sim /path/to/program.bin --trace\n' "$C_SIM_DIR"

