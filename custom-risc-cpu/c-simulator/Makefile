CC := gcc
CFLAGS := -Wall -Wextra -std=c11 -O2

SIM_OBJS := cpu_sim.o registers.o memory.o
ASM_OBJS := assembler.o registers.o memory.o

PROG ?= programs/add_two_numbers

.PHONY: all clean run test

all: cpu_sim assembler

cpu_sim: $(SIM_OBJS)
	$(CC) $(CFLAGS) -o $@ $(SIM_OBJS)

assembler: $(ASM_OBJS)
	$(CC) $(CFLAGS) -o $@ $(ASM_OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

run: all
	./assembler $(PROG).asm $(PROG).bin
	./cpu_sim $(PROG).bin --trace

test: all
	./tests.sh

clean:
	rm -f cpu_sim assembler *.o programs/*.bin
