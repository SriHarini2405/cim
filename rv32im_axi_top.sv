// =============================================================================
// File: rv32im_axi_top.sv
// Description: Top-Level SoC integrating RV32IM Core + AXI4-Lite Bus + Unified Memory
// =============================================================================

import riscv_pkg::*;

module rv32im_axi_top #(
    parameter int MEM_SIZE_BYTES = 4096 // 4 KB on-chip memory
)(
    input  logic        clk,
    input  logic        rst_n,

    // Debug / Verification Outputs
    output logic [31:0] debug_pc,
    output logic [31:0] debug_wb_data,
    output logic [4:0]  debug_wb_rd,
    output logic        debug_wb_valid
);

    // -------------------------------------------------------------------------
    // Interconnect Wires
    // -------------------------------------------------------------------------
    // Port 1: Instruction Fetch Bus
    logic [31:0] instr_addr;
    logic [31:0] instr_rdata;

    // Port 2: AXI4-Lite Bus Signals
    logic [31:0] axi_awaddr;
    logic [2:0]  axi_awprot;
    logic        axi_awvalid;
    logic        axi_awready;

    logic [31:0] axi_wdata;
    logic [3:0]  axi_wstrb;
    logic        axi_wvalid;
    logic        axi_wready;

    logic [1:0]  axi_bresp;
    logic        axi_bvalid;
    logic        axi_bready;

    logic [31:0] axi_araddr;
    logic [2:0]  axi_arprot;
    logic        axi_arvalid;
    logic        axi_arready;

    logic [31:0] axi_rdata;
    logic [1:0]  axi_rresp;
    logic        axi_rvalid;
    logic        axi_rready;

    // -------------------------------------------------------------------------
    // RV32IM Core Instantiation
    // -------------------------------------------------------------------------
    rv32im_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .instr_addr(instr_addr),
        .instr_rdata(instr_rdata),
        .m_axi_awaddr(axi_awaddr),
        .m_axi_awprot(axi_awprot),
        .m_axi_awvalid(axi_awvalid),
        .m_axi_awready(axi_awready),
        .m_axi_wdata(axi_wdata),
        .m_axi_wstrb(axi_wstrb),
        .m_axi_wvalid(axi_wvalid),
        .m_axi_wready(axi_wready),
        .m_axi_bresp(axi_bresp),
        .m_axi_bvalid(axi_bvalid),
        .m_axi_bready(axi_bready),
        .m_axi_araddr(axi_araddr),
        .m_axi_arprot(axi_arprot),
        .m_axi_arvalid(axi_arvalid),
        .m_axi_arready(axi_arready),
        .m_axi_rdata(axi_rdata),
        .m_axi_rresp(axi_rresp),
        .m_axi_rvalid(axi_rvalid),
        .m_axi_rready(axi_rready)
    );

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave Memory Instantiation
    // -------------------------------------------------------------------------
    axi_lite_slave_mem #(
        .MEM_SIZE_BYTES(MEM_SIZE_BYTES)
    ) u_axi_mem (
        .aclk(clk),
        .aresetn(rst_n),
        .instr_addr(instr_addr),
        .instr_rdata(instr_rdata),
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awprot(axi_awprot),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),
        .s_axi_wdata(axi_wdata),
        .s_axi_wstrb(axi_wstrb),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),
        .s_axi_bresp(axi_bresp),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),
        .s_axi_araddr(axi_araddr),
        .s_axi_arprot(axi_arprot),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),
        .s_axi_rdata(axi_rdata),
        .s_axi_rresp(axi_rresp),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready)
    );

    // Debug output assignments
    assign debug_pc       = u_core.pc_reg;
    assign debug_wb_data  = u_core.wb_final_data;
    assign debug_wb_rd    = u_core.mem_wb_q.rd_addr;
    assign debug_wb_valid = u_core.mem_wb_q.valid && u_core.mem_wb_q.reg_write;

endmodule
