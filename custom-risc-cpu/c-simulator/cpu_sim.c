#include "instructions.h"
#include "memory.h"
#include "registers.h"

#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_PROGRAM_WORDS MEMORY_SIZE
#define EXECUTION_LIMIT 10000
#define STACK_POINTER_REG 7
#define MMIO_OUTPUT_ADDR 255

typedef struct {
    bool zero;
    bool negative;
    bool carry;
} Flags;

static bool load_program(const char *path, int memory[MEMORY_SIZE], int *program_words)
{
    FILE *file = fopen(path, "r");
    if (file == NULL) {
        fprintf(stderr, "error: could not open program '%s'\n", path);
        return false;
    }

    char token[64];
    int count = 0;
    while (fscanf(file, "%63s", token) == 1) {
        char *end = NULL;
        errno = 0;
        long parsed = strtol(token, &end, 0);
        if (end == token || *end != '\0' || errno == ERANGE || parsed < INT_MIN || parsed > INT_MAX) {
            fprintf(stderr, "error: invalid integer token '%s' in '%s'\n", token, path);
            fclose(file);
            return false;
        }
        if (count >= MAX_PROGRAM_WORDS) {
            fprintf(stderr, "error: program is larger than %d memory words\n", MAX_PROGRAM_WORDS);
            fclose(file);
            return false;
        }
        memory[count++] = (int)parsed;
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

static bool require_shift_amount(int amount, int pc)
{
    if (amount < 0 || amount > 31) {
        fprintf(stderr, "runtime error at PC %d: invalid shift amount %d\n", pc, amount);
        return false;
    }
    return true;
}

static void update_flags(Flags *flags, int value, bool carry)
{
    flags->zero = (value == 0);
    flags->negative = (value < 0);
    flags->carry = carry;
}

static bool push_value(int memory[MEMORY_SIZE], int registers[NUM_REGISTERS], int value, int pc)
{
    int next_sp = registers[STACK_POINTER_REG] - 1;
    if (!require_memory_addr(next_sp, pc)) {
        return false;
    }
    registers[STACK_POINTER_REG] = next_sp;
    memory[next_sp] = value;
    return true;
}

static bool pop_value(const int memory[MEMORY_SIZE], int registers[NUM_REGISTERS], int *value, int pc)
{
    int sp = registers[STACK_POINTER_REG];
    if (!require_memory_addr(sp, pc)) {
        return false;
    }
    *value = memory[sp];
    registers[STACK_POINTER_REG] = sp + 1;
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
    registers[STACK_POINTER_REG] = MEMORY_SIZE;

    if (!load_program(argv[1], memory, &program_words)) {
        return 1;
    }
    if (program_words == 0 || program_words % INSTR_WIDTH != 0) {
        fprintf(stderr, "error: program must contain complete %d-word instructions\n", INSTR_WIDTH);
        return 1;
    }

    int pc = 0;
    int steps = 0;
    Flags flags = { false, false, false };
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
            update_flags(&flags, registers[a], false);
            break;
        case OP_STORE:
            if (!require_register(a, pc) || !require_memory_addr(b, pc)) return 1;
            memory[b] = registers[a];
            if (b == MMIO_OUTPUT_ADDR) {
                printf("MMIO[255] output = %d\n", registers[a]);
            }
            break;
        case OP_MOVI:
            if (!require_register(a, pc)) return 1;
            registers[a] = b;
            update_flags(&flags, registers[a], false);
            break;
        case OP_ADD:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return 1;
            {
                long long result = (long long)registers[b] + registers[c];
                registers[a] = (int)result;
                update_flags(&flags, registers[a], result > INT_MAX || result < INT_MIN);
            }
            break;
        case OP_SUB:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return 1;
            {
                long long result = (long long)registers[b] - registers[c];
                registers[a] = (int)result;
                update_flags(&flags, registers[a], result > INT_MAX || result < INT_MIN);
            }
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
        case OP_ADDI:
            if (!require_register(a, pc) || !require_register(b, pc)) return 1;
            {
                long long result = (long long)registers[b] + c;
                registers[a] = (int)result;
                update_flags(&flags, registers[a], result > INT_MAX || result < INT_MIN);
            }
            break;
        case OP_AND:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return 1;
            registers[a] = registers[b] & registers[c];
            update_flags(&flags, registers[a], false);
            break;
        case OP_OR:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return 1;
            registers[a] = registers[b] | registers[c];
            update_flags(&flags, registers[a], false);
            break;
        case OP_XOR:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return 1;
            registers[a] = registers[b] ^ registers[c];
            update_flags(&flags, registers[a], false);
            break;
        case OP_SHL:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_shift_amount(c, pc)) return 1;
            registers[a] = (int)((unsigned int)registers[b] << c);
            update_flags(&flags, registers[a], c != 0 && (((unsigned int)registers[b] >> (32 - c)) != 0));
            break;
        case OP_SHR:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_shift_amount(c, pc)) return 1;
            registers[a] = (int)((unsigned int)registers[b] >> c);
            update_flags(&flags, registers[a], false);
            break;
        case OP_LOADR:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_memory_addr(registers[b], pc)) return 1;
            registers[a] = memory[registers[b]];
            update_flags(&flags, registers[a], false);
            break;
        case OP_STORER:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_memory_addr(registers[b], pc)) return 1;
            memory[registers[b]] = registers[a];
            if (registers[b] == MMIO_OUTPUT_ADDR) {
                printf("MMIO[255] output = %d\n", registers[a]);
            }
            break;
        case OP_JLT:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_target(c, pc)) return 1;
            if (registers[a] < registers[b]) {
                next_pc = c;
            }
            break;
        case OP_JGT:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_target(c, pc)) return 1;
            if (registers[a] > registers[b]) {
                next_pc = c;
            }
            break;
        case OP_PUSH:
            if (!require_register(a, pc) || !push_value(memory, registers, registers[a], pc)) return 1;
            break;
        case OP_POP:
            if (!require_register(a, pc) || !pop_value(memory, registers, &registers[a], pc)) return 1;
            update_flags(&flags, registers[a], false);
            break;
        case OP_CALL:
            if (!require_target(a, pc) || !push_value(memory, registers, next_pc, pc)) return 1;
            next_pc = a;
            break;
        case OP_RET:
            if (!pop_value(memory, registers, &next_pc, pc) || !require_target(next_pc, pc)) return 1;
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
    printf("Flags:\n  Z = %d\n  N = %d\n  C = %d\n", flags.zero, flags.negative, flags.carry);
    memory_dump_nonzero(memory);
    return 0;
}
