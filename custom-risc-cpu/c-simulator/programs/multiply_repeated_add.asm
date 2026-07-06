; Compute 6 * 7 with repeated addition.
; Result: MEM[250] = 42
MOVI R1, 6      ; multiplicand
MOVI R2, 7      ; loop counter
MOVI R3, 0      ; accumulated product
MOVI R4, 1

loop:
BEQ R2, R0, done
ADD R3, R3, R1
SUB R2, R2, R4
JMP loop

done:
STORE R3, 250
HALT

