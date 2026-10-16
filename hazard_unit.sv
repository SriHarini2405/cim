// =============================================================================
// File: hazard_unit.sv
// Description: Pipeline Hazard Detection and Stall/Flush Control
// =============================================================================

module hazard_unit (
    input  logic [4:0]  if_id_rs1,
    input  logic [4:0]  if_id_rs2,
    input  logic [4:0]  id_ex_rd,
    input  logic        id_ex_mem_read,
    input  logic        branch_redirect,
    input  logic        div_busy,
    input  logic        axi_stall,
    output logic        pc_stall,
    output logic        if_id_stall,
    output logic        if_id_flush,
    output logic        id_ex_stall,
    output logic        id_ex_flush,
    output logic        ex_mem_stall,
    output logic        ex_mem_flush,
    output logic        mem_wb_stall
);

    logic load_use_hazard;

    always_comb begin
        // Load-Use Hazard Detection
        load_use_hazard = id_ex_mem_read && (id_ex_rd != 5'd0) &&
                          ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2));

        // Default: no stalls, no flushes
        pc_stall     = 1'b0;
        if_id_stall  = 1'b0;
        if_id_flush  = 1'b0;
        id_ex_stall  = 1'b0;
        id_ex_flush  = 1'b0;
        ex_mem_stall = 1'b0;
        ex_mem_flush = 1'b0;
        mem_wb_stall = 1'b0;

        // Priority 1: AXI Bus Memory Stall (stalls entire pipeline while waiting for bus)
        if (axi_stall) begin
            pc_stall     = 1'b1;
            if_id_stall  = 1'b1;
            id_ex_stall  = 1'b1;
            ex_mem_stall = 1'b1;
            mem_wb_stall = 1'b1;
        end
        // Priority 2: Multi-cycle Divider Busy Stall
        else if (div_busy) begin
            pc_stall     = 1'b1;
            if_id_stall  = 1'b1;
            id_ex_stall  = 1'b1;
            ex_mem_flush = 1'b1; // Insert bubble into EX/MEM
        end
        // Priority 3: Branch / Jump Taken (Control Hazard Flush)
        else if (branch_redirect) begin
            if_id_flush = 1'b1;
            id_ex_flush = 1'b1;
        end
        // Priority 4: Load-Use Data Hazard
        else if (load_use_hazard) begin
            pc_stall    = 1'b1;
            if_id_stall = 1'b1;
            id_ex_flush = 1'b1; // Insert bubble into ID/EX
        end
    end

endmodule
