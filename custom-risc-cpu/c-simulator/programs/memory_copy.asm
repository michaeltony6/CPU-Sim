; Copy four words from MEM[230..233] to MEM[240..243].
; Result: MEM[250] = copied final word, 44
MOVI R4, 11
STORE R4, 230
MOVI R4, 22
STORE R4, 231
MOVI R4, 33
STORE R4, 232
MOVI R4, 44
STORE R4, 233

MOVI R1, 230    ; source pointer
MOVI R2, 240    ; destination pointer
MOVI R3, 234    ; source end

copy_loop:
BEQ R1, R3, done
LOADR R4, R1
STORER R4, R2
ADDI R1, R1, 1
ADDI R2, R2, 1
JMP copy_loop

done:
LOAD R5, 243
STORE R5, 250
HALT

