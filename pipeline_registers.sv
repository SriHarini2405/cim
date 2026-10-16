// =============================================================================
// File: pipeline_registers.sv
// Description: Synchronous Inter-Stage Registers for 5-Stage RV32 Pipeline
// =============================================================================

import riscv_pkg::*;

// -----------------------------------------------------------------------------
// IF / ID Pipeline Register
// -----------------------------------------------------------------------------
module if_id_reg (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         stall,
    input  logic         flush,
    input  if_id_reg_t   d,
    output if_id_reg_t   q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q.pc    <= 32'd0;
            q.instr <= 32'h00000013; // NOP (addi x0, x0, 0)
            q.valid <= 1'b0;
        end else if (flush) begin
            q.pc    <= 32'd0;
            q.instr <= 32'h00000013; // NOP
            q.valid <= 1'b0;
        end else if (!stall) begin
            q <= d;
        end
    end
endmodule

// -----------------------------------------------------------------------------
// ID / EX Pipeline Register
// -----------------------------------------------------------------------------
module id_ex_reg (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         stall,
    input  logic         flush,
    input  id_ex_reg_t   d,
    output id_ex_reg_t   q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= '0;
        end else if (flush) begin
            q <= '0;
        end else if (!stall) begin
            q <= d;
        end
    end
endmodule

// -----------------------------------------------------------------------------
// EX / MEM Pipeline Register
// -----------------------------------------------------------------------------
module ex_mem_reg (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         stall,
    input  logic         flush,
    input  ex_mem_reg_t  d,
    output ex_mem_reg_t  q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= '0;
        end else if (flush) begin
            q <= '0;
        end else if (!stall) begin
            q <= d;
        end
    end
endmodule

// -----------------------------------------------------------------------------
// MEM / WB Pipeline Register
// -----------------------------------------------------------------------------
module mem_wb_reg (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         stall,
    input  mem_wb_reg_t  d,
    output mem_wb_reg_t  q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= '0;
        end else if (!stall) begin
            q <= d;
        end
    end
endmodule
