// Five-stage pipelined CPU for the custom RISC ISA.
//
// This core is intentionally separate from cpu.v so the project has both a
// simple single-cycle reference implementation and a real pipelined datapath.
// Supported in this pipeline: NOP, LOAD, STORE, MOVI, ADD, SUB, JMP, BEQ, BNE,
// HALT, ADDI, AND, OR, XOR, SHL, SHR, LOADR, STORER, JLT, and JGT.
module pipeline_cpu #(
    parameter PROGRAM_FILE = ""
)(
    input clk,
    input reset,
    output reg halted,
    output reg fault,
    output reg [31:0] cycles,
    output reg [31:0] retired,
    output reg [31:0] stalls,
    output reg [31:0] flushes
);
    localparam INSTR_WIDTH = 32'd4;

    localparam OP_NOP    = 32'd0;
    localparam OP_LOAD   = 32'd1;
    localparam OP_STORE  = 32'd2;
    localparam OP_MOVI   = 32'd3;
    localparam OP_ADD    = 32'd4;
    localparam OP_SUB    = 32'd5;
    localparam OP_JMP    = 32'd6;
    localparam OP_BEQ    = 32'd7;
    localparam OP_BNE    = 32'd8;
    localparam OP_HALT   = 32'd9;
    localparam OP_ADDI   = 32'd10;
    localparam OP_AND    = 32'd11;
    localparam OP_OR     = 32'd12;
    localparam OP_XOR    = 32'd13;
    localparam OP_SHL    = 32'd14;
    localparam OP_SHR    = 32'd15;
    localparam OP_LOADR  = 32'd16;
    localparam OP_STORER = 32'd17;
    localparam OP_JLT    = 32'd18;
    localparam OP_JGT    = 32'd19;

    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_PASS = 4'd2;
    localparam ALU_AND  = 4'd3;
    localparam ALU_OR   = 4'd4;
    localparam ALU_XOR  = 4'd5;
    localparam ALU_SHL  = 4'd6;
    localparam ALU_SHR  = 4'd7;

    reg [31:0] mem [0:255];
    reg [31:0] regs [0:7];
    reg [31:0] pc;
    reg halt_seen;

    reg if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_opcode;
    reg [31:0] if_id_a;
    reg [31:0] if_id_b;
    reg [31:0] if_id_c;

    reg id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_opcode;
    reg [31:0] id_ex_a;
    reg [31:0] id_ex_b;
    reg [31:0] id_ex_c;
    reg [2:0] id_ex_rs1;
    reg [2:0] id_ex_rs2;
    reg [2:0] id_ex_rd;
    reg id_ex_uses_rs1;
    reg id_ex_uses_rs2;
    reg id_ex_reg_write;
    reg id_ex_mem_write;
    reg id_ex_mem_read;
    reg id_ex_mem_to_reg;
    reg id_ex_alu_src_imm;
    reg id_ex_branch_eq;
    reg id_ex_branch_ne;
    reg id_ex_branch_lt;
    reg id_ex_branch_gt;
    reg id_ex_jump;
    reg id_ex_halt;
    reg [3:0] id_ex_alu_op;
    reg [31:0] id_ex_value1;
    reg [31:0] id_ex_value2;

    reg ex_mem_valid;
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_opcode;
    reg [2:0] ex_mem_rd;
    reg ex_mem_reg_write;
    reg ex_mem_mem_write;
    reg ex_mem_mem_read;
    reg ex_mem_mem_to_reg;
    reg ex_mem_halt;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_data_addr;
    reg [31:0] ex_mem_store_data;

    reg mem_wb_valid;
    reg [31:0] mem_wb_opcode;
    reg [2:0] mem_wb_rd;
    reg mem_wb_reg_write;
    reg mem_wb_mem_to_reg;
    reg mem_wb_halt;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [31:0] mem_wb_write_data;

    integer i;
    integer file;
    integer code;
    integer value;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            mem[i] = 32'd0;
        end
        if (PROGRAM_FILE != "") begin
            file = $fopen(PROGRAM_FILE, "r");
            if (file == 0) begin
                $display("error: could not open program file %s", PROGRAM_FILE);
                $finish;
            end
            i = 0;
            while (!$feof(file) && i < 256) begin
                code = $fscanf(file, "%d\n", value);
                if (code == 1) begin
                    mem[i] = value;
                    i = i + 1;
                end
            end
            $fclose(file);
        end
    end

    wire [31:0] fetch_opcode = (pc <= 32'd252) ? mem[pc] : OP_HALT;
    wire [31:0] fetch_a = (pc <= 32'd252) ? mem[pc + 32'd1] : 32'd0;
    wire [31:0] fetch_b = (pc <= 32'd252) ? mem[pc + 32'd2] : 32'd0;
    wire [31:0] fetch_c = (pc <= 32'd252) ? mem[pc + 32'd3] : 32'd0;

    wire id_is_load = if_id_opcode == OP_LOAD;
    wire id_is_store = if_id_opcode == OP_STORE;
    wire id_is_movi = if_id_opcode == OP_MOVI;
    wire id_is_add = if_id_opcode == OP_ADD;
    wire id_is_sub = if_id_opcode == OP_SUB;
    wire id_is_jmp = if_id_opcode == OP_JMP;
    wire id_is_beq = if_id_opcode == OP_BEQ;
    wire id_is_bne = if_id_opcode == OP_BNE;
    wire id_is_halt = if_id_opcode == OP_HALT;
    wire id_is_addi = if_id_opcode == OP_ADDI;
    wire id_is_and = if_id_opcode == OP_AND;
    wire id_is_or = if_id_opcode == OP_OR;
    wire id_is_xor = if_id_opcode == OP_XOR;
    wire id_is_shl = if_id_opcode == OP_SHL;
    wire id_is_shr = if_id_opcode == OP_SHR;
    wire id_is_loadr = if_id_opcode == OP_LOADR;
    wire id_is_storer = if_id_opcode == OP_STORER;
    wire id_is_jlt = if_id_opcode == OP_JLT;
    wire id_is_jgt = if_id_opcode == OP_JGT;
    wire id_is_reg_reg = id_is_add || id_is_sub || id_is_and || id_is_or || id_is_xor;
    wire id_is_imm_alu = id_is_addi || id_is_shl || id_is_shr;
    wire id_is_branch = id_is_beq || id_is_bne || id_is_jlt || id_is_jgt;
    wire id_opcode_known =
        (if_id_opcode == OP_NOP) || id_is_load || id_is_store || id_is_movi ||
        id_is_reg_reg || id_is_jmp || id_is_branch || id_is_halt ||
        id_is_imm_alu || id_is_loadr || id_is_storer;

    wire [2:0] id_rs1 =
        (id_is_reg_reg || id_is_imm_alu || id_is_loadr) ? if_id_b[2:0] :
        (id_is_store || id_is_storer || id_is_branch) ? if_id_a[2:0] :
        3'd0;
    wire [2:0] id_rs2 =
        id_is_reg_reg ? if_id_c[2:0] :
        (id_is_storer || id_is_branch) ? if_id_b[2:0] :
        3'd0;
    wire [2:0] id_rd = if_id_a[2:0];
    wire id_uses_rs1 = id_is_reg_reg || id_is_imm_alu || id_is_loadr || id_is_store || id_is_storer || id_is_branch;
    wire id_uses_rs2 = id_is_reg_reg || id_is_storer || id_is_branch;
    wire id_reg_write = id_is_load || id_is_movi || id_is_reg_reg || id_is_imm_alu || id_is_loadr;
    wire id_mem_write = id_is_store || id_is_storer;
    wire id_mem_read = id_is_load || id_is_loadr;
    wire id_mem_to_reg = id_is_load || id_is_loadr;
    wire id_alu_src_imm = id_is_movi || id_is_imm_alu;
    wire [3:0] id_alu_op =
        id_is_sub ? ALU_SUB :
        id_is_movi ? ALU_PASS :
        id_is_and ? ALU_AND :
        id_is_or ? ALU_OR :
        id_is_xor ? ALU_XOR :
        id_is_shl ? ALU_SHL :
        id_is_shr ? ALU_SHR :
        ALU_ADD;

    wire id_valid_rd = if_id_a <= 32'd7;
    wire id_valid_rs1 = if_id_b <= 32'd7;
    wire id_valid_rs2 = if_id_c <= 32'd7;
    wire id_valid_store_rs = if_id_a <= 32'd7;
    wire id_valid_storer_addr = if_id_b <= 32'd7;
    wire id_valid_immediate_addr = if_id_b <= 32'd255;
    wire id_valid_shift = if_id_c <= 32'd31;
    wire id_valid_jump_target = if_id_a <= 32'd252 && if_id_a[1:0] == 2'b00;
    wire id_valid_branch_target = if_id_c <= 32'd252 && if_id_c[1:0] == 2'b00;
    wire id_decode_valid =
        !if_id_valid ||
        (id_opcode_known &&
         (!(id_is_load || id_is_movi || id_is_reg_reg || id_is_imm_alu || id_is_loadr) || id_valid_rd) &&
         (!id_is_store || (id_valid_store_rs && id_valid_immediate_addr)) &&
         (!id_is_reg_reg || (id_valid_rs1 && id_valid_rs2)) &&
         (!id_is_imm_alu || (id_valid_rs1 && (!id_is_shl && !id_is_shr || id_valid_shift))) &&
         (!id_is_load || id_valid_immediate_addr) &&
         (!id_is_loadr || id_valid_rs1) &&
         (!id_is_storer || (id_valid_store_rs && id_valid_storer_addr)) &&
         (!id_is_jmp || id_valid_jump_target) &&
         (!id_is_branch || (if_id_a <= 32'd7 && if_id_b <= 32'd7 && id_valid_branch_target)));

    wire [31:0] ex_mem_forward_value = ex_mem_alu_result;
    wire [31:0] mem_wb_forward_value = mem_wb_write_data;
    wire [31:0] ex_value1_forwarded =
        (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_to_reg && ex_mem_rd == id_ex_rs1) ? ex_mem_forward_value :
        (mem_wb_valid && mem_wb_reg_write && mem_wb_rd == id_ex_rs1) ? mem_wb_forward_value :
        id_ex_value1;
    wire [31:0] ex_value2_forwarded =
        (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_to_reg && ex_mem_rd == id_ex_rs2) ? ex_mem_forward_value :
        (mem_wb_valid && mem_wb_reg_write && mem_wb_rd == id_ex_rs2) ? mem_wb_forward_value :
        id_ex_value2;

    wire [31:0] ex_alu_b = id_ex_alu_src_imm ? (id_ex_opcode == OP_MOVI ? id_ex_b : id_ex_c) : ex_value2_forwarded;
    reg [31:0] ex_alu_result;
    always @(*) begin
        case (id_ex_alu_op)
            ALU_ADD: ex_alu_result = ex_value1_forwarded + ex_alu_b;
            ALU_SUB: ex_alu_result = ex_value1_forwarded - ex_alu_b;
            ALU_PASS: ex_alu_result = ex_alu_b;
            ALU_AND: ex_alu_result = ex_value1_forwarded & ex_alu_b;
            ALU_OR: ex_alu_result = ex_value1_forwarded | ex_alu_b;
            ALU_XOR: ex_alu_result = ex_value1_forwarded ^ ex_alu_b;
            ALU_SHL: ex_alu_result = ex_value1_forwarded << ex_alu_b[4:0];
            ALU_SHR: ex_alu_result = ex_value1_forwarded >> ex_alu_b[4:0];
            default: ex_alu_result = 32'd0;
        endcase
    end

    wire ex_is_branch = id_ex_branch_eq || id_ex_branch_ne || id_ex_branch_lt || id_ex_branch_gt;
    wire ex_branch_taken =
        id_ex_valid &&
        ((id_ex_branch_eq && (ex_value1_forwarded == ex_value2_forwarded)) ||
         (id_ex_branch_ne && (ex_value1_forwarded != ex_value2_forwarded)) ||
         (id_ex_branch_lt && ($signed(ex_value1_forwarded) < $signed(ex_value2_forwarded))) ||
         (id_ex_branch_gt && ($signed(ex_value1_forwarded) > $signed(ex_value2_forwarded))));
    wire ex_jump_taken = id_ex_valid && id_ex_jump;
    wire ex_control_flush = ex_branch_taken || ex_jump_taken || (id_ex_valid && id_ex_halt);
    wire [31:0] ex_control_target = ex_jump_taken ? id_ex_a : id_ex_c;
    wire [31:0] ex_data_addr =
        (id_ex_opcode == OP_LOAD || id_ex_opcode == OP_STORE) ? id_ex_b :
        (id_ex_opcode == OP_LOADR) ? ex_value1_forwarded :
        (id_ex_opcode == OP_STORER) ? ex_value2_forwarded :
        32'd0;

    wire raw_stall;
    wire unused_flush;
    wire unused_fwd_a_ex;
    wire unused_fwd_a_mem;
    wire unused_fwd_a_wb;
    wire unused_fwd_b_ex;
    wire unused_fwd_b_mem;
    wire unused_fwd_b_wb;
    wire [2:0] unused_reason;

    hazard_unit hazards(
        .id_valid(if_id_valid),
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .id_uses_rs1(id_uses_rs1),
        .id_uses_rs2(id_uses_rs2),
        .ex_valid(id_ex_valid),
        .ex_rd(id_ex_rd),
        .ex_writes_rd(id_ex_reg_write),
        .ex_is_load(id_ex_mem_read),
        .mem_valid(ex_mem_valid),
        .mem_rd(ex_mem_rd),
        .mem_writes_rd(ex_mem_reg_write),
        .wb_valid(mem_wb_valid),
        .wb_rd(mem_wb_rd),
        .wb_writes_rd(mem_wb_reg_write),
        .branch_taken(ex_control_flush),
        .stall(raw_stall),
        .flush_if_id(unused_flush),
        .forward_a_from_ex(unused_fwd_a_ex),
        .forward_a_from_mem(unused_fwd_a_mem),
        .forward_a_from_wb(unused_fwd_a_wb),
        .forward_b_from_ex(unused_fwd_b_ex),
        .forward_b_from_mem(unused_fwd_b_mem),
        .forward_b_from_wb(unused_fwd_b_wb),
        .reason(unused_reason)
    );

    wire stall_pipeline = raw_stall && !ex_control_flush && !halt_seen && !halted;
    wire [31:0] mem_stage_read_data = (ex_mem_data_addr <= 32'd255) ? mem[ex_mem_data_addr] : 32'd0;
    wire [31:0] mem_stage_write_data = ex_mem_mem_to_reg ? mem_stage_read_data : ex_mem_alu_result;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'd0;
            halted <= 1'b0;
            fault <= 1'b0;
            cycles <= 32'd0;
            retired <= 32'd0;
            stalls <= 32'd0;
            flushes <= 32'd0;
            halt_seen <= 1'b0;
            if_id_valid <= 1'b0;
            id_ex_valid <= 1'b0;
            ex_mem_valid <= 1'b0;
            mem_wb_valid <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                regs[i] <= 32'd0;
            end
            regs[7] <= 32'd256;
        end else if (!halted) begin
            cycles <= cycles + 32'd1;

            if (mem_wb_valid) begin
                retired <= retired + 32'd1;
            end

            if (mem_wb_valid && mem_wb_reg_write) begin
                regs[mem_wb_rd] <= mem_wb_write_data;
            end

            if (ex_mem_valid && ex_mem_mem_write) begin
                if (ex_mem_data_addr <= 32'd255) begin
                    mem[ex_mem_data_addr] <= ex_mem_store_data;
                    if (ex_mem_data_addr == 32'd255) begin
                        $display("PIPELINE MMIO[255] output = %0d", ex_mem_store_data);
                    end
                end else begin
                    fault <= 1'b1;
                    halt_seen <= 1'b1;
                end
            end

            if (if_id_valid && !id_decode_valid) begin
                $display("pipeline fault: unsupported or invalid instruction at PC %0d opcode=%0d", if_id_pc, if_id_opcode);
                fault <= 1'b1;
                halt_seen <= 1'b1;
                if_id_valid <= 1'b0;
                id_ex_valid <= 1'b0;
            end

            mem_wb_valid <= ex_mem_valid;
            mem_wb_opcode <= ex_mem_opcode;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            mem_wb_halt <= ex_mem_halt;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= mem_stage_read_data;
            mem_wb_write_data <= mem_stage_write_data;

            ex_mem_valid <= id_ex_valid;
            ex_mem_pc <= id_ex_pc;
            ex_mem_opcode <= id_ex_opcode;
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
            ex_mem_halt <= id_ex_halt;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_data_addr <= ex_data_addr;
            ex_mem_store_data <= ex_value1_forwarded;

            if (ex_control_flush) begin
                flushes <= flushes + 32'd1;
                if (id_ex_halt) begin
                    halt_seen <= 1'b1;
                end else begin
                    pc <= ex_control_target;
                end
                if_id_valid <= 1'b0;
                id_ex_valid <= 1'b0;
            end else if (stall_pipeline) begin
                stalls <= stalls + 32'd1;
                id_ex_valid <= 1'b0;
            end else begin
                if (!halt_seen) begin
                    pc <= pc + INSTR_WIDTH;
                    if_id_valid <= (pc <= 32'd252);
                    if_id_pc <= pc;
                    if_id_opcode <= fetch_opcode;
                    if_id_a <= fetch_a;
                    if_id_b <= fetch_b;
                    if_id_c <= fetch_c;
                end else begin
                    if_id_valid <= 1'b0;
                end

                if (!halt_seen && if_id_valid && id_decode_valid) begin
                    id_ex_valid <= if_id_valid;
                    id_ex_pc <= if_id_pc;
                    id_ex_opcode <= if_id_opcode;
                    id_ex_a <= if_id_a;
                    id_ex_b <= if_id_b;
                    id_ex_c <= if_id_c;
                    id_ex_rs1 <= id_rs1;
                    id_ex_rs2 <= id_rs2;
                    id_ex_rd <= id_rd;
                    id_ex_uses_rs1 <= id_uses_rs1;
                    id_ex_uses_rs2 <= id_uses_rs2;
                    id_ex_reg_write <= id_reg_write;
                    id_ex_mem_write <= id_mem_write;
                    id_ex_mem_read <= id_mem_read;
                    id_ex_mem_to_reg <= id_mem_to_reg;
                    id_ex_alu_src_imm <= id_alu_src_imm;
                    id_ex_branch_eq <= id_is_beq;
                    id_ex_branch_ne <= id_is_bne;
                    id_ex_branch_lt <= id_is_jlt;
                    id_ex_branch_gt <= id_is_jgt;
                    id_ex_jump <= id_is_jmp;
                    id_ex_halt <= id_is_halt;
                    id_ex_alu_op <= id_alu_op;
                    id_ex_value1 <= (mem_wb_valid && mem_wb_reg_write && mem_wb_rd == id_rs1) ?
                        mem_wb_write_data : regs[id_rs1];
                    id_ex_value2 <= (mem_wb_valid && mem_wb_reg_write && mem_wb_rd == id_rs2) ?
                        mem_wb_write_data : regs[id_rs2];
                end else begin
                    id_ex_valid <= 1'b0;
                end
            end

            if (halt_seen && !if_id_valid && !id_ex_valid && !ex_mem_valid && !mem_wb_valid) begin
                halted <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if (!reset && !halted) begin
            $display("pipeline cycle=%0d pc=%0d IFID=%0d IDEX=%0d EXMEM=%0d MEMWB=%0d mem250=%0d",
                     cycles, pc, if_id_valid, id_ex_valid, ex_mem_valid, mem_wb_valid, mem[250]);
        end
    end
endmodule
