// Top-level single-cycle CPU for the custom RISC ISA.
module cpu #(
    parameter PROGRAM_FILE = ""
)(
    input clk,
    input reset,
    output reg halted,
    output reg fault
);
    localparam INSTR_WIDTH = 8'd4;

    reg [31:0] pc;

    wire [31:0] opcode;
    wire [31:0] instr_a;
    wire [31:0] instr_b;
    wire [31:0] instr_c;
    wire [31:0] mem_read_data;
    wire [31:0] reg_data1;
    wire [31:0] reg_data2;
    wire [31:0] alu_b;
    wire [31:0] alu_result;
    wire alu_zero;
    wire reg_write;
    wire mem_write;
    wire mem_to_reg;
    wire alu_src_imm;
    wire branch_eq;
    wire branch_ne;
    wire jump;
    wire halt;
    wire [2:0] alu_op;
    wire take_branch;
    wire [31:0] write_back_data;
    wire is_reg_reg_alu;
    wire [2:0] read_reg1;
    wire [2:0] read_reg2;
    wire is_load;
    wire is_store;
    wire is_movi;
    wire is_add;
    wire is_sub;
    wire is_jump;
    wire is_branch;
    wire valid_rd;
    wire valid_rs1;
    wire valid_rs2;
    wire valid_data_addr;
    wire valid_jump_target;
    wire valid_branch_target;
    wire valid_pc;
    wire invalid_instruction;

    memory #(.PROGRAM_FILE(PROGRAM_FILE)) data_memory(
        .clk(clk),
        .write_enable(mem_write && !halted),
        .instr_addr(pc),
        .data_addr(instr_b),
        .write_data(reg_data1),
        .instr_word0(opcode),
        .instr_word1(instr_a),
        .instr_word2(instr_b),
        .instr_word3(instr_c),
        .read_data(mem_read_data)
    );

    register_file regs(
        .clk(clk),
        .reset(reset),
        .write_enable(reg_write && !halted),
        .read_reg1(read_reg1),
        .read_reg2(read_reg2),
        .write_reg(instr_a[2:0]),
        .write_data(write_back_data),
        .read_data1(reg_data1),
        .read_data2(reg_data2)
    );

    control decoder(
        .opcode(opcode),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .alu_src_imm(alu_src_imm),
        .branch_eq(branch_eq),
        .branch_ne(branch_ne),
        .jump(jump),
        .halt(halt),
        .alu_op(alu_op)
    );

    assign is_load = (opcode == 32'd1);
    assign is_store = (opcode == 32'd2);
    assign is_movi = (opcode == 32'd3);
    assign is_add = (opcode == 32'd4);
    assign is_sub = (opcode == 32'd5);
    assign is_jump = (opcode == 32'd6);
    assign is_branch = (opcode == 32'd7) || (opcode == 32'd8);
    assign is_reg_reg_alu = is_add || is_sub;
    assign valid_rd = instr_a <= 32'd7;
    assign valid_rs1 = instr_b <= 32'd7;
    assign valid_rs2 = instr_c <= 32'd7;
    assign valid_data_addr = instr_b <= 32'd255;
    assign valid_jump_target = instr_a <= 32'd252 && instr_a[1:0] == 2'b00;
    assign valid_branch_target = instr_c <= 32'd252 && instr_c[1:0] == 2'b00;
    assign valid_pc = pc <= 32'd252 && pc[1:0] == 2'b00;

    assign invalid_instruction =
        !valid_pc ||
        ((is_load || is_movi) && !valid_rd) ||
        (is_load && !valid_data_addr) ||
        (is_store && (!valid_rd || !valid_data_addr)) ||
        (is_reg_reg_alu && (!valid_rd || !valid_rs1 || !valid_rs2)) ||
        (is_jump && !valid_jump_target) ||
        (is_branch && (!valid_rd || !valid_rs1 || !valid_branch_target));

    assign alu_b = alu_src_imm ? instr_b : reg_data2;
    assign write_back_data = mem_to_reg ? mem_read_data : alu_result;
    assign take_branch = (branch_eq && (reg_data1 == reg_data2)) ||
                         (branch_ne && (reg_data1 != reg_data2));
    assign read_reg1 = is_reg_reg_alu ? instr_b[2:0] : instr_a[2:0];
    assign read_reg2 = is_reg_reg_alu ? instr_c[2:0] : instr_b[2:0];

    alu main_alu(
        .a(reg_data1),
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'd0;
            halted <= 1'b0;
            fault <= 1'b0;
        end else if (!halted) begin
            if (invalid_instruction) begin
                fault <= 1'b1;
                halted <= 1'b1;
            end else if (halt) begin
                halted <= 1'b1;
            end else if (jump) begin
                pc <= instr_a;
            end else if (take_branch) begin
                pc <= instr_c;
            end else begin
                pc <= pc + INSTR_WIDTH;
            end
        end
    end

    // Helpful simulation trace.
    always @(posedge clk) begin
        if (!reset && !halted) begin
            $display("pc=%0d opcode=%0d a=%0d b=%0d c=%0d r1=%0d r2=%0d mem250=%0d",
                     pc, opcode, instr_a, instr_b, instr_c, reg_data1, reg_data2,
                     data_memory.mem[250]);
            if (invalid_instruction) begin
                $display("fault: invalid instruction or operand at pc=%0d", pc);
            end
        end
    end
endmodule
