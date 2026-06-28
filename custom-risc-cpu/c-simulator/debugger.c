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
#define MAX_BREAKPOINTS 64
#define COMMAND_LEN 256

typedef struct {
    bool zero;
    bool negative;
    bool carry;
} Flags;

typedef struct {
    int memory[MEMORY_SIZE];
    int registers[NUM_REGISTERS];
    int pc;
    int steps;
    bool halted;
    Flags flags;
} Machine;

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

static bool load_program(const char *path, Machine *machine)
{
    FILE *file = fopen(path, "r");
    if (file == NULL) {
        fprintf(stderr, "error: could not open program '%s'\n", path);
        return false;
    }

    memory_init(machine->memory);
    registers_init(machine->registers);
    machine->registers[STACK_POINTER_REG] = MEMORY_SIZE;
    machine->pc = 0;
    machine->steps = 0;
    machine->halted = false;
    machine->flags.zero = false;
    machine->flags.negative = false;
    machine->flags.carry = false;

    char token[64];
    int count = 0;
    while (fscanf(file, "%63s", token) == 1) {
        int value = 0;
        if (!parse_int_token(token, &value)) {
            fprintf(stderr, "error: invalid integer token '%s'\n", token);
            fclose(file);
            return false;
        }
        if (count >= MEMORY_SIZE) {
            fprintf(stderr, "error: program is larger than %d words\n", MEMORY_SIZE);
            fclose(file);
            return false;
        }
        machine->memory[count++] = value;
    }
    fclose(file);
    return count > 0 && count % INSTR_WIDTH == 0;
}

static bool valid_register(int reg)
{
    return reg >= 0 && reg < NUM_REGISTERS;
}

static bool valid_address(int addr)
{
    return addr >= 0 && addr < MEMORY_SIZE;
}

static bool valid_target(int target)
{
    return target >= 0 && target <= MEMORY_SIZE - INSTR_WIDTH && target % INSTR_WIDTH == 0;
}

static void update_flags(Machine *machine, int value, bool carry)
{
    machine->flags.zero = (value == 0);
    machine->flags.negative = (value < 0);
    machine->flags.carry = carry;
}

static bool push_value(Machine *machine, int value)
{
    int next_sp = machine->registers[STACK_POINTER_REG] - 1;
    if (!valid_address(next_sp)) {
        fprintf(stderr, "debugger runtime error: stack push out of bounds (%d)\n", next_sp);
        return false;
    }
    machine->registers[STACK_POINTER_REG] = next_sp;
    machine->memory[next_sp] = value;
    return true;
}

static bool pop_value(Machine *machine, int *value)
{
    int sp = machine->registers[STACK_POINTER_REG];
    if (!valid_address(sp)) {
        fprintf(stderr, "debugger runtime error: stack pop out of bounds (%d)\n", sp);
        return false;
    }
    *value = machine->memory[sp];
    machine->registers[STACK_POINTER_REG] = sp + 1;
    return true;
}

static const char *format_instruction(int opcode, int a, int b, int c, char *buffer, size_t size)
{
    switch (opcode) {
    case OP_NOP:
    case OP_HALT:
    case OP_RET:
        snprintf(buffer, size, "%s", opcode_name(opcode));
        break;
    case OP_LOAD:
        snprintf(buffer, size, "LOAD R%d, %d", a, b);
        break;
    case OP_STORE:
        snprintf(buffer, size, "STORE R%d, %d", a, b);
        break;
    case OP_MOVI:
        snprintf(buffer, size, "MOVI R%d, %d", a, b);
        break;
    case OP_ADD:
    case OP_SUB:
    case OP_AND:
    case OP_OR:
    case OP_XOR:
        snprintf(buffer, size, "%s R%d, R%d, R%d", opcode_name(opcode), a, b, c);
        break;
    case OP_ADDI:
    case OP_SHL:
    case OP_SHR:
        snprintf(buffer, size, "%s R%d, R%d, %d", opcode_name(opcode), a, b, c);
        break;
    case OP_LOADR:
        snprintf(buffer, size, "LOADR R%d, R%d", a, b);
        break;
    case OP_STORER:
        snprintf(buffer, size, "STORER R%d, R%d", a, b);
        break;
    case OP_JMP:
    case OP_CALL:
        snprintf(buffer, size, "%s %d", opcode_name(opcode), a);
        break;
    case OP_BEQ:
    case OP_BNE:
    case OP_JLT:
    case OP_JGT:
        snprintf(buffer, size, "%s R%d, R%d, %d", opcode_name(opcode), a, b, c);
        break;
    case OP_PUSH:
    case OP_POP:
        snprintf(buffer, size, "%s R%d", opcode_name(opcode), a);
        break;
    default:
        snprintf(buffer, size, ".word %d %d %d %d", opcode, a, b, c);
        break;
    }
    return buffer;
}

static bool step_machine(Machine *machine, bool verbose)
{
    if (machine->halted) {
        puts("machine already halted");
        return true;
    }
    if (machine->steps >= EXECUTION_LIMIT) {
        fprintf(stderr, "debugger runtime error: execution limit reached\n");
        return false;
    }
    if (!valid_target(machine->pc)) {
        fprintf(stderr, "debugger runtime error: invalid PC %d\n", machine->pc);
        return false;
    }

    int pc = machine->pc;
    int opcode = machine->memory[pc];
    int a = machine->memory[pc + 1];
    int b = machine->memory[pc + 2];
    int c = machine->memory[pc + 3];
    int next_pc = pc + INSTR_WIDTH;
    char text[128];
    if (verbose) {
        printf("step=%d pc=%d %s\n", machine->steps, pc, format_instruction(opcode, a, b, c, text, sizeof(text)));
    }

    switch (opcode) {
    case OP_NOP:
        break;
    case OP_LOAD:
        if (!valid_register(a) || !valid_address(b)) return false;
        machine->registers[a] = machine->memory[b];
        update_flags(machine, machine->registers[a], false);
        break;
    case OP_STORE:
        if (!valid_register(a) || !valid_address(b)) return false;
        machine->memory[b] = machine->registers[a];
        break;
    case OP_MOVI:
        if (!valid_register(a)) return false;
        machine->registers[a] = b;
        update_flags(machine, machine->registers[a], false);
        break;
    case OP_ADD:
    case OP_SUB:
        if (!valid_register(a) || !valid_register(b) || !valid_register(c)) return false;
        {
            long long result = opcode == OP_ADD ?
                (long long)machine->registers[b] + machine->registers[c] :
                (long long)machine->registers[b] - machine->registers[c];
            machine->registers[a] = (int)result;
            update_flags(machine, machine->registers[a], result > INT_MAX || result < INT_MIN);
        }
        break;
    case OP_JMP:
        if (!valid_target(a)) return false;
        next_pc = a;
        break;
    case OP_BEQ:
    case OP_BNE:
    case OP_JLT:
    case OP_JGT:
        if (!valid_register(a) || !valid_register(b) || !valid_target(c)) return false;
        if ((opcode == OP_BEQ && machine->registers[a] == machine->registers[b]) ||
            (opcode == OP_BNE && machine->registers[a] != machine->registers[b]) ||
            (opcode == OP_JLT && machine->registers[a] < machine->registers[b]) ||
            (opcode == OP_JGT && machine->registers[a] > machine->registers[b])) {
            next_pc = c;
        }
        break;
    case OP_HALT:
        machine->halted = true;
        break;
    case OP_ADDI:
        if (!valid_register(a) || !valid_register(b)) return false;
        {
            long long result = (long long)machine->registers[b] + c;
            machine->registers[a] = (int)result;
            update_flags(machine, machine->registers[a], result > INT_MAX || result < INT_MIN);
        }
        break;
    case OP_AND:
    case OP_OR:
    case OP_XOR:
        if (!valid_register(a) || !valid_register(b) || !valid_register(c)) return false;
        if (opcode == OP_AND) machine->registers[a] = machine->registers[b] & machine->registers[c];
        if (opcode == OP_OR) machine->registers[a] = machine->registers[b] | machine->registers[c];
        if (opcode == OP_XOR) machine->registers[a] = machine->registers[b] ^ machine->registers[c];
        update_flags(machine, machine->registers[a], false);
        break;
    case OP_SHL:
    case OP_SHR:
        if (!valid_register(a) || !valid_register(b) || c < 0 || c > 31) return false;
        machine->registers[a] = opcode == OP_SHL ?
            (int)((unsigned int)machine->registers[b] << c) :
            (int)((unsigned int)machine->registers[b] >> c);
        update_flags(machine, machine->registers[a], false);
        break;
    case OP_LOADR:
        if (!valid_register(a) || !valid_register(b) || !valid_address(machine->registers[b])) return false;
        machine->registers[a] = machine->memory[machine->registers[b]];
        update_flags(machine, machine->registers[a], false);
        break;
    case OP_STORER:
        if (!valid_register(a) || !valid_register(b) || !valid_address(machine->registers[b])) return false;
        machine->memory[machine->registers[b]] = machine->registers[a];
        break;
    case OP_PUSH:
        if (!valid_register(a) || !push_value(machine, machine->registers[a])) return false;
        break;
    case OP_POP:
        if (!valid_register(a) || !pop_value(machine, &machine->registers[a])) return false;
        update_flags(machine, machine->registers[a], false);
        break;
    case OP_CALL:
        if (!valid_target(a) || !push_value(machine, next_pc)) return false;
        next_pc = a;
        break;
    case OP_RET:
        if (!pop_value(machine, &next_pc) || !valid_target(next_pc)) return false;
        break;
    default:
        fprintf(stderr, "debugger runtime error: unknown opcode %d at PC %d\n", opcode, pc);
        return false;
    }
    machine->pc = next_pc;
    machine->steps++;
    return true;
}

static void print_registers(const Machine *machine)
{
    for (int i = 0; i < NUM_REGISTERS; i++) {
        printf("R%d=%d%s", i, machine->registers[i], i == NUM_REGISTERS - 1 ? "\n" : " ");
    }
    printf("PC=%d steps=%d halted=%d flags=Z%d/N%d/C%d\n",
           machine->pc, machine->steps, machine->halted,
           machine->flags.zero, machine->flags.negative, machine->flags.carry);
}

static void print_memory(const Machine *machine, int start, int count)
{
    for (int i = 0; i < count; i++) {
        int addr = start + i;
        if (!valid_address(addr)) {
            break;
        }
        printf("MEM[%d]=%d\n", addr, machine->memory[addr]);
    }
}

static void print_disassembly(const Machine *machine, int start, int count)
{
    char text[128];
    for (int i = 0; i < count; i++) {
        int pc = start + i * INSTR_WIDTH;
        if (!valid_target(pc)) {
            break;
        }
        printf("%04d: %s\n", pc, format_instruction(machine->memory[pc], machine->memory[pc + 1],
                                                     machine->memory[pc + 2], machine->memory[pc + 3],
                                                     text, sizeof(text)));
    }
}

static bool has_breakpoint(const int breakpoints[MAX_BREAKPOINTS], int count, int pc)
{
    for (int i = 0; i < count; i++) {
        if (breakpoints[i] == pc) {
            return true;
        }
    }
    return false;
}

static void print_help(void)
{
    puts("Commands:");
    puts("  help                 show this command list");
    puts("  regs                 print registers, PC, flags");
    puts("  mem <addr> [count]   print memory words");
    puts("  disasm [pc] [count]  disassemble memory");
    puts("  step [count]         execute one or more instructions");
    puts("  run                  run until halt or breakpoint");
    puts("  break <pc>           add breakpoint");
    puts("  clear                remove all breakpoints");
    puts("  quit                 exit debugger");
}

static bool process_command(Machine *machine, char *line, int breakpoints[MAX_BREAKPOINTS], int *breakpoint_count)
{
    char *cmd = strtok(line, " \t\r\n");
    if (cmd == NULL) {
        return true;
    }
    if (strcmp(cmd, "help") == 0) {
        print_help();
    } else if (strcmp(cmd, "regs") == 0) {
        print_registers(machine);
    } else if (strcmp(cmd, "mem") == 0) {
        char *addr_text = strtok(NULL, " \t\r\n");
        char *count_text = strtok(NULL, " \t\r\n");
        int addr = 0;
        int count = 1;
        if (addr_text == NULL || !parse_int_token(addr_text, &addr)) {
            puts("usage: mem <addr> [count]");
            return true;
        }
        if (count_text != NULL && !parse_int_token(count_text, &count)) {
            puts("usage: mem <addr> [count]");
            return true;
        }
        print_memory(machine, addr, count);
    } else if (strcmp(cmd, "disasm") == 0) {
        char *pc_text = strtok(NULL, " \t\r\n");
        char *count_text = strtok(NULL, " \t\r\n");
        int pc = machine->pc;
        int count = 8;
        if (pc_text != NULL && !parse_int_token(pc_text, &pc)) {
            puts("usage: disasm [pc] [count]");
            return true;
        }
        if (count_text != NULL && !parse_int_token(count_text, &count)) {
            puts("usage: disasm [pc] [count]");
            return true;
        }
        print_disassembly(machine, pc, count);
    } else if (strcmp(cmd, "step") == 0) {
        char *count_text = strtok(NULL, " \t\r\n");
        int count = 1;
        if (count_text != NULL && !parse_int_token(count_text, &count)) {
            puts("usage: step [count]");
            return true;
        }
        for (int i = 0; i < count && !machine->halted; i++) {
            if (!step_machine(machine, true)) {
                return false;
            }
        }
    } else if (strcmp(cmd, "run") == 0) {
        while (!machine->halted) {
            if (*breakpoint_count > 0 && has_breakpoint(breakpoints, *breakpoint_count, machine->pc)) {
                printf("hit breakpoint at PC %d\n", machine->pc);
                break;
            }
            if (!step_machine(machine, false)) {
                return false;
            }
        }
        if (machine->halted) {
            puts("program halted");
        }
    } else if (strcmp(cmd, "break") == 0) {
        char *pc_text = strtok(NULL, " \t\r\n");
        int pc = 0;
        if (pc_text == NULL || !parse_int_token(pc_text, &pc) || !valid_target(pc)) {
            puts("usage: break <word-aligned-pc>");
            return true;
        }
        if (*breakpoint_count < MAX_BREAKPOINTS) {
            breakpoints[*breakpoint_count] = pc;
            (*breakpoint_count)++;
            printf("breakpoint added at PC %d\n", pc);
        }
    } else if (strcmp(cmd, "clear") == 0) {
        *breakpoint_count = 0;
        puts("breakpoints cleared");
    } else if (strcmp(cmd, "quit") == 0 || strcmp(cmd, "exit") == 0) {
        return false;
    } else {
        printf("unknown command '%s'\n", cmd);
    }
    return true;
}

static void print_usage(const char *program_name)
{
    fprintf(stderr, "usage: %s program.bin [commands.txt]\n", program_name);
}

int main(int argc, char **argv)
{
    if (argc < 2 || argc > 3) {
        print_usage(argv[0]);
        return 1;
    }

    Machine machine;
    if (!load_program(argv[1], &machine)) {
        return 1;
    }

    FILE *input = stdin;
    bool scripted = false;
    if (argc == 3) {
        input = fopen(argv[2], "r");
        if (input == NULL) {
            fprintf(stderr, "error: could not open command script '%s'\n", argv[2]);
            return 1;
        }
        scripted = true;
    }

    int breakpoints[MAX_BREAKPOINTS];
    int breakpoint_count = 0;
    char line[COMMAND_LEN];
    puts("Custom RISC CPU debugger ready. Type 'help' for commands.");
    while (true) {
        if (!scripted) {
            printf("cpu-debug> ");
            fflush(stdout);
        }
        if (fgets(line, sizeof(line), input) == NULL) {
            break;
        }
        if (!process_command(&machine, line, breakpoints, &breakpoint_count)) {
            break;
        }
    }

    if (scripted) {
        fclose(input);
    }
    return 0;
}
