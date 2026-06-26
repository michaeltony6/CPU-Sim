#include "instructions.h"
#include "memory.h"

#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

static bool read_word(FILE *file, const char *path, int *value)
{
    char token[64];
    if (fscanf(file, "%63s", token) != 1) {
        return false;
    }

    char *end = NULL;
    errno = 0;
    long parsed = strtol(token, &end, 0);
    if (end == token || *end != '\0' || errno == ERANGE || parsed < INT_MIN || parsed > INT_MAX) {
        fprintf(stderr, "error: invalid integer token '%s' in '%s'\n", token, path);
        exit(1);
    }

    *value = (int)parsed;
    return true;
}

static void print_instruction(int pc, int opcode, int a, int b, int c)
{
    printf("%04d: ", pc);
    switch (opcode) {
    case OP_NOP:
    case OP_HALT:
    case OP_RET:
        printf("%s\n", opcode_name(opcode));
        break;
    case OP_LOAD:
        printf("LOAD R%d, %d\n", a, b);
        break;
    case OP_STORE:
        printf("STORE R%d, %d\n", a, b);
        break;
    case OP_MOVI:
        printf("MOVI R%d, %d\n", a, b);
        break;
    case OP_ADD:
    case OP_SUB:
    case OP_AND:
    case OP_OR:
    case OP_XOR:
        printf("%s R%d, R%d, R%d\n", opcode_name(opcode), a, b, c);
        break;
    case OP_ADDI:
    case OP_SHL:
    case OP_SHR:
        printf("%s R%d, R%d, %d\n", opcode_name(opcode), a, b, c);
        break;
    case OP_LOADR:
        printf("LOADR R%d, R%d\n", a, b);
        break;
    case OP_STORER:
        printf("STORER R%d, R%d\n", a, b);
        break;
    case OP_JMP:
    case OP_CALL:
        printf("%s %d\n", opcode_name(opcode), a);
        break;
    case OP_BEQ:
    case OP_BNE:
    case OP_JLT:
    case OP_JGT:
        printf("%s R%d, R%d, %d\n", opcode_name(opcode), a, b, c);
        break;
    case OP_PUSH:
    case OP_POP:
        printf("%s R%d\n", opcode_name(opcode), a);
        break;
    default:
        printf(".word %d %d %d %d ; unknown opcode\n", opcode, a, b, c);
        break;
    }
}

static void print_usage(const char *program_name)
{
    fprintf(stderr, "usage: %s program.bin\n", program_name);
}

int main(int argc, char **argv)
{
    if (argc != 2) {
        print_usage(argv[0]);
        return 1;
    }

    FILE *file = fopen(argv[1], "r");
    if (file == NULL) {
        fprintf(stderr, "error: could not open '%s'\n", argv[1]);
        return 1;
    }

    int words[INSTR_WIDTH];
    int pc = 0;
    while (read_word(file, argv[1], &words[0])) {
        for (int i = 1; i < INSTR_WIDTH; i++) {
            if (!read_word(file, argv[1], &words[i])) {
                fprintf(stderr, "error: incomplete instruction at PC %d\n", pc);
                fclose(file);
                return 1;
            }
        }
        if (pc >= MEMORY_SIZE) {
            fprintf(stderr, "error: program exceeds %d-word memory\n", MEMORY_SIZE);
            fclose(file);
            return 1;
        }
        print_instruction(pc, words[0], words[1], words[2], words[3]);
        pc += INSTR_WIDTH;
    }

    fclose(file);
    return 0;
}
