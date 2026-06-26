// Control unit for opcode decoding.
module control(
    input [31:0] opcode,
    output reg reg_write,
    output reg mem_write,
    output reg mem_to_reg,
    output reg alu_src_imm,
    output reg branch_eq,
    output reg branch_ne,
    output reg branch_lt,
    output reg branch_gt,
    output reg jump,
    output reg halt,
    output reg [3:0] alu_op
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
    localparam OP_ADDI  = 32'd10;
    localparam OP_AND   = 32'd11;
    localparam OP_OR    = 32'd12;
    localparam OP_XOR   = 32'd13;
    localparam OP_SHL   = 32'd14;
    localparam OP_SHR   = 32'd15;
    localparam OP_LOADR = 32'd16;
    localparam OP_STORER = 32'd17;
    localparam OP_JLT   = 32'd18;
    localparam OP_JGT   = 32'd19;
    localparam OP_PUSH  = 32'd20;
    localparam OP_POP   = 32'd21;
    localparam OP_CALL  = 32'd22;
    localparam OP_RET   = 32'd23;

    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_PASS = 4'd2;
    localparam ALU_AND  = 4'd3;
    localparam ALU_OR   = 4'd4;
    localparam ALU_XOR  = 4'd5;
    localparam ALU_SHL  = 4'd6;
    localparam ALU_SHR  = 4'd7;

    always @(*) begin
        reg_write = 1'b0;
        mem_write = 1'b0;
        mem_to_reg = 1'b0;
        alu_src_imm = 1'b0;
        branch_eq = 1'b0;
        branch_ne = 1'b0;
        branch_lt = 1'b0;
        branch_gt = 1'b0;
        jump = 1'b0;
        halt = 1'b0;
        alu_op = ALU_ADD;

        case (opcode)
            OP_LOAD: begin
                reg_write = 1'b1;
                mem_to_reg = 1'b1;
            end
            OP_LOADR: begin
                reg_write = 1'b1;
                mem_to_reg = 1'b1;
            end
            OP_STORE: begin
                mem_write = 1'b1;
            end
            OP_STORER: begin
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
            OP_ADDI: begin
                reg_write = 1'b1;
                alu_src_imm = 1'b1;
                alu_op = ALU_ADD;
            end
            OP_SUB: begin
                reg_write = 1'b1;
                alu_op = ALU_SUB;
            end
            OP_AND: begin
                reg_write = 1'b1;
                alu_op = ALU_AND;
            end
            OP_OR: begin
                reg_write = 1'b1;
                alu_op = ALU_OR;
            end
            OP_XOR: begin
                reg_write = 1'b1;
                alu_op = ALU_XOR;
            end
            OP_SHL: begin
                reg_write = 1'b1;
                alu_src_imm = 1'b1;
                alu_op = ALU_SHL;
            end
            OP_SHR: begin
                reg_write = 1'b1;
                alu_src_imm = 1'b1;
                alu_op = ALU_SHR;
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
            OP_JLT: begin
                branch_lt = 1'b1;
                alu_op = ALU_SUB;
            end
            OP_JGT: begin
                branch_gt = 1'b1;
                alu_op = ALU_SUB;
            end
            OP_PUSH: begin
                mem_write = 1'b1;
            end
            OP_POP: begin
                reg_write = 1'b1;
                mem_to_reg = 1'b1;
            end
            OP_CALL: begin
                jump = 1'b1;
                mem_write = 1'b1;
            end
            OP_RET: begin
                jump = 1'b1;
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
