#include "instructions.h"
#include "memory.h"
#include "registers.h"

#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define EXECUTION_LIMIT 10000
#define STACK_POINTER_REG 7
#define MMIO_OUTPUT_ADDR 255
#define MAX_OPCODE_VALUE OP_RET

typedef struct {
    bool zero;
    bool negative;
    bool carry;
} Flags;

typedef struct {
    long steps;
    long opcode_counts[MAX_OPCODE_VALUE + 1];
    long register_writes[NUM_REGISTERS];
    long register_reads[NUM_REGISTERS];
    long memory_reads;
    long memory_writes;
    long branch_count;
    long branch_taken;
    long jumps;
    long calls;
    long returns;
    long pushes;
    long pops;
    long mmio_outputs;
    int min_stack_pointer;
    int max_pc;
} Profile;

static bool parse_int_token(const char *token, int *value)
{
    char *end = NULL;
    errno = 0;
    long parsed = strtol(token, &end, 0);
    if (end == token || *end != '\0' || errno == ERANGE || parsed < INT_MIN || parsed > INT_MAX) {
        return false;
    }
    *value = (int)parsed;
    return true;
}

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
        int value = 0;
        if (!parse_int_token(token, &value)) {
            fprintf(stderr, "error: invalid integer token '%s' in '%s'\n", token, path);
            fclose(file);
            return false;
        }
        if (count >= MEMORY_SIZE) {
            fprintf(stderr, "error: program is larger than %d memory words\n", MEMORY_SIZE);
            fclose(file);
            return false;
        }
        memory[count++] = value;
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

static void record_read(Profile *profile, int reg)
{
    if (register_is_valid(reg)) {
        profile->register_reads[reg]++;
    }
}

static void record_write(Profile *profile, int reg)
{
    if (register_is_valid(reg)) {
        profile->register_writes[reg]++;
    }
}

static void write_register(Profile *profile, Flags *flags, int registers[NUM_REGISTERS], int reg, int value, bool carry)
{
    registers[reg] = value;
    record_write(profile, reg);
    update_flags(flags, value, carry);
}

static bool push_value(Profile *profile, int memory[MEMORY_SIZE], int registers[NUM_REGISTERS], int value, int pc)
{
    int next_sp = registers[STACK_POINTER_REG] - 1;
    if (!require_memory_addr(next_sp, pc)) {
        return false;
    }
    registers[STACK_POINTER_REG] = next_sp;
    memory[next_sp] = value;
    profile->pushes++;
    profile->memory_writes++;
    record_write(profile, STACK_POINTER_REG);
    if (next_sp < profile->min_stack_pointer) {
        profile->min_stack_pointer = next_sp;
    }
    return true;
}

static bool pop_value(Profile *profile, const int memory[MEMORY_SIZE], int registers[NUM_REGISTERS], int *value, int pc)
{
    int sp = registers[STACK_POINTER_REG];
    if (!require_memory_addr(sp, pc)) {
        return false;
    }
    *value = memory[sp];
    registers[STACK_POINTER_REG] = sp + 1;
    profile->pops++;
    profile->memory_reads++;
    record_read(profile, STACK_POINTER_REG);
    record_write(profile, STACK_POINTER_REG);
    return true;
}

static bool execute_program(const char *path, bool trace)
{
    int memory[MEMORY_SIZE];
    int registers[NUM_REGISTERS];
    int program_words = 0;
    Flags flags = { false, false, false };
    Profile profile;
    memset(&profile, 0, sizeof(profile));
    profile.min_stack_pointer = MEMORY_SIZE;

    memory_init(memory);
    registers_init(registers);
    registers[STACK_POINTER_REG] = MEMORY_SIZE;

    if (!load_program(path, memory, &program_words)) {
        return false;
    }
    if (program_words == 0 || program_words % INSTR_WIDTH != 0) {
        fprintf(stderr, "error: program must contain complete %d-word instructions\n", INSTR_WIDTH);
        return false;
    }

    int pc = 0;
    bool halted = false;
    while (!halted) {
        if (profile.steps >= EXECUTION_LIMIT) {
            fprintf(stderr, "runtime error: execution limit of %d steps reached\n", EXECUTION_LIMIT);
            return false;
        }
        if (pc < 0 || pc > MEMORY_SIZE - INSTR_WIDTH || pc % INSTR_WIDTH != 0) {
            fprintf(stderr, "runtime error: PC out of bounds or misaligned (%d)\n", pc);
            return false;
        }

        int opcode = memory[pc];
        int a = memory[pc + 1];
        int b = memory[pc + 2];
        int c = memory[pc + 3];
        int next_pc = pc + INSTR_WIDTH;
        bool branch_taken = false;

        if (opcode >= 0 && opcode <= MAX_OPCODE_VALUE) {
            profile.opcode_counts[opcode]++;
        }
        if (pc > profile.max_pc) {
            profile.max_pc = pc;
        }
        if (trace) {
            printf("profile step=%ld pc=%d opcode=%s(%d) a=%d b=%d c=%d\n",
                   profile.steps, pc, opcode_name(opcode), opcode, a, b, c);
        }

        switch (opcode) {
        case OP_NOP:
            break;
        case OP_LOAD:
            if (!require_register(a, pc) || !require_memory_addr(b, pc)) return false;
            profile.memory_reads++;
            write_register(&profile, &flags, registers, a, memory[b], false);
            break;
        case OP_STORE:
            if (!require_register(a, pc) || !require_memory_addr(b, pc)) return false;
            record_read(&profile, a);
            memory[b] = registers[a];
            profile.memory_writes++;
            if (b == MMIO_OUTPUT_ADDR) profile.mmio_outputs++;
            break;
        case OP_MOVI:
            if (!require_register(a, pc)) return false;
            write_register(&profile, &flags, registers, a, b, false);
            break;
        case OP_ADD:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return false;
            record_read(&profile, b);
            record_read(&profile, c);
            {
                long long result = (long long)registers[b] + registers[c];
                write_register(&profile, &flags, registers, a, (int)result, result > INT_MAX || result < INT_MIN);
            }
            break;
        case OP_SUB:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return false;
            record_read(&profile, b);
            record_read(&profile, c);
            {
                long long result = (long long)registers[b] - registers[c];
                write_register(&profile, &flags, registers, a, (int)result, result > INT_MAX || result < INT_MIN);
            }
            break;
        case OP_JMP:
            if (!require_target(a, pc)) return false;
            profile.jumps++;
            next_pc = a;
            break;
        case OP_BEQ:
        case OP_BNE:
        case OP_JLT:
        case OP_JGT:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_target(c, pc)) return false;
            profile.branch_count++;
            record_read(&profile, a);
            record_read(&profile, b);
            if ((opcode == OP_BEQ && registers[a] == registers[b]) ||
                (opcode == OP_BNE && registers[a] != registers[b]) ||
                (opcode == OP_JLT && registers[a] < registers[b]) ||
                (opcode == OP_JGT && registers[a] > registers[b])) {
                next_pc = c;
                branch_taken = true;
                profile.branch_taken++;
            }
            break;
        case OP_HALT:
            halted = true;
            break;
        case OP_ADDI:
            if (!require_register(a, pc) || !require_register(b, pc)) return false;
            record_read(&profile, b);
            {
                long long result = (long long)registers[b] + c;
                write_register(&profile, &flags, registers, a, (int)result, result > INT_MAX || result < INT_MIN);
            }
            break;
        case OP_AND:
        case OP_OR:
        case OP_XOR:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_register(c, pc)) return false;
            record_read(&profile, b);
            record_read(&profile, c);
            if (opcode == OP_AND) write_register(&profile, &flags, registers, a, registers[b] & registers[c], false);
            if (opcode == OP_OR) write_register(&profile, &flags, registers, a, registers[b] | registers[c], false);
            if (opcode == OP_XOR) write_register(&profile, &flags, registers, a, registers[b] ^ registers[c], false);
            break;
        case OP_SHL:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_shift_amount(c, pc)) return false;
            record_read(&profile, b);
            write_register(&profile, &flags, registers, a, (int)((unsigned int)registers[b] << c),
                           c != 0 && (((unsigned int)registers[b] >> (32 - c)) != 0));
            break;
        case OP_SHR:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_shift_amount(c, pc)) return false;
            record_read(&profile, b);
            write_register(&profile, &flags, registers, a, (int)((unsigned int)registers[b] >> c), false);
            break;
        case OP_LOADR:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_memory_addr(registers[b], pc)) return false;
            record_read(&profile, b);
            profile.memory_reads++;
            write_register(&profile, &flags, registers, a, memory[registers[b]], false);
            break;
        case OP_STORER:
            if (!require_register(a, pc) || !require_register(b, pc) || !require_memory_addr(registers[b], pc)) return false;
            record_read(&profile, a);
            record_read(&profile, b);
            memory[registers[b]] = registers[a];
            profile.memory_writes++;
            if (registers[b] == MMIO_OUTPUT_ADDR) profile.mmio_outputs++;
            break;
        case OP_PUSH:
            if (!require_register(a, pc)) return false;
            record_read(&profile, a);
            if (!push_value(&profile, memory, registers, registers[a], pc)) return false;
            break;
        case OP_POP:
            if (!require_register(a, pc)) return false;
            {
                int value = 0;
                if (!pop_value(&profile, memory, registers, &value, pc)) return false;
                write_register(&profile, &flags, registers, a, value, false);
            }
            break;
        case OP_CALL:
            if (!require_target(a, pc) || !push_value(&profile, memory, registers, next_pc, pc)) return false;
            profile.calls++;
            next_pc = a;
            break;
        case OP_RET:
            {
                int target = 0;
                if (!pop_value(&profile, memory, registers, &target, pc) || !require_target(target, pc)) return false;
                profile.returns++;
                next_pc = target;
            }
            break;
        default:
            fprintf(stderr, "runtime error at PC %d: unknown opcode %d\n", pc, opcode);
            return false;
        }

        if (trace && (opcode == OP_BEQ || opcode == OP_BNE || opcode == OP_JLT || opcode == OP_JGT)) {
            printf("  branch %s\n", branch_taken ? "taken" : "not taken");
        }
        pc = next_pc;
        profile.steps++;
    }

    printf("Profile for %s\n", path);
    printf("  steps: %ld\n", profile.steps);
    printf("  max_pc: %d\n", profile.max_pc);
    printf("  branches: %ld taken: %ld\n", profile.branch_count, profile.branch_taken);
    printf("  jumps: %ld calls: %ld returns: %ld\n", profile.jumps, profile.calls, profile.returns);
    printf("  pushes: %ld pops: %ld min_sp: %d\n", profile.pushes, profile.pops, profile.min_stack_pointer);
    printf("  memory_reads: %ld memory_writes: %ld mmio_outputs: %ld\n",
           profile.memory_reads, profile.memory_writes, profile.mmio_outputs);
    printf("  flags: Z=%d N=%d C=%d\n", flags.zero, flags.negative, flags.carry);
    printf("  final MEM[250]: %d\n", memory[250]);
    printf("Opcode histogram:\n");
    for (int i = 0; i <= MAX_OPCODE_VALUE; i++) {
        if (profile.opcode_counts[i] > 0) {
            printf("  %-7s %ld\n", opcode_name(i), profile.opcode_counts[i]);
        }
    }
    printf("Register reads/writes:\n");
    for (int i = 0; i < NUM_REGISTERS; i++) {
        printf("  R%d reads=%ld writes=%ld final=%d\n",
               i, profile.register_reads[i], profile.register_writes[i], registers[i]);
    }
    return true;
}

static void print_usage(const char *program_name)
{
    fprintf(stderr, "usage: %s program.bin [--trace]\n", program_name);
}

int main(int argc, char **argv)
{
    bool trace = false;
    if (argc < 2 || argc > 3) {
        print_usage(argv[0]);
        return 1;
    }
    if (argc == 3) {
        if (strcmp(argv[2], "--trace") != 0) {
            print_usage(argv[0]);
            return 1;
        }
        trace = true;
    }
    return execute_program(argv[1], trace) ? 0 : 1;
}
