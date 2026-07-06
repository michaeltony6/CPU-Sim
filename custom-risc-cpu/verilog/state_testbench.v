// State-dumping testbench for C-vs-Verilog golden model comparisons.
module state_testbench;
    parameter PROGRAM_FILE = "programs/add_two_numbers.mem";
    parameter MAX_CYCLES = 500;

    reg clk;
    reg reset;
    wire halted;
    wire fault;
    integer cycles;

    cpu #(.PROGRAM_FILE(PROGRAM_FILE)) dut(
        .clk(clk),
        .reset(reset),
        .halted(halted),
        .fault(fault)
    );

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        cycles = 0;
        #12 reset = 1'b0;
    end

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset) begin
            cycles = cycles + 1;
            if (halted) begin
                if (fault) begin
                    $display("STATE fault 1");
                    $finish;
                end
                $display("STATE cycles %0d", cycles);
                $display("STATE REG 0 %0d", dut.regs.regs[0]);
                $display("STATE REG 1 %0d", dut.regs.regs[1]);
                $display("STATE REG 2 %0d", dut.regs.regs[2]);
                $display("STATE REG 3 %0d", dut.regs.regs[3]);
                $display("STATE REG 4 %0d", dut.regs.regs[4]);
                $display("STATE REG 5 %0d", dut.regs.regs[5]);
                $display("STATE REG 6 %0d", dut.regs.regs[6]);
                $display("STATE REG 7 %0d", dut.regs.regs[7]);
                $display("STATE MEM 250 %0d", dut.data_memory.mem[250]);
                $finish;
            end
            if (cycles > MAX_CYCLES) begin
                $display("STATE timeout");
                $finish;
            end
        end
    end
endmodule

