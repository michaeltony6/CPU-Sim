// Top-level single-cycle CPU for the custom RISC ISA.
module cpu #(
    parameter PROGRAM_FILE = ""
)(
    input clk,
    input reset,
    output reg halted
);
    localparam INSTR_WIDTH = 8'd4;

    reg [7:0] pc;

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

    memory #(.PROGRAM_FILE(PROGRAM_FILE)) data_memory(
        .clk(clk),
        .write_enable(mem_write && !halted),
        .instr_addr(pc),
        .data_addr(instr_b[7:0]),
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

    assign alu_b = alu_src_imm ? instr_b : reg_data2;
    assign write_back_data = mem_to_reg ? mem_read_data : alu_result;
    assign take_branch = (branch_eq && (reg_data1 == reg_data2)) ||
                         (branch_ne && (reg_data1 != reg_data2));
    assign is_reg_reg_alu = (opcode == 32'd4) || (opcode == 32'd5);
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
            pc <= 8'd0;
            halted <= 1'b0;
        end else if (!halted) begin
            if (halt) begin
                halted <= 1'b1;
            end else if (jump) begin
                pc <= instr_a[7:0];
            end else if (take_branch) begin
                pc <= instr_c[7:0];
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
        end
    end
endmodule
