#ifndef INSTRUCTIONS_H
#define INSTRUCTIONS_H

#define INSTR_WIDTH 4

typedef enum {
    OP_NOP = 0,
    OP_LOAD = 1,
    OP_STORE = 2,
    OP_MOVI = 3,
    OP_ADD = 4,
    OP_SUB = 5,
    OP_JMP = 6,
    OP_BEQ = 7,
    OP_BNE = 8,
    OP_HALT = 9,
    OP_ADDI = 10,
    OP_AND = 11,
    OP_OR = 12,
    OP_XOR = 13,
    OP_SHL = 14,
    OP_SHR = 15,
    OP_LOADR = 16,
    OP_STORER = 17,
    OP_JLT = 18,
    OP_JGT = 19,
    OP_PUSH = 20,
    OP_POP = 21,
    OP_CALL = 22,
    OP_RET = 23
} Opcode;

static inline const char *opcode_name(int opcode)
{
    switch (opcode) {
    case OP_NOP: return "NOP";
    case OP_LOAD: return "LOAD";
    case OP_STORE: return "STORE";
    case OP_MOVI: return "MOVI";
    case OP_ADD: return "ADD";
    case OP_SUB: return "SUB";
    case OP_JMP: return "JMP";
    case OP_BEQ: return "BEQ";
    case OP_BNE: return "BNE";
    case OP_HALT: return "HALT";
    case OP_ADDI: return "ADDI";
    case OP_AND: return "AND";
    case OP_OR: return "OR";
    case OP_XOR: return "XOR";
    case OP_SHL: return "SHL";
    case OP_SHR: return "SHR";
    case OP_LOADR: return "LOADR";
    case OP_STORER: return "STORER";
    case OP_JLT: return "JLT";
    case OP_JGT: return "JGT";
    case OP_PUSH: return "PUSH";
    case OP_POP: return "POP";
    case OP_CALL: return "CALL";
    case OP_RET: return "RET";
    default: return "UNKNOWN";
    }
}

#endif
