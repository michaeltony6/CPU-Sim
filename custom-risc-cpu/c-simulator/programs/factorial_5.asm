; Compute 5! using nested repeated-add multiplication.
; Result: MEM[250] = 120
MOVI R1, 5      ; n
MOVI R2, 1      ; result
MOVI R3, 1      ; constant one

outer_loop:
BEQ R1, R3, done
MOVI R5, 0      ; product accumulator
ADD R6, R1, R0  ; inner loop counter = n

multiply_loop:
BEQ R6, R0, multiply_done
ADD R5, R5, R2
SUB R6, R6, R3
JMP multiply_loop

multiply_done:
ADD R2, R5, R0
SUB R1, R1, R3
JMP outer_loop

done:
STORE R2, 250
HALT

