// Hazard and forwarding unit for a five-stage version of the custom RISC CPU.
//
// The current top-level CPU is single-cycle, but the web visualizer models an
// IF/ID/EX/MEM/WB pipeline. This module captures the hardware policy that a
// pipelined implementation would need: stall on load-use hazards, forward ALU
// results when possible, and flush younger instructions after a taken branch.
module hazard_unit(
    input id_valid,
    input [2:0] id_rs1,
    input [2:0] id_rs2,
    input id_uses_rs1,
    input id_uses_rs2,

    input ex_valid,
    input [2:0] ex_rd,
    input ex_writes_rd,
    input ex_is_load,

    input mem_valid,
    input [2:0] mem_rd,
    input mem_writes_rd,

    input wb_valid,
    input [2:0] wb_rd,
    input wb_writes_rd,

    input branch_taken,

    output reg stall,
    output reg flush_if_id,
    output reg forward_a_from_ex,
    output reg forward_a_from_mem,
    output reg forward_a_from_wb,
    output reg forward_b_from_ex,
    output reg forward_b_from_mem,
    output reg forward_b_from_wb,
    output reg [2:0] reason
);
    localparam REASON_NONE      = 3'd0;
    localparam REASON_LOAD_USE  = 3'd1;
    localparam REASON_BRANCH    = 3'd2;
    localparam REASON_FORWARD   = 3'd3;

    wire ex_matches_rs1 = id_valid && id_uses_rs1 && ex_valid && ex_writes_rd && (ex_rd == id_rs1);
    wire ex_matches_rs2 = id_valid && id_uses_rs2 && ex_valid && ex_writes_rd && (ex_rd == id_rs2);
    wire mem_matches_rs1 = id_valid && id_uses_rs1 && mem_valid && mem_writes_rd && (mem_rd == id_rs1);
    wire mem_matches_rs2 = id_valid && id_uses_rs2 && mem_valid && mem_writes_rd && (mem_rd == id_rs2);
    wire wb_matches_rs1 = id_valid && id_uses_rs1 && wb_valid && wb_writes_rd && (wb_rd == id_rs1);
    wire wb_matches_rs2 = id_valid && id_uses_rs2 && wb_valid && wb_writes_rd && (wb_rd == id_rs2);

    wire load_use_hazard = (ex_matches_rs1 || ex_matches_rs2) && ex_is_load;
    wire forward_rs1_available = (ex_matches_rs1 && !ex_is_load) || mem_matches_rs1 || wb_matches_rs1;
    wire forward_rs2_available = (ex_matches_rs2 && !ex_is_load) || mem_matches_rs2 || wb_matches_rs2;
    wire has_forward = forward_rs1_available || forward_rs2_available;

    always @(*) begin
        stall = load_use_hazard;
        flush_if_id = branch_taken;

        forward_a_from_ex = ex_matches_rs1 && !ex_is_load;
        forward_b_from_ex = ex_matches_rs2 && !ex_is_load;

        // Prefer the newest producer. If EX can forward, MEM/WB do not win.
        forward_a_from_mem = !forward_a_from_ex && mem_matches_rs1;
        forward_b_from_mem = !forward_b_from_ex && mem_matches_rs2;
        forward_a_from_wb = !forward_a_from_ex && !forward_a_from_mem && wb_matches_rs1;
        forward_b_from_wb = !forward_b_from_ex && !forward_b_from_mem && wb_matches_rs2;

        if (load_use_hazard) begin
            reason = REASON_LOAD_USE;
        end else if (branch_taken) begin
            reason = REASON_BRANCH;
        end else if (has_forward) begin
            reason = REASON_FORWARD;
        end else begin
            reason = REASON_NONE;
        end
    end
endmodule
