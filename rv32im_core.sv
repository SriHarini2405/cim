// =============================================================================
// File: rv32im_core.sv
// Description: 5-Stage Pipelined RV32IM Processor Core integrating modular stages:
//              IF -> ID -> EX -> MEM -> WB with Hazards & Forwarding
// =============================================================================

import riscv_pkg::*;

module rv32im_core (
    input  logic        clk,
    input  logic        rst_n,

    // Instruction Fetch Interface (Memory Port 1)
    output logic [31:0] instr_addr,
    input  logic [31:0] instr_rdata,

    // AXI4-Lite Data Memory Master Interface (Memory Port 2)
    output logic [31:0] m_axi_awaddr,
    output logic [2:0]  m_axi_awprot,
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,

    output logic [31:0] m_axi_wdata,
    output logic [3:0]  m_axi_wstrb,
    output logic        m_axi_wvalid,
    input  logic        m_axi_wready,

    input  logic [1:0]  m_axi_bresp,
    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,

    output logic [31:0] m_axi_araddr,
    output logic [2:0]  m_axi_arprot,
    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,

    input  logic [31:0] m_axi_rdata,
    input  logic [1:0]  m_axi_rresp,
    input  logic        m_axi_rvalid,
    output logic        m_axi_rready
);

    // -------------------------------------------------------------------------
    // Inter-stage Pipeline Register Structs
    // -------------------------------------------------------------------------
    if_id_reg_t   if_id_d,   if_id_q;
    id_ex_reg_t   id_ex_d,   id_ex_q;
    ex_mem_reg_t  ex_mem_d,  ex_mem_q;
    mem_wb_reg_t  mem_wb_d,  mem_wb_q;

    // Hazard & Stall Control Wires
    logic pc_stall, if_id_stall, if_id_flush;
    logic id_ex_stall, id_ex_flush;
    logic ex_mem_stall, ex_mem_flush;
    logic mem_wb_stall;
    logic axi_stall;
    logic div_stall;
    logic div_busy;

    // Forwarding Wires
    fwd_sel_e    fwd_a, fwd_b;
    logic [31:0] ex_mem_fwd_data;
    logic [31:0] wb_final_data;
    logic        wb_reg_write;
    logic [4:0]  wb_rd_addr;

    // Branch & Redirect Wires
    logic [31:0] pc_reg;
    logic [31:0] branch_target;
    logic        branch_redirect;
    logic [4:0]  id_rs1_addr, id_rs2_addr;
    logic [31:0] rf_rdata1, rf_rdata2;

    // =========================================================================
    // STAGE 1: INSTRUCTION FETCH (IF)
    // =========================================================================
    if_stage u_if_stage (
        .clk(clk),
        .rst_n(rst_n),
        .pc_stall(pc_stall),
        .branch_redirect(branch_redirect),
        .branch_target(branch_target),
        .instr_addr(instr_addr),
        .instr_rdata(instr_rdata),
        .if_id_d(if_id_d),
        .pc_current(pc_reg)
    );

    // IF/ID Pipeline Register
    if_id_reg u_if_id_reg (
        .clk(clk),
        .rst_n(rst_n),
        .stall(if_id_stall),
        .flush(if_id_flush),
        .d(if_id_d),
        .q(if_id_q)
    );

    // =========================================================================
    // STAGE 2: INSTRUCTION DECODE (ID)
    // =========================================================================
    // Register File Instance
    reg_file u_reg_file (
        .clk(clk),
        .rst_n(rst_n),
        .raddr1(id_rs1_addr),
        .rdata1(rf_rdata1),
        .raddr2(id_rs2_addr),
        .rdata2(rf_rdata2),
        .we(wb_reg_write),
        .waddr(wb_rd_addr),
        .wdata(wb_final_data)
    );

    id_stage u_id_stage (
        .if_id_q(if_id_q),
        .rs1_addr(id_rs1_addr),
        .rs2_addr(id_rs2_addr),
        .rf_rdata1(rf_rdata1),
        .rf_rdata2(rf_rdata2),
        .id_ex_d(id_ex_d)
    );

    // ID/EX Pipeline Register
    id_ex_reg u_id_ex_reg (
        .clk(clk),
        .rst_n(rst_n),
        .stall(id_ex_stall),
        .flush(id_ex_flush),
        .d(id_ex_d),
        .q(id_ex_q)
    );

    // =========================================================================
    // STAGE 3: EXECUTE (EX)
    // =========================================================================
    ex_stage u_ex_stage (
        .clk(clk),
        .rst_n(rst_n),
        .id_ex_q(id_ex_q),
        .fwd_a(fwd_a),
        .fwd_b(fwd_b),
        .ex_mem_fwd_data(ex_mem_fwd_data),
        .wb_final_data(wb_final_data),
        .branch_redirect(branch_redirect),
        .branch_target(branch_target),
        .div_stall(div_stall),
        .div_busy(div_busy),
        .ex_mem_d(ex_mem_d)
    );

    // EX/MEM Pipeline Register
    ex_mem_reg u_ex_mem_reg (
        .clk(clk),
        .rst_n(rst_n),
        .stall(ex_mem_stall),
        .flush(ex_mem_flush),
        .d(ex_mem_d),
        .q(ex_mem_q)
    );

    // =========================================================================
    // STAGE 4: MEMORY ACCESS (MEM) via AXI4-LITE
    // =========================================================================
    mem_stage u_mem_stage (
        .clk(clk),
        .rst_n(rst_n),
        .ex_mem_q(ex_mem_q),
        .ex_mem_fwd_data(ex_mem_fwd_data),
        .axi_stall(axi_stall),
        .mem_wb_d(mem_wb_d),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    // MEM/WB Pipeline Register
    mem_wb_reg u_mem_wb_reg (
        .clk(clk),
        .rst_n(rst_n),
        .stall(mem_wb_stall),
        .d(mem_wb_d),
        .q(mem_wb_q)
    );

    // =========================================================================
    // STAGE 5: WRITEBACK (WB)
    // =========================================================================
    wb_stage u_wb_stage (
        .mem_wb_q(mem_wb_q),
        .wb_final_data(wb_final_data),
        .wb_reg_write(wb_reg_write),
        .wb_rd_addr(wb_rd_addr)
    );

    // =========================================================================
    // HAZARD & FORWARDING UNITS
    // =========================================================================
    hazard_unit u_hazard_unit (
        .if_id_rs1(id_rs1_addr),
        .if_id_rs2(id_rs2_addr),
        .id_ex_rd(id_ex_q.rd_addr),
        .id_ex_mem_read(id_ex_q.mem_read),
        .branch_redirect(branch_redirect),
        .div_busy(div_stall || div_busy),
        .axi_stall(axi_stall),
        .pc_stall(pc_stall),
        .if_id_stall(if_id_stall),
        .if_id_flush(if_id_flush),
        .id_ex_stall(id_ex_stall),
        .id_ex_flush(id_ex_flush),
        .ex_mem_stall(ex_mem_stall),
        .ex_mem_flush(ex_mem_flush),
        .mem_wb_stall(mem_wb_stall)
    );

    forwarding_unit u_forwarding_unit (
        .id_ex_rs1(id_ex_q.rs1_addr),
        .id_ex_rs2(id_ex_q.rs2_addr),
        .ex_mem_rd(ex_mem_q.rd_addr),
        .ex_mem_reg_write(ex_mem_q.reg_write && ex_mem_q.valid),
        .mem_wb_rd(mem_wb_q.rd_addr),
        .mem_wb_reg_write(mem_wb_q.reg_write && mem_wb_q.valid),
        .fwd_a(fwd_a),
        .fwd_b(fwd_b)
    );

endmodule
