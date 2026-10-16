// =============================================================================
// File: axi_lite_slave_mem.sv
// Description: AMBA AXI4-Lite Slave Memory for Data and Dual-Port Instruction Fetch
// =============================================================================

module axi_lite_slave_mem #(
    parameter int MEM_SIZE_BYTES = 4096, // 4 KB Memory
    parameter int ADDR_WIDTH     = $clog2(MEM_SIZE_BYTES)
)(
    input  logic        aclk,
    input  logic        aresetn,

    // -------------------------------------------------------------------------
    // Port 1: Direct Instruction Fetch Port (Single-cycle synchronous read)
    // -------------------------------------------------------------------------
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_rdata,

    // -------------------------------------------------------------------------
    // Port 2: AXI4-Lite Slave Interface for Data Memory (Loads & Stores)
    // -------------------------------------------------------------------------
    // Write Address Channel
    input  logic [31:0] s_axi_awaddr,
    input  logic [2:0]  s_axi_awprot,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    // Write Data Channel
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    // Write Response Channel
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    // Read Address Channel
    input  logic [31:0] s_axi_araddr,
    input  logic [2:0]  s_axi_arprot,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    // Read Data Channel
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready
);

    // 32-bit word array (4 KB = 1024 words)
    localparam int NUM_WORDS = MEM_SIZE_BYTES / 4;
    logic [31:0] mem [0:NUM_WORDS-1];

    // -------------------------------------------------------------------------
    // Port 1: Combinational Instruction Read
    // -------------------------------------------------------------------------
    logic [ADDR_WIDTH-3:0] instr_word_addr;
    assign instr_word_addr = instr_addr[ADDR_WIDTH-1:2];
    assign instr_rdata     = mem[instr_word_addr];

    // -------------------------------------------------------------------------
    // Port 2: AXI4-Lite Slave Logic
    // -------------------------------------------------------------------------
    assign s_axi_bresp = 2'b00; // OKAY
    assign s_axi_rresp = 2'b00; // OKAY

    // Write Handshake
    logic [ADDR_WIDTH-3:0] write_word_addr;
    assign write_word_addr = s_axi_awaddr[ADDR_WIDTH-1:2];

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
        end else begin
            // Ready generation
            s_axi_awready <= s_axi_awvalid && !s_axi_bvalid;
            s_axi_wready  <= s_axi_wvalid  && !s_axi_bvalid;

            // Perform Memory Write with Byte Strobes
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                if (s_axi_wstrb[0]) mem[write_word_addr][7:0]   <= s_axi_wdata[7:0];
                if (s_axi_wstrb[1]) mem[write_word_addr][15:8]  <= s_axi_wdata[15:8];
                if (s_axi_wstrb[2]) mem[write_word_addr][23:16] <= s_axi_wdata[23:16];
                if (s_axi_wstrb[3]) mem[write_word_addr][31:24] <= s_axi_wdata[31:24];
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // Read Handshake
    logic [ADDR_WIDTH-3:0] read_word_addr;
    assign read_word_addr = s_axi_araddr[ADDR_WIDTH-1:2];

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
        end else begin
            s_axi_arready <= s_axi_arvalid && !s_axi_rvalid;

            if (s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rdata  <= mem[read_word_addr];
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rready && s_axi_rvalid) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
