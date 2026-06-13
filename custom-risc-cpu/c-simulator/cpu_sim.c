#include "instructions.h"
#include "memory.h"
#include "registers.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_PROGRAM_WORDS MEMORY_SIZE
#define EXECUTION_LIMIT 10000

static bool load_program(const char *path, int memory[MEMORY_SIZE], int *program_words)
{
    FILE *file = fopen(path, "r");
    if (file == NULL) {
        fprintf(stderr, "error: could not open program '%s'\n", path);
        return false;
    }

    int value = 0;
    int count = 0;
    while (fscanf(file, "%d", &value) == 1) {
        if (count >= MAX_PROGRAM_WORDS) {
            fprintf(stderr, "error: program is larger than %d memory words\n", MAX_PROGRAM_WORDS);
            fclose(file);
            return false;
        }
        memory[count++] = value;
    }

    if (ferror(file)) {
        fprintf(stderr, "error: failed while reading '%s'\n", path);
        fclose(file);
        return false;
    }

    fclose(file);
    *program_words = count;
    return true;
}

static bool require_register(int reg, int pc)
{
    if (!register_is_valid(reg)) {
        fprintf(stderr, "runtime error at PC %d: invalid register R%d\n", pc, reg);
        return false;
    }
    return true;
}

static bool require_memory_addr(int addr, int pc)
{
    if (!memory_addr_is_valid(addr)) {
        fprintf(stderr, "runtime error at PC %d: invalid memory address %d\n", pc, addr);
        return false;
    }
    return true;
}

static bool require_target(int target, int pc)
{
    if (target < 0 || target > MEMORY_SIZE - INSTR_WIDTH || target % INSTR_WIDTH != 0) {
        fprintf(stderr, "runtime error at PC %d: invalid jump target %d\n", pc, target);
        return false;
    }
    return true;
}

static void print_usage(const char *program_name)
{
    fprintf(stderr, "usage: %s program.bin [--trace]\n", program_name);
}

int main(int argc, char **argv)
{
    if (argc < 2 || argc > 3) {
        print_usage(argv[0]);
        return 1;
    }

    bool trace = false;
    if (argc == 3) {
        if (strcmp(argv[2], "--trace") != 0) {
            print_usage(argv[0]);
            return 1;
        }
        trace = true;
    }

    int memory[MEMORY_SIZE];
    int registers[NUM_REGISTERS];
    int program_words = 0;
    memory_init(memory);
    registers_init(registers);

    if (!load_program(argv[1], memory, &program_words)) {
        return 1;
    }
    if (program_words == 0 || program_words % INSTR_WIDTH != 0) {
        fprintf(stderr, "error: program must contain complete %d-word instructions\n", INSTR_WIDTH);
        return 1;
    }

    int pc = 0;
    int steps = 0;
    bool halted = false;

    while (!halted) {
        if (steps >= EXECUTION_LIMIT) {
            fprintf(stderr, "runtime error: execution limit of %d steps reached\n", EXECUTION_LIMIT);
            return 1;
        }
        if (pc < 0 || pc > MEMORY_SIZE - INSTR_WIDTH || pc % INSTR_WIDTH != 0) {
            fprintf(stderr, "runtime error: PC out of bounds or misaligned (%d)\n", pc);
            return 1;
        }

        int opcode = memory[pc];
        int a = memory[pc + 1];
        int b = memory[pc + 2];
        int c = memory[pc + 3];
        int next_pc = pc + INSTR_WIDTH;

        if (trace) {
            printf("step=%d pc=%d opcode=%s(%d) a=%d b=%d c=%d\n",
                   steps, pc, opcode_name(opcode), opcode, a, b, c);
        }

        switch (opcode) {
        case OP_NOP:
            break;
        case OP_LOAD:
            if (!require_register(a, pc) || !require_memory_addr(b, pc)) return 1;
            registers[a] = memory[b];
            break;
        case OP_STORE:
            if (!require_register(a, pc) || !require_memory_addr(b, pc)) return 1;
            memory[b] = registers[a];
            break;
        case OP_MOVI:
            if (!require_register(a, pc)) return 1;
            registers[a] = b;
            break;
        case OP_ADD:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return 1;
            registers[a] = registers[b] + registers[c];
            break;
        case OP_SUB:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return 1;
            registers[a] = registers[b] - registers[c];
            break;
        case OP_JMP:
            if (!require_target(a, pc)) return 1;
            next_pc = a;
            break;
        case OP_BEQ:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_target(c, pc)) return 1;
            if (registers[a] == registers[b]) {
                next_pc = c;
            }
            break;
        case OP_BNE:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_target(c, pc)) return 1;
            if (registers[a] != registers[b]) {
                next_pc = c;
            }
            break;
        case OP_HALT:
            halted = true;
            break;
        default:
            fprintf(stderr, "runtime error at PC %d: unknown opcode %d\n", pc, opcode);
            return 1;
        }

        pc = next_pc;
        steps++;
    }

    printf("Program halted after %d steps.\n", steps);
    registers_dump(registers);
    memory_dump_nonzero(memory);
    return 0;
}
