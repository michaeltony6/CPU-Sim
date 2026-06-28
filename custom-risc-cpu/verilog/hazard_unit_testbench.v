`timescale 1ns/1ps

module hazard_unit_testbench;
    reg id_valid;
    reg [2:0] id_rs1;
    reg [2:0] id_rs2;
    reg id_uses_rs1;
    reg id_uses_rs2;
    reg ex_valid;
    reg [2:0] ex_rd;
    reg ex_writes_rd;
    reg ex_is_load;
    reg mem_valid;
    reg [2:0] mem_rd;
    reg mem_writes_rd;
    reg wb_valid;
    reg [2:0] wb_rd;
    reg wb_writes_rd;
    reg branch_taken;

    wire stall;
    wire flush_if_id;
    wire forward_a_from_ex;
    wire forward_a_from_mem;
    wire forward_a_from_wb;
    wire forward_b_from_ex;
    wire forward_b_from_mem;
    wire forward_b_from_wb;
    wire [2:0] reason;

    reg clk;
    reg reset;
    reg pipe_stall;
    reg pipe_flush;
    reg pipe_valid_in;
    reg [31:0] pipe_data_in;
    wire pipe_valid_out;
    wire [31:0] pipe_data_out;

    integer failures;

    hazard_unit dut(
        .id_valid(id_valid),
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .id_uses_rs1(id_uses_rs1),
        .id_uses_rs2(id_uses_rs2),
        .ex_valid(ex_valid),
        .ex_rd(ex_rd),
        .ex_writes_rd(ex_writes_rd),
        .ex_is_load(ex_is_load),
        .mem_valid(mem_valid),
        .mem_rd(mem_rd),
        .mem_writes_rd(mem_writes_rd),
        .wb_valid(wb_valid),
        .wb_rd(wb_rd),
        .wb_writes_rd(wb_writes_rd),
        .branch_taken(branch_taken),
        .stall(stall),
        .flush_if_id(flush_if_id),
        .forward_a_from_ex(forward_a_from_ex),
        .forward_a_from_mem(forward_a_from_mem),
        .forward_a_from_wb(forward_a_from_wb),
        .forward_b_from_ex(forward_b_from_ex),
        .forward_b_from_mem(forward_b_from_mem),
        .forward_b_from_wb(forward_b_from_wb),
        .reason(reason)
    );

    pipeline_register #(.WIDTH(32)) pipe_reg(
        .clk(clk),
        .reset(reset),
        .stall(pipe_stall),
        .flush(pipe_flush),
        .valid_in(pipe_valid_in),
        .data_in(pipe_data_in),
        .valid_out(pipe_valid_out),
        .data_out(pipe_data_out)
    );

    always #5 clk = ~clk;

    task clear_hazard_inputs;
        begin
            id_valid = 1'b0;
            id_rs1 = 3'd0;
            id_rs2 = 3'd0;
            id_uses_rs1 = 1'b0;
            id_uses_rs2 = 1'b0;
            ex_valid = 1'b0;
            ex_rd = 3'd0;
            ex_writes_rd = 1'b0;
            ex_is_load = 1'b0;
            mem_valid = 1'b0;
            mem_rd = 3'd0;
            mem_writes_rd = 1'b0;
            wb_valid = 1'b0;
            wb_rd = 3'd0;
            wb_writes_rd = 1'b0;
            branch_taken = 1'b0;
        end
    endtask

    task expect;
        input condition;
        input [160*8:1] message;
        begin
            if (!condition) begin
                failures = failures + 1;
                $display("FAIL: %0s", message);
            end
        end
    endtask

    initial begin
        $dumpfile("hazard_dump.vcd");
        $dumpvars(0, hazard_unit_testbench);

        failures = 0;
        clk = 1'b0;
        reset = 1'b1;
        pipe_stall = 1'b0;
        pipe_flush = 1'b0;
        pipe_valid_in = 1'b0;
        pipe_data_in = 32'd0;
        clear_hazard_inputs();

        #12;
        reset = 1'b0;

        id_valid = 1'b1;
        id_rs1 = 3'd1;
        id_rs2 = 3'd2;
        id_uses_rs1 = 1'b1;
        id_uses_rs2 = 1'b1;
        #1;
        expect(stall == 1'b0, "no dependency should not stall");
        expect(reason == 3'd0, "no dependency should report no reason");

        clear_hazard_inputs();
        id_valid = 1'b1;
        id_rs1 = 3'd4;
        id_uses_rs1 = 1'b1;
        ex_valid = 1'b1;
        ex_rd = 3'd4;
        ex_writes_rd = 1'b1;
        ex_is_load = 1'b1;
        #1;
        expect(stall == 1'b1, "load-use dependency should stall");
        expect(reason == 3'd1, "load-use dependency should report load-use reason");
        expect(forward_a_from_ex == 1'b0, "load-use dependency should not forward from EX");

        clear_hazard_inputs();
        id_valid = 1'b1;
        id_rs1 = 3'd2;
        id_rs2 = 3'd5;
        id_uses_rs1 = 1'b1;
        id_uses_rs2 = 1'b1;
        ex_valid = 1'b1;
        ex_rd = 3'd2;
        ex_writes_rd = 1'b1;
        mem_valid = 1'b1;
        mem_rd = 3'd5;
        mem_writes_rd = 1'b1;
        #1;
        expect(stall == 1'b0, "ALU forwarding should avoid a stall");
        expect(forward_a_from_ex == 1'b1, "rs1 should forward from EX");
        expect(forward_b_from_mem == 1'b1, "rs2 should forward from MEM");
        expect(reason == 3'd3, "forwarding should report forward reason");

        clear_hazard_inputs();
        id_valid = 1'b1;
        id_rs1 = 3'd3;
        id_uses_rs1 = 1'b1;
        ex_valid = 1'b1;
        ex_rd = 3'd3;
        ex_writes_rd = 1'b1;
        mem_valid = 1'b1;
        mem_rd = 3'd3;
        mem_writes_rd = 1'b1;
        wb_valid = 1'b1;
        wb_rd = 3'd3;
        wb_writes_rd = 1'b1;
        #1;
        expect(forward_a_from_ex == 1'b1, "newest EX value should win over MEM/WB");
        expect(forward_a_from_mem == 1'b0, "MEM should not override newer EX value");
        expect(forward_a_from_wb == 1'b0, "WB should not override newer EX value");

        clear_hazard_inputs();
        branch_taken = 1'b1;
        #1;
        expect(flush_if_id == 1'b1, "taken branch should flush IF/ID");
        expect(reason == 3'd2, "taken branch should report branch reason");

        pipe_valid_in = 1'b1;
        pipe_data_in = 32'h12345678;
        @(posedge clk);
        #1;
        expect(pipe_valid_out == 1'b1, "pipeline register should capture valid bit");
        expect(pipe_data_out == 32'h12345678, "pipeline register should capture data");

        pipe_stall = 1'b1;
        pipe_data_in = 32'hAAAAAAAA;
        @(posedge clk);
        #1;
        expect(pipe_data_out == 32'h12345678, "stalled pipeline register should hold data");

        pipe_stall = 1'b0;
        pipe_flush = 1'b1;
        @(posedge clk);
        #1;
        expect(pipe_valid_out == 1'b0, "flushed pipeline register should clear valid bit");
        expect(pipe_data_out == 32'd0, "flushed pipeline register should clear data");

        if (failures == 0) begin
            $display("HAZARD UNIT TESTS PASSED");
        end else begin
            $display("HAZARD UNIT TESTS FAILED: %0d failure(s)", failures);
        end
        $finish;
    end
endmodule

