// Eight 32-bit general-purpose registers: R0 through R7.
module register_file(
    input clk,
    input reset,
    input write_enable,
    input [2:0] read_reg1,
    input [2:0] read_reg2,
    input [2:0] write_reg,
    input [31:0] write_data,
    input sp_write_enable,
    input [31:0] sp_write_data,
    output [31:0] read_data1,
    output [31:0] read_data2,
    output [31:0] sp_data
);
    reg [31:0] regs [0:7];
    integer i;

    assign read_data1 = regs[read_reg1];
    assign read_data2 = regs[read_reg2];
    assign sp_data = regs[3'd7];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 8; i = i + 1) begin
                regs[i] <= 32'd0;
            end
            regs[7] <= 32'd256;
        end else if (write_enable) begin
            regs[write_reg] <= write_data;
            if (sp_write_enable) begin
                regs[7] <= sp_write_data;
            end
        end else if (sp_write_enable) begin
            regs[7] <= sp_write_data;
        end
    end
endmodule
