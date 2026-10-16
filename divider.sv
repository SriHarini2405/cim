// =============================================================================
// File: divider.sv
// Description: RV32M Hardware Sequential Divider (DIV, DIVU, REM, REMU)
//              Compliant with RISC-V corner cases (div-by-zero, signed overflow)
// =============================================================================

import riscv_pkg::*;

module divider (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  m_op_e        m_op,
    input  logic [31:0]  a,      // Dividend
    input  logic [31:0]  b,      // Divisor
    output logic [31:0]  result,
    output logic         busy,
    output logic         ready
);

    typedef enum logic [1:0] {
        IDLE,
        DIVIDE,
        DONE
    } div_state_e;

    div_state_e state;
    logic [5:0]  count;
    logic [63:0] remainder_quotient;
    logic [31:0] abs_divisor;
    logic        is_signed;
    logic        neg_quotient;
    logic        neg_remainder;
    m_op_e       m_op_reg;
    logic [31:0] result_reg;

    always_comb begin
        is_signed = (m_op == M_OP_DIV || m_op == M_OP_REM);
    end

    // Corner cases
    logic div_by_zero;
    logic overflow;
    assign div_by_zero = (b == 32'd0);
    assign overflow    = is_signed && (a == 32'h80000000) && (b == 32'hFFFFFFFF);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= IDLE;
            count              <= '0;
            remainder_quotient <= '0;
            abs_divisor        <= '0;
            neg_quotient       <= '0;
            neg_remainder      <= '0;
            result_reg         <= '0;
            busy               <= 1'b0;
            ready              <= 1'b0;
            m_op_reg           <= M_OP_DIV;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    if (start) begin
                        m_op_reg <= m_op;
                        busy     <= 1'b1;

                        // Check RISC-V edge cases immediately
                        if (div_by_zero) begin
                            state <= DONE;
                            case (m_op)
                                M_OP_DIV, M_OP_DIVU: result_reg <= 32'hFFFFFFFF;
                                M_OP_REM, M_OP_REMU: result_reg <= a;
                                default:             result_reg <= 32'hFFFFFFFF;
                            endcase
                        end else if (overflow) begin
                            state <= DONE;
                            case (m_op)
                                M_OP_DIV: result_reg <= 32'h80000000;
                                M_OP_REM: result_reg <= 32'h00000000;
                                default:  result_reg <= 32'h80000000;
                            endcase
                        end else begin
                            state <= DIVIDE;
                            count <= 6'd32;

                            // Determine sign and magnitudes
                            neg_quotient  <= is_signed ? (a[31] ^ b[31]) : 1'b0;
                            neg_remainder <= is_signed ? a[31] : 1'b0;

                            abs_divisor <= (is_signed && b[31]) ? (-b) : b;
                            remainder_quotient <= {32'd0, (is_signed && a[31]) ? (-a) : a};
                        end
                    end else begin
                        busy <= 1'b0;
                    end
                end

                DIVIDE: begin
                    // Radix-2 non-restoring step
                    logic [31:0] rem_part;
                    logic [31:0] quo_part;
                    logic [63:0] shifted;
                    
                    shifted = remainder_quotient << 1;
                    rem_part = shifted[63:32];
                    quo_part = shifted[31:0];

                    if (rem_part >= abs_divisor) begin
                        rem_part = rem_part - abs_divisor;
                        quo_part[0] = 1'b1;
                    end

                    remainder_quotient <= {rem_part, quo_part};
                    count <= count - 1'b1;

                    if (count == 6'd1) begin
                        logic [31:0] final_q;
                        logic [31:0] final_r;
                        final_q = neg_quotient  ? (-quo_part)  : quo_part;
                        final_r = neg_remainder ? (-rem_part) : rem_part;

                        case (m_op_reg)
                            M_OP_DIV, M_OP_DIVU: result_reg <= final_q;
                            M_OP_REM, M_OP_REMU: result_reg <= final_r;
                            default:             result_reg <= final_q;
                        endcase

                        busy  <= 1'b0;
                        ready <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    ready <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign result = result_reg;

endmodule
