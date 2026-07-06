; Initialize a small array and scan it for the maximum value.
; Result: MEM[250] = 42
MOVI R1, 230
MOVI R5, 17
STORE R5, 230
MOVI R5, 4
STORE R5, 231
MOVI R5, 42
STORE R5, 232
MOVI R5, 23
STORE R5, 233
MOVI R5, 9
STORE R5, 234

LOAD R3, 230    ; current max
MOVI R1, 231    ; current pointer
MOVI R2, 235    ; one past the array

scan_loop:
BEQ R1, R2, done
LOADR R4, R1
JGT R4, R3, replace_max
JMP next

replace_max:
ADD R3, R4, R0

next:
ADDI R1, R1, 1
JMP scan_loop

done:
STORE R3, 250
HALT

