; Sum integers 1 through 10 and store 55 in MEM[250].
MOVI R1, 1      ; counter
MOVI R2, 10     ; limit
MOVI R3, 0      ; running sum
MOVI R4, 1      ; increment

loop:
ADD R3, R3, R1
BEQ R1, R2, done
ADD R1, R1, R4
JMP loop

done:
STORE R3, 250
HALT
