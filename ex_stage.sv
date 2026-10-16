// =============================================================================
// File: ex_stage.sv
// Description: Execution (EX) Stage: ALU, Multiplier, Divider, Branch Evaluation,
//              + CIM (imu_mac) unit
// =============================================================================

import riscv_pkg::*;

module ex_stage (
    input  logic        clk,
    input  logic        rst_n,

    // From ID/EX Register
    input  id_ex_reg_t  id_ex_q,

    // Forwarding Inputs
    input  fwd_sel_e    fwd_a,
    input  fwd_sel_e    fwd_b,
    input  logic [31:0] ex_mem_fwd_data,
    input  logic [31:0] wb_final_data,

    // Branch / Jump Redirection Outputs to IF Stage
    output logic        branch_redirect,
    output logic [31:0] branch_target,

    // Stall & Status Outputs
    output logic        div_stall,
    output logic        div_busy,

    // Output to EX/MEM Register
    output ex_mem_reg_t ex_mem_d
);

    // Forwarding Multiplexers
    logic [31:0] fwd_operand_a, fwd_operand_b;
    always_comb begin
        case (fwd_a)
            FWD_EX:   fwd_operand_a = ex_mem_fwd_data;
            FWD_MEM:  fwd_operand_a = wb_final_data;
            default:  fwd_operand_a = id_ex_q.rs1_data;
        endcase

        case (fwd_b)
            FWD_EX:   fwd_operand_b = ex_mem_fwd_data;
            FWD_MEM:  fwd_operand_b = wb_final_data;
            default:  fwd_operand_b = id_ex_q.rs2_data;
        endcase
    end

    // ALU Inputs and Instance
    logic [31:0] alu_in_a, alu_in_b, alu_result;
    logic        alu_zero;
    assign alu_in_a = id_ex_q.alu_src_a ? id_ex_q.pc  : fwd_operand_a;
    assign alu_in_b = id_ex_q.alu_src_b ? id_ex_q.imm : fwd_operand_b;

    alu u_alu (
        .alu_op(id_ex_q.alu_op),
        .a(alu_in_a),
        .b(alu_in_b),
        .result(alu_result),
        .zero(alu_zero)
    );

    // Branch Condition Evaluation
    logic branch_taken;
    branch_eval u_branch_eval (
        .branch_type(id_ex_q.branch_type),
        .a(fwd_operand_a),
        .b(fwd_operand_b),
        .branch_taken(branch_taken)
    );

    always_comb begin
        if (id_ex_q.is_jalr) begin
            branch_target = (fwd_operand_a + id_ex_q.imm) & ~32'd1;
        end else begin
            branch_target = id_ex_q.pc + id_ex_q.imm;
        end
        branch_redirect = id_ex_q.valid && ((id_ex_q.is_branch && branch_taken) || id_ex_q.is_jal || id_ex_q.is_jalr);
    end

    // RV32M Hardware Multiplier
    logic [31:0] mul_result;
    multiplier u_multiplier (
        .m_op(id_ex_q.m_op),
        .a(fwd_operand_a),
        .b(fwd_operand_b),
        .result(mul_result)
    );

    // RV32M Hardware Divider
    logic [31:0] div_result;
    logic        div_ready;
    logic        is_div_op;
    logic        div_running;
    logic        div_start;

    assign is_div_op = id_ex_q.valid && id_ex_q.is_m_ext && id_ex_q.m_op[2]; // DIV, DIVU, REM, REMU
    assign div_start = is_div_op && !div_running && !div_ready;
    assign div_stall = is_div_op && !div_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_running <= 1'b0;
        end else if (div_ready) begin
            div_running <= 1'b0;
        end else if (is_div_op) begin
            div_running <= 1'b1;
        end
    end

    divider u_divider (
        .clk(clk),
        .rst_n(rst_n),
        .start(div_start),
        .m_op(id_ex_q.m_op),
        .a(fwd_operand_a),
        .b(fwd_operand_b),
        .result(div_result),
        .busy(div_busy),
        .ready(div_ready)
    );

    logic [31:0] md_result;
    assign md_result = is_div_op ? div_result : mul_result;

    // -------------------------------------------------------------------------
    // CIM (imu_mac) Unit  -- combinational, uses forwarded operands
    // -------------------------------------------------------------------------
    logic [31:0] cim_out;
    cim_mac_unit u_cim (
        .rs1_data(fwd_operand_a),
        .rs2_data(fwd_operand_b),
        .result  (cim_out)
    );

    // Pack EX/MEM Inputs
    assign ex_mem_d.pc         = id_ex_q.pc;
    assign ex_mem_d.alu_result = alu_result;
    assign ex_mem_d.md_result  = md_result;
    assign ex_mem_d.cim_result = id_ex_q.is_cim ? cim_out : 32'b0;
    assign ex_mem_d.is_cim     = id_ex_q.is_cim;
    assign ex_mem_d.rs2_data   = fwd_operand_b; // Store data
    assign ex_mem_d.rd_addr    = id_ex_q.rd_addr;
    assign ex_mem_d.mem_read   = id_ex_q.mem_read;
    assign ex_mem_d.mem_write  = id_ex_q.mem_write;
    assign ex_mem_d.mem_format = id_ex_q.mem_format;
    assign ex_mem_d.reg_write  = id_ex_q.reg_write;
    assign ex_mem_d.wb_sel     = id_ex_q.wb_sel;
    assign ex_mem_d.valid      = id_ex_q.valid && !branch_redirect;

endmodule