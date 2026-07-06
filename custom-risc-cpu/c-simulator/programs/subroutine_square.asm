; Compute 9 * 9 in a subroutine and return through the stack.
; Result: MEM[250] = 81
MOVI R1, 9
CALL square
STORE R2, 250
HALT

square:
MOVI R2, 0      ; result
ADD R3, R1, R0  ; counter
MOVI R4, 1

square_loop:
BEQ R3, R0, square_done
ADD R2, R2, R1
SUB R3, R3, R4
JMP square_loop

square_done:
RET

