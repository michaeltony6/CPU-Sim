; Sum the first 10 Fibonacci terms: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34.
; The expected result is 88 in MEM[250].
MOVI R1, 0      ; current Fibonacci term
MOVI R2, 1      ; next Fibonacci term
MOVI R3, 0      ; running sum
MOVI R4, 10     ; remaining terms
MOVI R5, 0      ; zero constant
MOVI R6, 1      ; decrement value

loop:
BEQ R4, R5, done
ADD R3, R3, R1
ADD R7, R1, R2
MOVI R1, 0
ADD R1, R1, R2
MOVI R2, 0
ADD R2, R2, R7
SUB R4, R4, R6
JMP loop

done:
STORE R3, 250
HALT
