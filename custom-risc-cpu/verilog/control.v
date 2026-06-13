// Control unit for opcode decoding.
module control(
    input [31:0] opcode,
    output reg reg_write,
    output reg mem_write,
    output reg mem_to_reg,
    output reg alu_src_imm,
    output reg branch_eq,
    output reg branch_ne,
    output reg jump,
    output reg halt,
    output reg [2:0] alu_op
);
    localparam OP_NOP   = 32'd0;
    localparam OP_LOAD  = 32'd1;
    localparam OP_STORE = 32'd2;
    localparam OP_MOVI  = 32'd3;
    localparam OP_ADD   = 32'd4;
    localparam OP_SUB   = 32'd5;
    localparam OP_JMP   = 32'd6;
    localparam OP_BEQ   = 32'd7;
    localparam OP_BNE   = 32'd8;
    localparam OP_HALT  = 32'd9;

    localparam ALU_ADD  = 3'd0;
    localparam ALU_SUB  = 3'd1;
    localparam ALU_PASS = 3'd2;

    always @(*) begin
        reg_write = 1'b0;
        mem_write = 1'b0;
        mem_to_reg = 1'b0;
        alu_src_imm = 1'b0;
        branch_eq = 1'b0;
        branch_ne = 1'b0;
        jump = 1'b0;
        halt = 1'b0;
        alu_op = ALU_ADD;

        case (opcode)
            OP_LOAD: begin
                reg_write = 1'b1;
                mem_to_reg = 1'b1;
            end
            OP_STORE: begin
                mem_write = 1'b1;
            end
            OP_MOVI: begin
                reg_write = 1'b1;
                alu_src_imm = 1'b1;
                alu_op = ALU_PASS;
            end
            OP_ADD: begin
                reg_write = 1'b1;
                alu_op = ALU_ADD;
            end
            OP_SUB: begin
                reg_write = 1'b1;
                alu_op = ALU_SUB;
            end
            OP_JMP: begin
                jump = 1'b1;
            end
            OP_BEQ: begin
                branch_eq = 1'b1;
                alu_op = ALU_SUB;
            end
            OP_BNE: begin
                branch_ne = 1'b1;
                alu_op = ALU_SUB;
            end
            OP_HALT: begin
                halt = 1'b1;
            end
            OP_NOP: begin
            end
            default: begin
                halt = 1'b1;
            end
        endcase
    end
endmodule
