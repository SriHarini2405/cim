// =============================================================================
// File: tb_rv32im_axi.sv
// Description: Self-Checking Testbench for 5-Stage RV32IM with AXI4-Lite Bus
//              Verifies Hardware MAC, RV32M Divide/Remainder, and imu_mac (custom-0)
//              imu_mac = packed INT8 4-lane dot product (cim_mac_unit)
// =============================================================================

`timescale 1ns / 1ps

import riscv_pkg::*;

module tb_rv32im_axi;

    logic        clk;
    logic        rst_n;
    logic [31:0] debug_pc;
    logic [31:0] debug_wb_data;
    logic [4:0]  debug_wb_rd;
    logic        debug_wb_valid;

    // Instantiate Top-Level SoC
    rv32im_axi_top #(
        .MEM_SIZE_BYTES(4096)
    ) u_top (
        .clk(clk),
        .rst_n(rst_n),
        .debug_pc(debug_pc),
        .debug_wb_data(debug_wb_data),
        .debug_wb_rd(debug_wb_rd),
        .debug_wb_valid(debug_wb_valid)
    );

    // Clock Generation: 100 MHz (10ns period)
    always #5 clk = ~clk;

    // Testbench Variables
    int cycle_count = 0;
    int mem_read_count = 0;
    int mem_write_count = 0;
    integer expected_acc, expected_div, expected_rem;
    integer actual_mem_acc, actual_reg_acc, actual_reg_div, actual_reg_rem;

    // imu_mac test variables
    integer expected_cim1, expected_cim_dep, expected_cim_neg;
    integer actual_cim1, actual_cim_dep, actual_cim_neg;
    integer expected_cim_pk, expected_cim_pks;
    integer actual_cim_pk,   actual_cim_pks;

    // Monitor AXI memory bus transactions
    always_ff @(posedge clk) begin
        if (rst_n) begin
            cycle_count++;
            if (u_top.axi_arvalid && u_top.axi_arready) begin
                mem_read_count++;
                $display("[%0t ns] AXI READ  REQUEST: Addr = 0x%08x", $time, u_top.axi_araddr);
            end
            if (u_top.axi_rvalid && u_top.axi_rready) begin
                $display("[%0t ns] AXI READ  DATA   : Data = 0x%08x (%0d)", $time, u_top.axi_rdata, $signed(u_top.axi_rdata));
            end
            if (u_top.axi_awvalid && u_top.axi_awready) begin
                mem_write_count++;
                $display("[%0t ns] AXI WRITE REQUEST: Addr = 0x%08x, Data = 0x%08x (%0d)", 
                         $time, u_top.axi_awaddr, u_top.axi_wdata, $signed(u_top.axi_wdata));
            end
        end
    end

    // Monitor Register Writeback
    always_ff @(posedge clk) begin
        if (rst_n && debug_wb_valid && debug_wb_rd != 5'd0) begin
            $display("[%0t ns] WB: x%0d <= 0x%08x (%0d) at PC = 0x%08x", 
                     $time, debug_wb_rd, debug_wb_data, $signed(debug_wb_data), debug_pc);
        end
    end

    // -------------------------------------------------------------------------
    // Main Test Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $display("==================================================================");
        $display(" STARTING 5-STAGE RV32IM WITH AXI4-LITE BUS TESTBENCH");
        $display(" Workload: MAC over AXI + Hardware DIV + imu_mac custom instruction");
        $display("==================================================================");

        clk   = 1'b0;
        rst_n = 1'b0;

        // Initialize Memory with Instructions (Program begins at address 0x00)
        u_top.u_axi_mem.mem[0]  = 32'h10000413; // addi s0, zero, 0x100 (Ptr to Vector X)
        u_top.u_axi_mem.mem[1]  = 32'h01040493; // addi s1, s0, 0x10    (Ptr to Vector W)
        u_top.u_axi_mem.mem[2]  = 32'h02040913; // addi s2, s0, 0x20    (Ptr to Result Acc)
        u_top.u_axi_mem.mem[3]  = 32'h00000693; // addi a3, zero, 0     (Clear Acc = 0)

        // MAC Iteration 0: Acc = 0 + (3 * 2) = 6
        u_top.u_axi_mem.mem[4]  = 32'h00042503; // lw  a0, 0(s0)
        u_top.u_axi_mem.mem[5]  = 32'h0004a583; // lw  a1, 0(s1)
        u_top.u_axi_mem.mem[6]  = 32'h02b50633; // mul a2, a0, a1
        u_top.u_axi_mem.mem[7]  = 32'h00c686b3; // add a3, a3, a2

        // MAC Iteration 1: Acc = 6 + (7 * -3) = -15
        u_top.u_axi_mem.mem[8]  = 32'h00442503; // lw  a0, 4(s0)
        u_top.u_axi_mem.mem[9]  = 32'h0044a583; // lw  a1, 4(s1)
        u_top.u_axi_mem.mem[10] = 32'h02b50633; // mul a2, a0, a1
        u_top.u_axi_mem.mem[11] = 32'h00c686b3; // add a3, a3, a2

        // MAC Iteration 2: Acc = -15 + (-4 * 6) = -39
        u_top.u_axi_mem.mem[12] = 32'h00842503; // lw  a0, 8(s0)
        u_top.u_axi_mem.mem[13] = 32'h0084a583; // lw  a1, 8(s1)
        u_top.u_axi_mem.mem[14] = 32'h02b50633; // mul a2, a0, a1
        u_top.u_axi_mem.mem[15] = 32'h00c686b3; // add a3, a3, a2

        // MAC Iteration 3: Acc = -39 + (5 * 4) = -19
        u_top.u_axi_mem.mem[16] = 32'h00c42503; // lw  a0, 12(s0)
        u_top.u_axi_mem.mem[17] = 32'h00c4a583; // lw  a1, 12(s1)
        u_top.u_axi_mem.mem[18] = 32'h02b50633; // mul a2, a0, a1
        u_top.u_axi_mem.mem[19] = 32'h00c686b3; // add a3, a3, a2

        // Store Final Accumulated Result back over AXI Bus
        u_top.u_axi_mem.mem[20] = 32'h00d92023; // sw a3, 0(s2) (Store to 0x120)

        // RV32M Division & Remainder Test
        u_top.u_axi_mem.mem[21] = 32'hfed00293; // addi t0, zero, -19
        u_top.u_axi_mem.mem[22] = 32'h00400313; // addi t1, zero, 4
        u_top.u_axi_mem.mem[23] = 32'h0262c3b3; // div  t2, t0, t1 (-19 / 4 = -4)
        u_top.u_axi_mem.mem[24] = 32'h0262ee33; // rem  t3, t0, t1 (-19 % 4 = -3)

        // ---------------------------------------------------------------------
        // imu_mac (custom-0) Tests -- packed INT8 dot product
        //   rd = sum_i signed(rs1.byte[i]) * signed(rs2.byte[i])
        // ---------------------------------------------------------------------
        u_top.u_axi_mem.mem[25] = 32'h00500713; // addi a4, zero, 5
        u_top.u_axi_mem.mem[26] = 32'h00300793; // addi a5, zero, 3
        u_top.u_axi_mem.mem[27] = 32'h00F7080B; // imu_mac a6, a4, a5   -> 5*3 = 15
        u_top.u_axi_mem.mem[28] = 32'h010809B3; // add s3, a6, a6       -> 30 (forwarding test)
        u_top.u_axi_mem.mem[29] = 32'hFFC00713; // addi a4, zero, -4
        u_top.u_axi_mem.mem[30] = 32'h00F7088B; // imu_mac x17, a4, a5  -> -4*3 = -12

        // Packed INT8 tests
        // x20 = 0x04030201 (w = 1,2,3,4)      x21 = 0x08070605 (a = 5,6,7,8)
        u_top.u_axi_mem.mem[31] = 32'h04030A37; // lui  x20, 0x04030
        u_top.u_axi_mem.mem[32] = 32'h201A0A13; // addi x20, x20, 0x201
        u_top.u_axi_mem.mem[33] = 32'h08070AB7; // lui  x21, 0x08070
        u_top.u_axi_mem.mem[34] = 32'h605A8A93; // addi x21, x21, 0x605
        // x22 = 0x04FD02FF (w = -1,2,-3,4)    x23 = 0xF807FA05 (a = 5,-6,7,-8)
        u_top.u_axi_mem.mem[35] = 32'h04FD0B37; // lui  x22, 0x04FD0
        u_top.u_axi_mem.mem[36] = 32'h2FFB0B13; // addi x22, x22, 0x2FF
        u_top.u_axi_mem.mem[37] = 32'hF8080BB7; // lui  x23, 0xF8080
        u_top.u_axi_mem.mem[38] = 32'hA05B8B93; // addi x23, x23, -1531 (0xA05)
        u_top.u_axi_mem.mem[39] = 32'h015A0C0B; // imu_mac x24, x20, x21 -> 5+12+21+32 = 70
        u_top.u_axi_mem.mem[40] = 32'h017B0C8B; // imu_mac x25, x22, x23 -> -5-12-21-32 = -70

        // Infinite loop (Halt condition) at word 41 -> PC = 0xA4
        u_top.u_axi_mem.mem[41] = 32'h0000006f; // jal zero, 0 (Loop forever)

        // ---------------------------------------------------------------------
        // Initialize Data Memory with Test Vectors
        // ---------------------------------------------------------------------
        // Vector X at word 64 (0x100) = [3, 7, -4, 5]
        u_top.u_axi_mem.mem[64] = 32'd3;
        u_top.u_axi_mem.mem[65] = 32'd7;
        u_top.u_axi_mem.mem[66] = -32'd4;
        u_top.u_axi_mem.mem[67] = 32'd5;

        // Vector W at word 68 (0x110) = [2, -3, 6, 4]
        u_top.u_axi_mem.mem[68] = 32'd2;
        u_top.u_axi_mem.mem[69] = -32'd3;
        u_top.u_axi_mem.mem[70] = 32'd6;
        u_top.u_axi_mem.mem[71] = 32'd4;

        // Result location at word 72 (0x120) initialized to 0
        u_top.u_axi_mem.mem[72] = 32'd0;

        // Apply Reset
        #20;
        rst_n = 1'b1;
        $display("[%0t ns] Reset released. Processor running...", $time);

        // Wait until core reaches the halt loop at PC = 0xA4 or timeout
        fork
            begin
                wait (u_top.u_core.pc_reg == 32'h000000A4);
                // Allow final instructions in pipeline (including 32-cycle divider) to retire
                repeat (80) @(posedge clk);
            end
            begin
                #20000; // 20 us timeout
                $display("\n[ERROR] Simulation timed out!");
                $finish;
            end
        join_any

        // ---------------------------------------------------------------------
        // Self-Checking Verification
        // ---------------------------------------------------------------------
        $display("\n==================================================================");
        $display("                   SIMULATION RESULTS & VERIFICATION");
        $display("==================================================================");
        $display(" Total Clock Cycles Executed : %0d", cycle_count);
        $display(" Total AXI Memory Reads      : %0d", mem_read_count);
        $display(" Total AXI Memory Writes     : %0d", mem_write_count);

        // Expected values
        expected_acc      = -19;
        expected_div      = -4;
        expected_rem      = -3;
        expected_cim1     = 15;   // 5 * 3
        expected_cim_dep  = 30;   // 15 + 15 (forwarded from imu_mac)
        expected_cim_neg  = -12;  // -4 * 3
        expected_cim_pk   = 70;   // 1*5 + 2*6 + 3*7 + 4*8
        expected_cim_pks  = -70;  // -1*5 + 2*-6 + -3*7 + 4*-8

        // Actual values
        actual_mem_acc = u_top.u_axi_mem.mem[72];
        actual_reg_acc = u_top.u_core.u_reg_file.regs[13]; // a3
        actual_reg_div = u_top.u_core.u_reg_file.regs[7];  // t2
        actual_reg_rem = u_top.u_core.u_reg_file.regs[28]; // t3
        actual_cim1    = u_top.u_core.u_reg_file.regs[16]; // a6
        actual_cim_dep = u_top.u_core.u_reg_file.regs[19]; // s3
        actual_cim_neg = u_top.u_core.u_reg_file.regs[17]; // x17
        actual_cim_pk  = u_top.u_core.u_reg_file.regs[24]; // x24
        actual_cim_pks = u_top.u_core.u_reg_file.regs[25]; // x25

        $display(" ------------------------------------------------------------------");
        $display(" MAC Stored in Memory [0x120] : %0d (Expected: %0d)", actual_mem_acc, expected_acc);
        $display(" MAC Accumulator Reg (a3)     : %0d (Expected: %0d)", actual_reg_acc, expected_acc);
        $display(" Division Result Reg (t2)     : %0d (Expected: %0d)", actual_reg_div, expected_div);
        $display(" Remainder Result Reg (t3)    : %0d (Expected: %0d)", actual_reg_rem, expected_rem);
        $display(" ------------------------------------------------------------------");
        $display(" imu_mac  a6  = 5 * 3         : %0d (Expected: %0d)", actual_cim1,    expected_cim1);
        $display(" imu_mac dependency (s3)      : %0d (Expected: %0d)", actual_cim_dep, expected_cim_dep);
        $display(" imu_mac  x17 = -4 * 3        : %0d (Expected: %0d)", actual_cim_neg, expected_cim_neg);
        $display(" imu_mac packed int8 (x24)    : %0d (Expected: %0d)", actual_cim_pk,  expected_cim_pk);
        $display(" imu_mac packed signed (x25)  : %0d (Expected: %0d)", actual_cim_pks, expected_cim_pks);
        $display(" ------------------------------------------------------------------");

        if ((actual_mem_acc == expected_acc) &&
            (actual_reg_acc == expected_acc) &&
            (actual_reg_div == expected_div) &&
            (actual_reg_rem == expected_rem)) begin
            $display(" [PASS] Baseline MAC + RV32M checks");
        end else begin
            $display(" [FAIL] Baseline MAC + RV32M checks");
        end

        if ((actual_cim1    == expected_cim1)    &&
            (actual_cim_dep == expected_cim_dep) &&
            (actual_cim_neg == expected_cim_neg) &&
            (actual_cim_pk  == expected_cim_pk)  &&
            (actual_cim_pks == expected_cim_pks)) begin
            $display(" [PASS] imu_mac instruction verified (basic, forwarding, signed, packed int8)");
        end else begin
            $display(" [FAIL] imu_mac instruction MISMATCH");
        end

        $display("==================================================================");
        #100;
        $finish;
    end

endmodule