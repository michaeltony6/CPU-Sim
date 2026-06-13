#include "registers.h"

#include <stdio.h>

void registers_init(int registers[NUM_REGISTERS])
{
    for (int i = 0; i < NUM_REGISTERS; i++) {
        registers[i] = 0;
    }
}

bool register_is_valid(int reg)
{
    return reg >= 0 && reg < NUM_REGISTERS;
}

void registers_dump(const int registers[NUM_REGISTERS])
{
    puts("Registers:");
    for (int i = 0; i < NUM_REGISTERS; i++) {
        printf("  R%d = %d\n", i, registers[i]);
    }
}
