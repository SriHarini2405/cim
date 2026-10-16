// =============================================================================
// File: mem_stage.sv
// Description: Memory (MEM) Stage with Load/Store Formatting & AXI Master
//              + CIM (imu_mac) result pass-through
// =============================================================================

import riscv_pkg::*;

module mem_stage (
    input  logic        clk,
    input  logic        rst_n,

    // From EX/MEM Register
    input  ex_mem_reg_t ex_mem_q,

    // Forwarding Output to EX Stage
    output logic [31:0] ex_mem_fwd_data,

    // Stall Output to Hazard Unit
    output logic        axi_stall,

    // Output to MEM/WB Register
    output mem_wb_reg_t mem_wb_d,

    // AXI4-Lite Master Interface
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

    logic        cpu_axi_req;
    logic        cpu_axi_we;
    logic [31:0] cpu_axi_addr;
    logic [31:0] cpu_axi_wdata;
    logic [3:0]  cpu_axi_wstrb;
    logic [31:0] cpu_axi_rdata;
    logic        cpu_axi_busy;
    logic        cpu_axi_done;

    assign cpu_axi_req  = (ex_mem_q.mem_read || ex_mem_q.mem_write) && ex_mem_q.valid && !cpu_axi_done;
    assign cpu_axi_we   = ex_mem_q.mem_write;
    assign cpu_axi_addr = ex_mem_q.alu_result;
    assign axi_stall    = cpu_axi_busy;

    // Format Store Data and Byte Strobes
    logic [1:0] byte_offset;
    assign byte_offset = ex_mem_q.alu_result[1:0];

    always_comb begin
        case (ex_mem_q.mem_format)
            MEM_BYTE: begin
                cpu_axi_wstrb = 4'b0001 << byte_offset;
                cpu_axi_wdata = {4{ex_mem_q.rs2_data[7:0]}};
            end
            MEM_HALF: begin
                cpu_axi_wstrb = byte_offset[1] ? 4'b1100 : 4'b0011;
                cpu_axi_wdata = {2{ex_mem_q.rs2_data[15:0]}};
            end
            default: begin // Word
                cpu_axi_wstrb = 4'b1111;
                cpu_axi_wdata = ex_mem_q.rs2_data;
            end
        endcase
    end

    // AXI4-Lite Master Bridge Instance
    axi_lite_master u_axi_master (
        .aclk(clk),
        .aresetn(rst_n),
        .cpu_req(cpu_axi_req),
        .cpu_we(cpu_axi_we),
        .cpu_addr(cpu_axi_addr),
        .cpu_wdata(cpu_axi_wdata),
        .cpu_wstrb(cpu_axi_wstrb),
        .cpu_rdata(cpu_axi_rdata),
        .cpu_busy(cpu_axi_busy),
        .cpu_done(cpu_axi_done),
        .m_axi_awaddr,
        .m_axi_awprot,
        .m_axi_awvalid,
        .m_axi_awready,
        .m_axi_wdata,
        .m_axi_wstrb,
        .m_axi_wvalid,
        .m_axi_wready,
        .m_axi_bresp,
        .m_axi_bvalid,
        .m_axi_bready,
        .m_axi_araddr,
        .m_axi_arprot,
        .m_axi_arvalid,
        .m_axi_arready,
        .m_axi_rdata,
        .m_axi_rresp,
        .m_axi_rvalid,
        .m_axi_rready
    );

    // Format Load Data (Sign and Zero extension)
    logic [31:0] aligned_mem_rdata;
    always_comb begin
        case (ex_mem_q.mem_format)
            MEM_BYTE: begin
                case (byte_offset)
                    2'b00: aligned_mem_rdata = {{24{cpu_axi_rdata[7]}},  cpu_axi_rdata[7:0]};
                    2'b01: aligned_mem_rdata = {{24{cpu_axi_rdata[15]}}, cpu_axi_rdata[15:8]};
                    2'b10: aligned_mem_rdata = {{24{cpu_axi_rdata[23]}}, cpu_axi_rdata[23:16]};
                    2'b11: aligned_mem_rdata = {{24{cpu_axi_rdata[31]}}, cpu_axi_rdata[31:24]};
                endcase
            end
            MEM_BYTEU: begin
                case (byte_offset)
                    2'b00: aligned_mem_rdata = {24'd0, cpu_axi_rdata[7:0]};
                    2'b01: aligned_mem_rdata = {24'd0, cpu_axi_rdata[15:8]};
                    2'b10: aligned_mem_rdata = {24'd0, cpu_axi_rdata[23:16]};
                    2'b11: aligned_mem_rdata = {24'd0, cpu_axi_rdata[31:24]};
                endcase
            end
            MEM_HALF: begin
                aligned_mem_rdata = byte_offset[1] ? {{16{cpu_axi_rdata[31]}}, cpu_axi_rdata[31:16]}
                                                   : {{16{cpu_axi_rdata[15]}}, cpu_axi_rdata[15:0]};
            end
            MEM_HALFU: begin
                aligned_mem_rdata = byte_offset[1] ? {16'd0, cpu_axi_rdata[31:16]}
                                                   : {16'd0, cpu_axi_rdata[15:0]};
            end
            default: aligned_mem_rdata = cpu_axi_rdata; // Word
        endcase
    end

    // Forwarding Data Generation
    always_comb begin
        case (ex_mem_q.wb_sel)
            WB_MEM:  ex_mem_fwd_data = aligned_mem_rdata;
            WB_MD:   ex_mem_fwd_data = ex_mem_q.md_result;
            WB_PC4:  ex_mem_fwd_data = ex_mem_q.pc + 32'd4;
            WB_CIM:  ex_mem_fwd_data = ex_mem_q.cim_result;   // imu_mac forwarding
            default: ex_mem_fwd_data = ex_mem_q.alu_result;
        endcase
    end

    // Pack MEM/WB Register Inputs
    assign mem_wb_d.pc         = ex_mem_q.pc;
    assign mem_wb_d.alu_result = ex_mem_q.alu_result;
    assign mem_wb_d.md_result  = ex_mem_q.md_result;
    assign mem_wb_d.cim_result = ex_mem_q.cim_result;         // imu_mac result
    assign mem_wb_d.is_cim     = ex_mem_q.is_cim;
    assign mem_wb_d.mem_rdata  = aligned_mem_rdata;
    assign mem_wb_d.rd_addr    = ex_mem_q.rd_addr;
    assign mem_wb_d.reg_write  = ex_mem_q.reg_write;
    assign mem_wb_d.wb_sel     = ex_mem_q.wb_sel;
    assign mem_wb_d.valid      = ex_mem_q.valid;

endmodule