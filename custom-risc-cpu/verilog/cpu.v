// Top-level single-cycle CPU for the custom RISC ISA.
module cpu #(
    parameter PROGRAM_FILE = ""
)(
    input clk,
    input reset,
    output reg halted,
    output reg fault
);
    localparam INSTR_WIDTH = 32'd4;

    reg [31:0] pc;
    reg flag_zero;
    reg flag_negative;
    reg flag_carry;

    wire [31:0] opcode;
    wire [31:0] instr_a;
    wire [31:0] instr_b;
    wire [31:0] instr_c;
    wire [31:0] mem_read_data;
    wire [31:0] reg_data1;
    wire [31:0] reg_data2;
    wire [31:0] sp_data;
    wire [31:0] alu_b;
    wire [31:0] alu_result;
    wire alu_zero;
    wire reg_write_control;
    wire mem_write_control;
    wire mem_to_reg;
    wire alu_src_imm;
    wire branch_eq;
    wire branch_ne;
    wire branch_lt;
    wire branch_gt;
    wire jump;
    wire halt;
    wire [3:0] alu_op;

    wire is_load = (opcode == 32'd1);
    wire is_store = (opcode == 32'd2);
    wire is_movi = (opcode == 32'd3);
    wire is_add = (opcode == 32'd4);
    wire is_sub = (opcode == 32'd5);
    wire is_jmp = (opcode == 32'd6);
    wire is_beq = (opcode == 32'd7);
    wire is_bne = (opcode == 32'd8);
    wire is_addi = (opcode == 32'd10);
    wire is_and = (opcode == 32'd11);
    wire is_or = (opcode == 32'd12);
    wire is_xor = (opcode == 32'd13);
    wire is_shl = (opcode == 32'd14);
    wire is_shr = (opcode == 32'd15);
    wire is_loadr = (opcode == 32'd16);
    wire is_storer = (opcode == 32'd17);
    wire is_jlt = (opcode == 32'd18);
    wire is_jgt = (opcode == 32'd19);
    wire is_push = (opcode == 32'd20);
    wire is_pop = (opcode == 32'd21);
    wire is_call = (opcode == 32'd22);
    wire is_ret = (opcode == 32'd23);

    wire is_reg_reg_alu = is_add || is_sub || is_and || is_or || is_xor;
    wire is_imm_alu = is_addi || is_shl || is_shr;
    wire is_branch = is_beq || is_bne || is_jlt || is_jgt;
    wire updates_flags = is_load || is_loadr || is_movi || is_reg_reg_alu || is_imm_alu || is_pop;

    wire [2:0] read_reg1 =
        (is_reg_reg_alu || is_imm_alu || is_loadr) ? instr_b[2:0] :
        instr_a[2:0];
    wire [2:0] read_reg2 =
        is_reg_reg_alu ? instr_c[2:0] :
        instr_b[2:0];

    wire [31:0] data_addr =
        (is_load || is_store) ? instr_b :
        is_loadr ? reg_data1 :
        is_storer ? reg_data2 :
        (is_push || is_call) ? (sp_data - 32'd1) :
        (is_pop || is_ret) ? sp_data :
        instr_b;

    wire [31:0] mem_write_data =
        is_call ? (pc + INSTR_WIDTH) :
        reg_data1;

    wire [31:0] write_back_data = mem_to_reg ? mem_read_data : alu_result;

    wire sp_write_enable = !halted && !invalid_instruction && (is_push || is_call || is_pop || is_ret);
    wire [31:0] sp_write_data = (is_push || is_call) ? (sp_data - 32'd1) : (sp_data + 32'd1);

    wire take_branch =
        (branch_eq && (reg_data1 == reg_data2)) ||
        (branch_ne && (reg_data1 != reg_data2)) ||
        (branch_lt && ($signed(reg_data1) < $signed(reg_data2))) ||
        (branch_gt && ($signed(reg_data1) > $signed(reg_data2)));

    wire valid_rd = instr_a <= 32'd7;
    wire valid_rs1 = instr_b <= 32'd7;
    wire valid_rs2 = instr_c <= 32'd7;
    wire valid_imm_shift = instr_c <= 32'd31;
    wire valid_immediate_addr = instr_b <= 32'd255;
    wire valid_data_addr = data_addr <= 32'd255;
    wire valid_jump_target = instr_a <= 32'd252 && instr_a[1:0] == 2'b00;
    wire valid_branch_target = instr_c <= 32'd252 && instr_c[1:0] == 2'b00;
    wire valid_pc = pc <= 32'd252 && pc[1:0] == 2'b00;

    wire invalid_instruction =
        !valid_pc ||
        ((is_load || is_movi || is_pop) && !valid_rd) ||
        ((is_store || is_push) && !valid_rd) ||
        ((is_load || is_store) && !valid_immediate_addr) ||
        (is_reg_reg_alu && (!valid_rd || !valid_rs1 || !valid_rs2)) ||
        (is_imm_alu && (!valid_rd || !valid_rs1 || ((is_shl || is_shr) && !valid_imm_shift))) ||
        ((is_loadr) && (!valid_rd || !valid_rs1 || !valid_data_addr)) ||
        ((is_storer) && (!valid_rd || !valid_rs1 || !valid_data_addr)) ||
        (is_jmp && !valid_jump_target) ||
        (is_call && (!valid_jump_target || !valid_data_addr)) ||
        (is_ret && (!valid_data_addr || !(mem_read_data <= 32'd252 && mem_read_data[1:0] == 2'b00))) ||
        ((is_pop || is_push) && !valid_data_addr) ||
        (is_branch && (!valid_rd || !valid_rs1 || !valid_branch_target));

    memory #(.PROGRAM_FILE(PROGRAM_FILE)) data_memory(
        .clk(clk),
        .write_enable(mem_write_control && !halted && !invalid_instruction),
        .instr_addr(pc),
        .data_addr(data_addr),
        .write_data(mem_write_data),
        .instr_word0(opcode),
        .instr_word1(instr_a),
        .instr_word2(instr_b),
        .instr_word3(instr_c),
        .read_data(mem_read_data)
    );

    register_file regs(
        .clk(clk),
        .reset(reset),
        .write_enable(reg_write_control && !halted && !invalid_instruction),
        .read_reg1(read_reg1),
        .read_reg2(read_reg2),
        .write_reg(instr_a[2:0]),
        .write_data(write_back_data),
        .sp_write_enable(sp_write_enable),
        .sp_write_data(sp_write_data),
        .read_data1(reg_data1),
        .read_data2(reg_data2),
        .sp_data(sp_data)
    );

    control decoder(
        .opcode(opcode),
        .reg_write(reg_write_control),
        .mem_write(mem_write_control),
        .mem_to_reg(mem_to_reg),
        .alu_src_imm(alu_src_imm),
        .branch_eq(branch_eq),
        .branch_ne(branch_ne),
        .branch_lt(branch_lt),
        .branch_gt(branch_gt),
        .jump(jump),
        .halt(halt),
        .alu_op(alu_op)
    );

    assign alu_b = alu_src_imm ? instr_c : reg_data2;

    alu main_alu(
        .a(is_movi ? 32'd0 : reg_data1),
        .b(is_movi ? instr_b : alu_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'd0;
            halted <= 1'b0;
            fault <= 1'b0;
            flag_zero <= 1'b0;
            flag_negative <= 1'b0;
            flag_carry <= 1'b0;
        end else if (!halted) begin
            if (invalid_instruction) begin
                fault <= 1'b1;
                halted <= 1'b1;
            end else begin
                if (updates_flags) begin
                    flag_zero <= (write_back_data == 32'd0);
                    flag_negative <= write_back_data[31];
                    flag_carry <= 1'b0;
                end

                if (halt) begin
                    halted <= 1'b1;
                end else if (is_ret) begin
                    pc <= mem_read_data;
                end else if (jump) begin
                    pc <= instr_a;
                end else if (take_branch) begin
                    pc <= instr_c;
                end else begin
                    pc <= pc + INSTR_WIDTH;
                end
            end
        end
    end

    // Helpful simulation trace.
    always @(posedge clk) begin
        if (!reset && !halted) begin
            $display("pc=%0d opcode=%0d a=%0d b=%0d c=%0d r1=%0d r2=%0d sp=%0d mem250=%0d flags=%0d%0d%0d",
                     pc, opcode, instr_a, instr_b, instr_c, reg_data1, reg_data2, sp_data,
                     data_memory.mem[250], flag_zero, flag_negative, flag_carry);
            if ((is_store || is_storer) && data_addr == 32'd255) begin
                $display("MMIO[255] output = %0d", mem_write_data);
            end
            if (invalid_instruction) begin
                $display("fault: invalid instruction or operand at pc=%0d", pc);
            end
        end
    end
endmodule
