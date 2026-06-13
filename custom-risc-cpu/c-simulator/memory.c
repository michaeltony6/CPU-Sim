#include "memory.h"

#include <stdio.h>

void memory_init(int memory[MEMORY_SIZE])
{
    for (int i = 0; i < MEMORY_SIZE; i++) {
        memory[i] = 0;
    }
}

bool memory_addr_is_valid(int addr)
{
    return addr >= 0 && addr < MEMORY_SIZE;
}

void memory_dump_nonzero(const int memory[MEMORY_SIZE])
{
    puts("Non-zero memory:");
    bool found = false;
    for (int i = 0; i < MEMORY_SIZE; i++) {
        if (memory[i] != 0) {
            printf("  MEM[%d] = %d\n", i, memory[i]);
            found = true;
        }
    }
    if (!found) {
        puts("  (all zero)");
    }
}
