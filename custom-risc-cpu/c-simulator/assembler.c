#include "instructions.h"
#include "memory.h"
#include "registers.h"

#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_LINE_LEN 256
#define MAX_LABELS 128
#define MAX_TOKENS 8

typedef struct {
    char name[64];
    int address;
} Label;

static Label labels[MAX_LABELS];
static int label_count = 0;

static char *trim(char *text)
{
    while (isspace((unsigned char)*text)) {
        text++;
    }

    char *end = text + strlen(text);
    while (end > text && isspace((unsigned char)*(end - 1))) {
        end--;
    }
    *end = '\0';
    return text;
}

static void strip_comment(char *line)
{
    char *comment = strchr(line, ';');
    if (comment != NULL) {
        *comment = '\0';
    }
}

static void uppercase(char *text)
{
    for (; *text != '\0'; text++) {
        *text = (char)toupper((unsigned char)*text);
    }
}

static int tokenize(char *line, char *tokens[MAX_TOKENS])
{
    int count = 0;
    char *tok = strtok(line, " \t,\r\n");
    while (tok != NULL) {
        if (count >= MAX_TOKENS) {
            return -1;
        }
        tokens[count++] = tok;
        tok = strtok(NULL, " \t,\r\n");
    }
    return count;
}

static bool parse_int(const char *text, int *value)
{
    char *end = NULL;
    errno = 0;
    long parsed = strtol(text, &end, 0);
    if (end == text || *end != '\0' || errno == ERANGE || parsed < INT_MIN || parsed > INT_MAX) {
        return false;
    }
    *value = (int)parsed;
    return true;
}

static bool parse_register(const char *text, int *reg)
{
    if ((text[0] != 'R' && text[0] != 'r') || text[1] == '\0') {
        return false;
    }

    int value = 0;
    if (!parse_int(text + 1, &value) || !register_is_valid(value)) {
        return false;
    }

    *reg = value;
    return true;
}

static int opcode_from_name(const char *name)
{
    if (strcmp(name, "NOP") == 0) return OP_NOP;
    if (strcmp(name, "LOAD") == 0) return OP_LOAD;
    if (strcmp(name, "STORE") == 0) return OP_STORE;
    if (strcmp(name, "MOVI") == 0) return OP_MOVI;
    if (strcmp(name, "ADD") == 0) return OP_ADD;
    if (strcmp(name, "SUB") == 0) return OP_SUB;
    if (strcmp(name, "JMP") == 0) return OP_JMP;
    if (strcmp(name, "BEQ") == 0) return OP_BEQ;
    if (strcmp(name, "BNE") == 0) return OP_BNE;
    if (strcmp(name, "HALT") == 0) return OP_HALT;
    return -1;
}

static int expected_operands(int opcode)
{
    switch (opcode) {
    case OP_NOP:
    case OP_HALT:
        return 0;
    case OP_JMP:
        return 1;
    case OP_LOAD:
    case OP_STORE:
    case OP_MOVI:
        return 2;
    case OP_ADD:
    case OP_SUB:
    case OP_BEQ:
    case OP_BNE:
        return 3;
    default:
        return -1;
    }
}

static int find_label(const char *name)
{
    for (int i = 0; i < label_count; i++) {
        if (strcmp(labels[i].name, name) == 0) {
            return labels[i].address;
        }
    }
    return -1;
}

static bool label_name_is_valid(const char *name)
{
    if (!(isalpha((unsigned char)name[0]) || name[0] == '_')) {
        return false;
    }

    for (size_t i = 1; name[i] != '\0'; i++) {
        if (!(isalnum((unsigned char)name[i]) || name[i] == '_')) {
            return false;
        }
    }

    return true;
}

static bool add_label(const char *name, int address, int line_no)
{
    if (name[0] == '\0') {
        fprintf(stderr, "line %d: empty label\n", line_no);
        return false;
    }
    if (strlen(name) >= sizeof(labels[0].name)) {
        fprintf(stderr, "line %d: label '%s' is too long (max %zu characters)\n",
                line_no, name, sizeof(labels[0].name) - 1);
        return false;
    }
    if (!label_name_is_valid(name)) {
        fprintf(stderr, "line %d: invalid label '%s' (use letters, numbers, and underscores; do not start with a number)\n",
                line_no, name);
        return false;
    }
    if (find_label(name) >= 0) {
        fprintf(stderr, "line %d: duplicate label '%s'\n", line_no, name);
        return false;
    }
    if (label_count >= MAX_LABELS) {
        fprintf(stderr, "line %d: too many labels (max %d)\n", line_no, MAX_LABELS);
        return false;
    }

    snprintf(labels[label_count].name, sizeof(labels[label_count].name), "%s", name);
    labels[label_count].address = address;
    label_count++;
    return true;
}

static char *consume_label(char *line, int address, int line_no)
{
    char *colon = strchr(line, ':');
    if (colon == NULL) {
        return line;
    }

    *colon = '\0';
    char *label_name = trim(line);
    if (!add_label(label_name, address, line_no)) {
        return NULL;
    }

    return trim(colon + 1);
}

static bool first_pass(const char *input_path, int *instruction_count)
{
    FILE *input = fopen(input_path, "r");
    if (input == NULL) {
        fprintf(stderr, "error: could not open '%s'\n", input_path);
        return false;
    }

    char line[MAX_LINE_LEN];
    int line_no = 0;
    int address = 0;
    while (fgets(line, sizeof(line), input) != NULL) {
        line_no++;
        strip_comment(line);
        char *clean = trim(line);
        if (*clean == '\0') {
            continue;
        }

        clean = consume_label(clean, address, line_no);
        if (clean == NULL) {
            fclose(input);
            return false;
        }
        if (*clean != '\0') {
            address += INSTR_WIDTH;
            if (address > MEMORY_SIZE) {
                fprintf(stderr, "line %d: program exceeds %d-word memory\n", line_no, MEMORY_SIZE);
                fclose(input);
                return false;
            }
        }
    }

    fclose(input);
    *instruction_count = address / INSTR_WIDTH;
    return true;
}

static bool validate_branch_target(int target, int line_no)
{
    if (target < 0 || target > MEMORY_SIZE - INSTR_WIDTH || target % INSTR_WIDTH != 0) {
        fprintf(stderr, "line %d: invalid branch target %d (must be 0-%d and divisible by %d)\n",
                line_no, target, MEMORY_SIZE - INSTR_WIDTH, INSTR_WIDTH);
        return false;
    }
    return true;
}

static bool parse_label_or_address(const char *text, int *target, int line_no)
{
    int label_addr = find_label(text);
    if (label_addr >= 0) {
        *target = label_addr;
        return validate_branch_target(*target, line_no);
    }
    if (parse_int(text, target)) {
        return validate_branch_target(*target, line_no);
    }

    fprintf(stderr, "line %d: unknown label '%s'\n", line_no, text);
    return false;
}

static bool emit_instruction(FILE *output, char *line, int line_no)
{
    char *tokens[MAX_TOKENS];
    int token_count = tokenize(line, tokens);
    if (token_count < 0) {
        fprintf(stderr, "line %d: too many tokens\n", line_no);
        return false;
    }
    if (token_count == 0) {
        return true;
    }

    uppercase(tokens[0]);
    int opcode = opcode_from_name(tokens[0]);
    if (opcode < 0) {
        fprintf(stderr, "line %d: unknown opcode '%s'\n", line_no, tokens[0]);
        return false;
    }

    int expected = expected_operands(opcode);
    if (token_count - 1 != expected) {
        fprintf(stderr, "line %d: %s expects %d operand(s), got %d\n",
                line_no, tokens[0], expected, token_count - 1);
        return false;
    }

    int a = 0;
    int b = 0;
    int c = 0;

    switch (opcode) {
    case OP_LOAD:
    case OP_STORE:
        if (!parse_register(tokens[1], &a)) {
            fprintf(stderr, "line %d: invalid register '%s'\n", line_no, tokens[1]);
            return false;
        }
        if (!parse_int(tokens[2], &b) || !memory_addr_is_valid(b)) {
            fprintf(stderr, "line %d: invalid memory address '%s'\n", line_no, tokens[2]);
            return false;
        }
        break;
    case OP_MOVI:
        if (!parse_register(tokens[1], &a)) {
            fprintf(stderr, "line %d: invalid register '%s'\n", line_no, tokens[1]);
            return false;
        }
        if (!parse_int(tokens[2], &b)) {
            fprintf(stderr, "line %d: invalid immediate '%s'\n", line_no, tokens[2]);
            return false;
        }
        break;
    case OP_ADD:
    case OP_SUB:
        if (!parse_register(tokens[1], &a) || !parse_register(tokens[2], &b) || !parse_register(tokens[3], &c)) {
            fprintf(stderr, "line %d: invalid register operand\n", line_no);
            return false;
        }
        break;
    case OP_JMP:
        if (!parse_label_or_address(tokens[1], &a, line_no)) {
            return false;
        }
        break;
    case OP_BEQ:
    case OP_BNE:
        if (!parse_register(tokens[1], &a) || !parse_register(tokens[2], &b)) {
            fprintf(stderr, "line %d: invalid branch register operand\n", line_no);
            return false;
        }
        if (!parse_label_or_address(tokens[3], &c, line_no)) {
            return false;
        }
        break;
    default:
        break;
    }

    fprintf(output, "%d\n%d\n%d\n%d\n", opcode, a, b, c);
    return true;
}

static bool second_pass(const char *input_path, const char *output_path)
{
    FILE *input = fopen(input_path, "r");
    if (input == NULL) {
        fprintf(stderr, "error: could not open '%s'\n", input_path);
        return false;
    }

    FILE *output = fopen(output_path, "w");
    if (output == NULL) {
        fprintf(stderr, "error: could not create '%s'\n", output_path);
        fclose(input);
        return false;
    }

    char line[MAX_LINE_LEN];
    int line_no = 0;
    int address = 0;
    while (fgets(line, sizeof(line), input) != NULL) {
        line_no++;
        strip_comment(line);
        char *clean = trim(line);
        if (*clean == '\0') {
            continue;
        }

        char *colon = strchr(clean, ':');
        if (colon != NULL) {
            clean = trim(colon + 1);
        }
        if (*clean == '\0') {
            continue;
        }

        if (!emit_instruction(output, clean, line_no)) {
            fclose(input);
            fclose(output);
            return false;
        }
        address += INSTR_WIDTH;
    }

    (void)address;
    fclose(input);
    fclose(output);
    return true;
}

static void print_usage(const char *program_name)
{
    fprintf(stderr, "usage: %s input.asm output.bin\n", program_name);
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        print_usage(argv[0]);
        return 1;
    }

    int instruction_count = 0;
    if (!first_pass(argv[1], &instruction_count)) {
        return 1;
    }
    if (!second_pass(argv[1], argv[2])) {
        return 1;
    }

    printf("Assembled %d instruction(s) into %s\n", instruction_count, argv[2]);
    return 0;
}
