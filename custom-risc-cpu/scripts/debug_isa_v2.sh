#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
C_SIM_DIR="$ROOT_DIR/c-simulator"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$C_SIM_DIR"
make >/dev/null

./assembler programs/isa_v2_demo.asm "$TMP_DIR/isa_v2_demo.bin" >/dev/null

cat > "$TMP_DIR/debugger.commands" <<'CMDS'
disasm 0 12
step 4
regs
break 100
run
regs
clear
run
mem 250 6
quit
CMDS

printf 'Running scripted debugger session for isa_v2_demo.asm...\n\n'
./debugger "$TMP_DIR/isa_v2_demo.bin" "$TMP_DIR/debugger.commands"

printf '\nExpected finish: MEM[250]=20 and MEM[255]=20.\n'

