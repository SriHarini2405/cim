// =============================================================================
// File: forwarding_unit.sv
// Description: Data Hazard Forwarding Unit (EX-to-EX and MEM-to-EX)
// =============================================================================

import riscv_pkg::*;

module forwarding_unit (
    input  logic [4:0]  id_ex_rs1,
    input  logic [4:0]  id_ex_rs2,
    input  logic [4:0]  ex_mem_rd,
    input  logic        ex_mem_reg_write,
    input  logic [4:0]  mem_wb_rd,
    input  logic        mem_wb_reg_write,
    output fwd_sel_e    fwd_a,
    output fwd_sel_e    fwd_b
);

    always_comb begin
        // Forward A logic
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1)) begin
            fwd_a = FWD_EX;
        end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1)) begin
            fwd_a = FWD_MEM;
        end else begin
            fwd_a = FWD_NONE;
        end

        // Forward B logic
        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2)) begin
            fwd_b = FWD_EX;
        end else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2)) begin
            fwd_b = FWD_MEM;
        end else begin
            fwd_b = FWD_NONE;
        end
    end

endmodule
