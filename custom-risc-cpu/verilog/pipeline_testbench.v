// Icarus Verilog:
//   iverilog -o pipeline_tb pipeline_testbench.v pipeline_cpu.v hazard_unit.v
//   vvp pipeline_tb
//   gtkwave pipeline_dump.vcd
module pipeline_testbench;
    parameter PROGRAM_FILE = "programs/add_two_numbers.mem";
    parameter EXPECTED_MEM250 = 12;
    parameter MAX_CYCLES = 500;

    reg clk;
    reg reset;
    wire halted;
    wire fault;
    wire [31:0] cycles;
    wire [31:0] retired;
    wire [31:0] stalls;
    wire [31:0] flushes;
    real cpi;

    pipeline_cpu #(.PROGRAM_FILE(PROGRAM_FILE)) dut(
        .clk(clk),
        .reset(reset),
        .halted(halted),
        .fault(fault),
        .cycles(cycles),
        .retired(retired),
        .stalls(stalls),
        .flushes(flushes)
    );

    initial begin
        $dumpfile("pipeline_dump.vcd");
        $dumpvars(0, pipeline_testbench);
        clk = 1'b0;
        reset = 1'b1;
        #12 reset = 1'b0;
    end

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset) begin
            if (halted) begin
                if (fault) begin
                    $display("error: pipeline CPU halted with a fault");
                    $finish;
                end
                cpi = retired == 0 ? 0.0 : cycles * 1.0 / retired;
                $display("PIPELINE CPU halted after %0d cycles", cycles);
                $display("PIPELINE retired=%0d stalls=%0d flushes=%0d CPI=%0.2f", retired, stalls, flushes, cpi);
                $display("PIPELINE REG 0 %0d", dut.regs[0]);
                $display("PIPELINE REG 1 %0d", dut.regs[1]);
                $display("PIPELINE REG 2 %0d", dut.regs[2]);
                $display("PIPELINE REG 3 %0d", dut.regs[3]);
                $display("PIPELINE REG 4 %0d", dut.regs[4]);
                $display("PIPELINE REG 5 %0d", dut.regs[5]);
                $display("PIPELINE REG 6 %0d", dut.regs[6]);
                $display("PIPELINE REG 7 %0d", dut.regs[7]);
                $display("PIPELINE MEM[250] = %0d", dut.mem[250]);
                if (dut.mem[250] !== EXPECTED_MEM250) begin
                    $display("error: expected MEM[250] = %0d", EXPECTED_MEM250);
                    $finish;
                end
                $finish;
            end

            if (cycles > MAX_CYCLES) begin
                $display("error: pipeline simulation cycle limit reached");
                $finish;
            end
        end
    end
endmodule

