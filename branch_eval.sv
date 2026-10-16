// =============================================================================
// File: branch_eval.sv
// Description: Branch Condition Evaluator for RISC-V B-type instructions
// =============================================================================

import riscv_pkg::*;

module branch_eval (
    input  branch_op_e  branch_type,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic        branch_taken
);

    always_comb begin
        case (branch_type)
            BR_BEQ:  branch_taken = (a == b);
            BR_BNE:  branch_taken = (a != b);
            BR_BLT:  branch_taken = ($signed(a) < $signed(b));
            BR_BGE:  branch_taken = ($signed(a) >= $signed(b));
            BR_BLTU: branch_taken = (a < b);
            BR_BGEU: branch_taken = (a >= b);
            default: branch_taken = 1'b0;
        endcase
    end

endmodule
