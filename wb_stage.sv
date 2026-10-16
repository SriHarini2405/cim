// =============================================================================
// File: wb_stage.sv
// Description: Writeback (WB) Stage Multiplexer & Register Commit Logic
// =============================================================================

import riscv_pkg::*;

module wb_stage (
    // From MEM/WB Register
    input  mem_wb_reg_t mem_wb_q,

    // Feedback to Register File and Forwarding Unit
    output logic [31:0] wb_final_data,
    output logic        wb_reg_write,
    output logic [4:0]  wb_rd_addr
);

    // Writeback Source Multiplexer
    always_comb begin
        case (mem_wb_q.wb_sel)
            WB_MEM:  wb_final_data = mem_wb_q.mem_rdata;
            WB_MD:   wb_final_data = mem_wb_q.md_result;
            WB_PC4:  wb_final_data = mem_wb_q.pc + 32'd4;
            WB_CIM:  wb_final_data = mem_wb_q.cim_result;   // imu_mac result
            default: wb_final_data = mem_wb_q.alu_result;   // WB_ALU
        endcase
    end

    assign wb_reg_write = mem_wb_q.reg_write && mem_wb_q.valid;
    assign wb_rd_addr   = mem_wb_q.rd_addr;

endmodule