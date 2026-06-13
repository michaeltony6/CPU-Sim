// Icarus Verilog:
//   iverilog -o cpu_tb testbench.v cpu.v alu.v register_file.v memory.v control.v
//   vvp cpu_tb
//   gtkwave dump.vcd
module testbench;
    reg clk;
    reg reset;
    wire halted;
    integer cycles;

    cpu #(.PROGRAM_FILE("programs/add_two_numbers.mem")) dut(
        .clk(clk),
        .reset(reset),
        .halted(halted)
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
                $display("CPU halted after %0d cycles", cycles);
                $display("MEM[250] = %0d", dut.data_memory.mem[250]);
                $finish;
            end
            if (cycles > 100) begin
                $display("error: simulation cycle limit reached");
                $finish;
            end
        end
    end
endmodule
