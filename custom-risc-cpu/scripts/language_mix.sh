#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

add_bytes() {
    language=$1
    bytes=$2
    printf '%s %s\n' "$language" "$bytes" >> "$TMP_FILE"
}

find "$ROOT_DIR" -type f \
    ! -path '*/.git/*' \
    ! -path '*/docs/images/*' \
    ! -name '*.o' \
    ! -name '*.bin' \
    ! -name 'dump.vcd' \
    ! -name 'fault_dump.vcd' \
    ! -name 'cpu_tb*' \
    ! -name 'fault_tb' \
    ! -name 'assembler' \
    ! -name 'cpu_sim' \
    ! -name 'debugger' \
    ! -name 'disassembler' \
    ! -name 'profiler' \
    | while IFS= read -r file; do
        bytes=$(wc -c < "$file" | tr -d ' ')
        case "$file" in
            *.c) add_bytes "C" "$bytes" ;;
            *.h) add_bytes "C-Header" "$bytes" ;;
            *.v) add_bytes "Verilog" "$bytes" ;;
            *.sh) add_bytes "Shell" "$bytes" ;;
            *.js) add_bytes "JavaScript" "$bytes" ;;
            *.css) add_bytes "CSS" "$bytes" ;;
            *.html) add_bytes "HTML" "$bytes" ;;
            *.md) add_bytes "Markdown" "$bytes" ;;
            *.asm) add_bytes "Assembly" "$bytes" ;;
            *.mem) add_bytes "Memory-Image" "$bytes" ;;
            Makefile|*/Makefile) add_bytes "Makefile" "$bytes" ;;
            *) add_bytes "Other" "$bytes" ;;
        esac
    done

total=$(awk '{ sum += $2 } END { print sum + 0 }' "$TMP_FILE")

printf '%-14s %12s %10s\n' "language" "bytes" "percent"
printf '%-14s %12s %10s\n' "--------" "-----" "-------"
awk -v total="$total" '
    {
        bytes[$1] += $2
    }
    END {
        for (language in bytes) {
            percent = total ? (bytes[language] * 100.0 / total) : 0
            printf "%-14s %12d %9.1f%%\n", language, bytes[language], percent
        }
    }
' "$TMP_FILE" | sort -k2,2nr

printf '\nTotal counted bytes: %s\n' "$total"
