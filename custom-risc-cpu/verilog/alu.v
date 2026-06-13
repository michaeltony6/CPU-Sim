// Simple ALU for the custom RISC CPU.
module alu(
    input  [31:0] a,
    input  [31:0] b,
    input  [2:0]  alu_op,
    output reg [31:0] result,
    output zero
);
    localparam ALU_ADD = 3'd0;
    localparam ALU_SUB = 3'd1;
    localparam ALU_PASS = 3'd2;

    always @(*) begin
        case (alu_op)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_PASS: result = b;
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule
