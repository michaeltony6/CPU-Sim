#ifndef REGISTERS_H
#define REGISTERS_H

#include <stdbool.h>

#define NUM_REGISTERS 8

void registers_init(int registers[NUM_REGISTERS]);
bool register_is_valid(int reg);
void registers_dump(const int registers[NUM_REGISTERS]);

#endif
