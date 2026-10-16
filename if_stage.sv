// =============================================================================
// File: if_stage.sv
// Description: Instruction Fetch (IF) Stage & PC Management Logic
// =============================================================================

import riscv_pkg::*;

module if_stage (
    input  logic        clk,
    input  logic        rst_n,

    // Pipeline Control
    input  logic        pc_stall,
    input  logic        branch_redirect,
    input  logic [31:0] branch_target,

    // Memory Interface
    output logic [31:0] instr_addr,
    input  logic [31:0] instr_rdata,

    // Output to IF/ID Pipeline Register
    output if_id_reg_t  if_id_d,
    output logic [31:0] pc_current
);

    logic [31:0] pc_reg;
    logic [31:0] pc_next;

    // Next PC Selection Logic
    always_comb begin
        if (branch_redirect) begin
            pc_next = branch_target;
        end else if (!pc_stall) begin
            pc_next = pc_reg + 32'd4;
        end else begin
            pc_next = pc_reg;
        end
    end

    // PC Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'd0;
        end else begin
            pc_reg <= pc_next;
        end
    end

    // Assign Outputs
    assign pc_current    = pc_reg;
    assign instr_addr    = pc_reg;
    assign if_id_d.pc    = pc_reg;
    assign if_id_d.instr = instr_rdata;
    assign if_id_d.valid = rst_n && !branch_redirect;

endmodule
