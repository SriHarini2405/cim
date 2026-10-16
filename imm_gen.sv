// =============================================================================
// File: imm_gen.sv
// Description: Immediate Generator for RISC-V (I, S, B, U, J types)
// =============================================================================

import riscv_pkg::*;

module imm_gen (
    input  logic [31:0] instr,
    output logic [31:0] imm
);

    opcode_e opcode;
    assign opcode = opcode_e'(instr[6:0]);

    always_comb begin
        case (opcode)
            OP_OP_IMM,
            OP_LOAD,
            OP_JALR: begin
                // I-type
                imm = {{20{instr[31]}}, instr[31:20]};
            end

            OP_STORE: begin
                // S-type
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end

            OP_BRANCH: begin
                // B-type
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            end

            OP_LUI,
            OP_AUIPC: begin
                // U-type
                imm = {instr[31:12], 12'd0};
            end

            OP_JAL: begin
                // J-type
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            end

            default: begin
                imm = 32'd0;
            end
        endcase
    end

endmodule
