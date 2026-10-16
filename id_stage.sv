// =============================================================================
// File: id_stage.sv
// Description: Instruction Decode (ID) Stage, Immediate Gen & Control Unit
// =============================================================================

import riscv_pkg::*;

module id_stage (
    // From IF/ID Register
    input  if_id_reg_t  if_id_q,

    // Register File Interface
    output logic [4:0]  rs1_addr,
    output logic [4:0]  rs2_addr,
    input  logic [31:0] rf_rdata1,
    input  logic [31:0] rf_rdata2,

    // Output to ID/EX Register
    output id_ex_reg_t  id_ex_d
);

    logic [31:0] decoded_imm;
    opcode_e     opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [4:0]  rd_addr;

    assign opcode   = opcode_e'(if_id_q.instr[6:0]);
    assign rd_addr  = if_id_q.instr[11:7];
    assign funct3   = if_id_q.instr[14:12];
    assign rs1_addr = if_id_q.instr[19:15];
    assign rs2_addr = if_id_q.instr[24:20];
    assign funct7   = if_id_q.instr[31:25];

    // Immediate Generator Instance
    imm_gen u_imm_gen (
        .instr(if_id_q.instr),
        .imm(decoded_imm)
    );

    // Control Unit Decoder
    always_comb begin
        id_ex_d.pc          = if_id_q.pc;
        id_ex_d.rs1_data    = rf_rdata1;
        id_ex_d.rs2_data    = rf_rdata2;
        id_ex_d.imm         = decoded_imm;
        id_ex_d.rs1_addr    = rs1_addr;
        id_ex_d.rs2_addr    = rs2_addr;
        id_ex_d.rd_addr     = rd_addr;
        id_ex_d.valid       = if_id_q.valid;

        // Default Control Signals
        id_ex_d.alu_op      = ALU_ADD;
        id_ex_d.alu_src_a   = 1'b0; // 0: rs1, 1: pc
        id_ex_d.alu_src_b   = 1'b0; // 0: rs2, 1: imm
        id_ex_d.is_branch   = 1'b0;
        id_ex_d.branch_type = branch_op_e'(funct3);
        id_ex_d.is_jal      = 1'b0;
        id_ex_d.is_jalr     = 1'b0;
        id_ex_d.mem_read    = 1'b0;
        id_ex_d.mem_write   = 1'b0;
        id_ex_d.mem_format  = mem_format_e'(funct3);
        id_ex_d.reg_write   = 1'b0;
        id_ex_d.wb_sel      = WB_ALU;
        id_ex_d.is_m_ext    = 1'b0;
        id_ex_d.m_op        = m_op_e'(funct3);
        id_ex_d.is_cim      = 1'b0;

        case (opcode)
            OP_OP: begin
                id_ex_d.reg_write = 1'b1;
                id_ex_d.alu_src_b = 1'b0; // rs2
                if (funct7 == 7'b0000001) begin
                    // RV32M Extension
                    id_ex_d.is_m_ext = 1'b1;
                    id_ex_d.wb_sel   = WB_MD;
                end else begin
                    // Standard RV32I R-Type
                    case (funct3)
                        3'b000: id_ex_d.alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: id_ex_d.alu_op = ALU_SLL;
                        3'b010: id_ex_d.alu_op = ALU_SLT;
                        3'b011: id_ex_d.alu_op = ALU_SLTU;
                        3'b100: id_ex_d.alu_op = ALU_XOR;
                        3'b101: id_ex_d.alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                        3'b110: id_ex_d.alu_op = ALU_OR;
                        3'b111: id_ex_d.alu_op = ALU_AND;
                    endcase
                end
            end

            OP_OP_IMM: begin
                id_ex_d.reg_write = 1'b1;
                id_ex_d.alu_src_b = 1'b1; // imm
                case (funct3)
                    3'b000: id_ex_d.alu_op = ALU_ADD;
                    3'b001: id_ex_d.alu_op = ALU_SLL;
                    3'b010: id_ex_d.alu_op = ALU_SLT;
                    3'b011: id_ex_d.alu_op = ALU_SLTU;
                    3'b100: id_ex_d.alu_op = ALU_XOR;
                    3'b101: id_ex_d.alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: id_ex_d.alu_op = ALU_OR;
                    3'b111: id_ex_d.alu_op = ALU_AND;
                endcase
            end

            OP_LUI: begin
                id_ex_d.reg_write = 1'b1;
                id_ex_d.alu_op    = ALU_PASS_B;
                id_ex_d.alu_src_b = 1'b1; // imm
            end

            OP_AUIPC: begin
                id_ex_d.reg_write = 1'b1;
                id_ex_d.alu_op    = ALU_ADD;
                id_ex_d.alu_src_a = 1'b1; // pc
                id_ex_d.alu_src_b = 1'b1; // imm
            end

            OP_LOAD: begin
                id_ex_d.reg_write = 1'b1;
                id_ex_d.mem_read  = 1'b1;
                id_ex_d.alu_op    = ALU_ADD;
                id_ex_d.alu_src_b = 1'b1; // imm
                id_ex_d.wb_sel    = WB_MEM;
            end

            OP_STORE: begin
                id_ex_d.mem_write = 1'b1;
                id_ex_d.alu_op    = ALU_ADD;
                id_ex_d.alu_src_b = 1'b1; // imm
            end

            OP_BRANCH: begin
                id_ex_d.is_branch = 1'b1;
            end

            OP_JAL: begin
                id_ex_d.is_jal    = 1'b1;
                id_ex_d.reg_write = 1'b1;
                id_ex_d.wb_sel    = WB_PC4;
            end

            OP_JALR: begin
                id_ex_d.is_jalr   = 1'b1;
                id_ex_d.reg_write = 1'b1;
                id_ex_d.wb_sel    = WB_PC4;
            end

            // imu_mac rd, rs1, rs2  (custom-0, funct3=000, funct7=0000000)
            OP_CUSTOM_0: begin
                if (funct3 == 3'b000 && funct7 == 7'b0000000) begin
                    id_ex_d.reg_write = 1'b1;
                    id_ex_d.alu_src_b = 1'b0;   // operands come from rs1/rs2
                    id_ex_d.is_cim    = 1'b1;
                    id_ex_d.wb_sel    = WB_CIM;
                end
            end

            default: ;
        endcase
    end

endmodule