// Icarus Verilog:
//   iverilog -o cpu_tb testbench.v cpu.v alu.v register_file.v memory.v control.v
//   vvp cpu_tb
//   gtkwave dump.vcd
module testbench;
    parameter PROGRAM_FILE = "programs/add_two_numbers.mem";
    parameter EXPECTED_MEM250 = 12;

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
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

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
                    $display("error: CPU halted with a fault");
                    $finish;
                end
                $display("CPU halted after %0d cycles", cycles);
                $display("MEM[250] = %0d", dut.data_memory.mem[250]);
                if (dut.data_memory.mem[250] !== EXPECTED_MEM250) begin
                    $display("error: expected MEM[250] = %0d", EXPECTED_MEM250);
                    $finish;
                end
                $finish;
            end
            if (cycles > 100) begin
                $display("error: simulation cycle limit reached");
                $finish;
            end
        end
    end
endmodule
