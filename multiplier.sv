// =============================================================================
// File: multiplier.sv
// Description: RV32M Hardware Multiplier (MUL, MULH, MULHSU, MULHU)
// =============================================================================

import riscv_pkg::*;

module multiplier (
    input  m_op_e        m_op,
    input  logic [31:0]  a,
    input  logic [31:0]  b,
    output logic [31:0]  result
);

    logic signed [63:0] mul_ss; // Signed * Signed
    logic signed [64:0] mul_su; // Signed * Unsigned
    logic        [63:0] mul_uu; // Unsigned * Unsigned

    always_comb begin
        mul_ss = $signed(a) * $signed(b);
        mul_su = $signed({{33{a[31]}}, a}) * $signed({33'd0, b});
        mul_uu = {32'd0, a} * {32'd0, b};

        case (m_op)
            M_OP_MUL:    result = mul_ss[31:0];
            M_OP_MULH:   result = mul_ss[63:32];
            M_OP_MULHSU: result = mul_su[63:32];
            M_OP_MULHU:  result = mul_uu[63:32];
            default:     result = mul_ss[31:0];
        endcase
    end

endmodule
