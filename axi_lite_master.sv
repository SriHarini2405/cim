// =============================================================================
// File: axi_lite_master.sv
// Description: AMBA AXI4-Lite Master Controller bridging CPU MEM stage to AXI Bus
// =============================================================================

module axi_lite_master (
    input  logic        aclk,
    input  logic        aresetn,

    // CPU Memory Stage Interface
    input  logic        cpu_req,
    input  logic        cpu_we,
    input  logic [31:0] cpu_addr,
    input  logic [31:0] cpu_wdata,
    input  logic [3:0]  cpu_wstrb,
    output logic [31:0] cpu_rdata,
    output logic        cpu_busy,
    output logic        cpu_done,

    // AXI4-Lite Write Address Channel
    output logic [31:0] m_axi_awaddr,
    output logic [2:0]  m_axi_awprot,
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,

    // AXI4-Lite Write Data Channel
    output logic [31:0] m_axi_wdata,
    output logic [3:0]  m_axi_wstrb,
    output logic        m_axi_wvalid,
    input  logic        m_axi_wready,

    // AXI4-Lite Write Response Channel
    input  logic [1:0]  m_axi_bresp,
    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,

    // AXI4-Lite Read Address Channel
    output logic [31:0] m_axi_araddr,
    output logic [2:0]  m_axi_arprot,
    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,

    // AXI4-Lite Read Data Channel
    input  logic [31:0] m_axi_rdata,
    input  logic [1:0]  m_axi_rresp,
    input  logic        m_axi_rvalid,
    output logic        m_axi_rready
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_READ_ADDR,
        ST_READ_DATA,
        ST_WRITE_ADDR_DATA,
        ST_WRITE_RESP
    } axi_state_e;

    axi_state_e state;
    logic aw_done;
    logic w_done;

    assign m_axi_awprot = 3'b000;
    assign m_axi_arprot = 3'b000;

    assign cpu_busy = (cpu_req && !cpu_done) || (state != ST_IDLE);

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state          <= ST_IDLE;
            m_axi_awaddr   <= 32'd0;
            m_axi_awvalid  <= 1'b0;
            m_axi_wdata    <= 32'd0;
            m_axi_wstrb    <= 4'd0;
            m_axi_wvalid   <= 1'b0;
            m_axi_bready   <= 1'b0;
            m_axi_araddr   <= 32'd0;
            m_axi_arvalid  <= 1'b0;
            m_axi_rready   <= 1'b0;
            cpu_rdata      <= 32'd0;
            cpu_done       <= 1'b0;
            aw_done        <= 1'b0;
            w_done         <= 1'b0;
        end else begin
            cpu_done <= 1'b0; // Pulse for 1 cycle when completed

            case (state)
                ST_IDLE: begin
                    if (cpu_req) begin
                        if (cpu_we) begin
                            // Initiate Write Transaction
                            m_axi_awaddr  <= cpu_addr;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wdata   <= cpu_wdata;
                            m_axi_wstrb   <= cpu_wstrb;
                            m_axi_wvalid  <= 1'b1;
                            aw_done       <= 1'b0;
                            w_done        <= 1'b0;
                            state         <= ST_WRITE_ADDR_DATA;
                        end else begin
                            // Initiate Read Transaction
                            m_axi_araddr  <= cpu_addr;
                            m_axi_arvalid <= 1'b1;
                            state         <= ST_READ_ADDR;
                        end
                    end
                end

                // -------------------------------------------------------------
                // Read Channels
                // -------------------------------------------------------------
                ST_READ_ADDR: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= ST_READ_DATA;
                    end
                end

                ST_READ_DATA: begin
                    if (m_axi_rvalid) begin
                        cpu_rdata     <= m_axi_rdata;
                        m_axi_rready  <= 1'b0;
                        cpu_done      <= 1'b1;
                        state         <= ST_IDLE;
                    end
                end

                // -------------------------------------------------------------
                // Write Channels
                // -------------------------------------------------------------
                ST_WRITE_ADDR_DATA: begin
                    // Check write address handshake
                    if (m_axi_awready && m_axi_awvalid) begin
                        m_axi_awvalid <= 1'b0;
                        aw_done       <= 1'b1;
                    end

                    // Check write data handshake
                    if (m_axi_wready && m_axi_wvalid) begin
                        m_axi_wvalid <= 1'b0;
                        w_done       <= 1'b1;
                    end

                    // Once both are accepted, wait for response
                    if ((aw_done || (m_axi_awready && m_axi_awvalid)) &&
                        (w_done  || (m_axi_wready  && m_axi_wvalid))) begin
                        m_axi_bready <= 1'b1;
                        state        <= ST_WRITE_RESP;
                    end
                end

                ST_WRITE_RESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        cpu_done     <= 1'b1;
                        state        <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
