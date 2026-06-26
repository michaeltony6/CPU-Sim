; ISA v2 demo:
; - immediate arithmetic
; - bitwise logic
; - shifts
; - register-indirect memory
; - signed branches
; - stack and subroutine call/return
; - memory-mapped output through MEM[255]
;
; Expected result: MEM[250] = 20.

MOVI R7, 256     ; stack pointer convention: empty stack starts one past memory
MOVI R1, 5
ADDI R2, R1, 3   ; R2 = 8
MOVI R3, 6
AND R4, R2, R3   ; R4 = 0
OR R4, R2, R3    ; R4 = 14
XOR R4, R4, R3   ; R4 = 8
SHL R5, R1, 2    ; R5 = 20
SHR R6, R5, 1    ; R6 = 10

MOVI R0, 240
STORER R6, R0    ; MEM[240] = 10
LOADR R3, R0     ; R3 = 10

PUSH R3
MOVI R3, 0
POP R4           ; R4 = 10
CALL double      ; R4 = 20

MOVI R5, 25
JLT R4, R5, less_ok
MOVI R4, 0       ; should be skipped

less_ok:
JGT R4, R3, greater_ok
MOVI R4, 0       ; should be skipped

greater_ok:
MOVI R6, 255
STORER R4, R6    ; MMIO[255] output = 20
STORE R4, 250
HALT

double:
ADD R4, R4, R4
RET
