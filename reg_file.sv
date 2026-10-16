// =============================================================================
// File: reg_file.sv
// Description: 32x32-bit Dual-Read, Single-Write Register File for RISC-V
//              x0 is hardwired to zero. Includes internal write-to-read bypass.
// =============================================================================

module reg_file (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [4:0]  raddr1,
    output logic [31:0] rdata1,
    input  logic [4:0]  raddr2,
    output logic [31:0] rdata2,
    input  logic        we,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata
);

    logic [31:0] regs [1:31];

    // Synchronous write
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 1; i < 32; i++) begin
                regs[i] <= 32'd0;
            end
        end else if (we && (waddr != 5'd0)) begin
            regs[waddr] <= wdata;
        end
    end

    // Combinational read with write-to-read bypass
    always_comb begin
        if (raddr1 == 5'd0) begin
            rdata1 = 32'd0;
        end else if (we && (waddr == raddr1)) begin
            rdata1 = wdata; // Bypass in the same cycle
        end else begin
            rdata1 = regs[raddr1];
        end

        if (raddr2 == 5'd0) begin
            rdata2 = 32'd0;
        end else if (we && (waddr == raddr2)) begin
            rdata2 = wdata; // Bypass in the same cycle
        end else begin
            rdata2 = regs[raddr2];
        end
    end

endmodule
