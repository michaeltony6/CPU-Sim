// Reusable valid/data pipeline register with stall and flush controls.
//
// A stall holds the current stage steady. A flush clears the valid bit and data,
// which is how a branch or jump removes younger wrong-path instructions.
module pipeline_register #(
    parameter WIDTH = 32
)(
    input clk,
    input reset,
    input stall,
    input flush,
    input valid_in,
    input [WIDTH-1:0] data_in,
    output reg valid_out,
    output reg [WIDTH-1:0] data_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_out <= 1'b0;
            data_out <= {WIDTH{1'b0}};
        end else if (flush) begin
            valid_out <= 1'b0;
            data_out <= {WIDTH{1'b0}};
        end else if (!stall) begin
            valid_out <= valid_in;
            data_out <= data_in;
        end
    end
endmodule

