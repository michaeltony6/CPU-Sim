// 256-word memory shared by program instructions and data.
// The program file is a plain text file with one decimal integer per line.
module memory #(
    parameter PROGRAM_FILE = ""
)(
    input clk,
    input write_enable,
    input [7:0] instr_addr,
    input [7:0] data_addr,
    input [31:0] write_data,
    output [31:0] instr_word0,
    output [31:0] instr_word1,
    output [31:0] instr_word2,
    output [31:0] instr_word3,
    output [31:0] read_data
);
    reg [31:0] mem [0:255];
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

    assign instr_word0 = mem[instr_addr];
    assign instr_word1 = mem[instr_addr + 8'd1];
    assign instr_word2 = mem[instr_addr + 8'd2];
    assign instr_word3 = mem[instr_addr + 8'd3];
    assign read_data = mem[data_addr];

    always @(posedge clk) begin
        if (write_enable) begin
            mem[data_addr] <= write_data;
        end
    end
endmodule
