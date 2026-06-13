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
    OP_HALT = 9
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
    default: return "UNKNOWN";
    }
}

#endif
