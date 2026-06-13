#ifndef MEMORY_H
#define MEMORY_H

#include <stdbool.h>

#define MEMORY_SIZE 256

void memory_init(int memory[MEMORY_SIZE]);
bool memory_addr_is_valid(int addr);
void memory_dump_nonzero(const int memory[MEMORY_SIZE]);

#endif
