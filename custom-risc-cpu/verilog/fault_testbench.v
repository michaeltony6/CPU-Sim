module fault_testbench;
    reg clk;
    reg reset;
    wire halted;
    wire fault;
    integer cycles;

    cpu #(.PROGRAM_FILE("programs/invalid_register.mem")) dut(
        .clk(clk),
        .reset(reset),
        .halted(halted),
        .fault(fault)
    );

    initial begin
        $dumpfile("fault_dump.vcd");
        $dumpvars(0, fault_testbench);

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
                if (!fault) begin
                    $display("error: expected CPU fault");
                    $finish;
                end
                $display("CPU faulted as expected after %0d cycles", cycles);
                $finish;
            end
            if (cycles > 20) begin
                $display("error: fault test cycle limit reached");
                $finish;
            end
        end
    end
endmodule
