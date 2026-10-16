// =============================================================================
// File: riscv_pkg.sv
// Description: Global definitions for RV32IM 5-Stage Pipelined Processor
//              with AMBA AXI4-Lite Bus Interface
//              + Custom-0 imu_mac (CIM) instruction support
// =============================================================================

package riscv_pkg;

    // -------------------------------------------------------------------------
    // RV32 Base Opcodes (opcode[6:0])
    // -------------------------------------------------------------------------
    typedef enum logic [6:0] {
        OP_LUI      = 7'b0110111,
        OP_AUIPC    = 7'b0010111,
        OP_JAL      = 7'b1101111,
        OP_JALR     = 7'b1100111,
        OP_BRANCH   = 7'b1100011,
        OP_LOAD     = 7'b0000011,
        OP_STORE    = 7'b0100011,
        OP_OP_IMM   = 7'b0010011,
        OP_OP       = 7'b0110011, // R-type: Arithmetic, Logic & RV32M
        OP_SYSTEM   = 7'b1110011,
        OP_CUSTOM_0 = 7'b0001011  // Custom-0: imu_mac
    } opcode_e;

    // -------------------------------------------------------------------------
    // ALU Operations
    // -------------------------------------------------------------------------
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_SLL  = 4'b0010,
        ALU_SLT  = 4'b0011,
        ALU_SLTU = 4'b0100,
        ALU_XOR  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_OR   = 4'b1000,
        ALU_AND  = 4'b1001,
        ALU_PASS_B = 4'b1010
    } alu_op_e;

    // -------------------------------------------------------------------------
    // RV32M Multiplier / Divider Operations (funct3 when opcode == OP_OP & funct7 == 7'b0000001)
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        M_OP_MUL    = 3'b000,
        M_OP_MULH   = 3'b001,
        M_OP_MULHSU = 3'b010,
        M_OP_MULHU  = 3'b011,
        M_OP_DIV    = 3'b100,
        M_OP_DIVU   = 3'b101,
        M_OP_REM    = 3'b110,
        M_OP_REMU   = 3'b111
    } m_op_e;

    // -------------------------------------------------------------------------
    // Branch Conditions (funct3 when opcode == OP_BRANCH)
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        BR_BEQ  = 3'b000,
        BR_BNE  = 3'b001,
        BR_BLT  = 3'b100,
        BR_BGE  = 3'b101,
        BR_BLTU = 3'b110,
        BR_BGEU = 3'b111
    } branch_op_e;

    // -------------------------------------------------------------------------
    // Load / Store Formats (funct3 for OP_LOAD / OP_STORE)
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        MEM_BYTE  = 3'b000, // LB / SB
        MEM_HALF  = 3'b001, // LH / SH
        MEM_WORD  = 3'b010, // LW / SW
        MEM_BYTEU = 3'b100, // LBU
        MEM_HALFU = 3'b101  // LHU
    } mem_format_e;

    // -------------------------------------------------------------------------
    // Writeback Source Multiplexer Selection
    // (widened to 3 bits to fit WB_CIM; existing values unchanged)
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        WB_ALU  = 3'b000,
        WB_MEM  = 3'b001,
        WB_PC4  = 3'b010,
        WB_MD   = 3'b011, // Multiplier / Divider result
        WB_CIM  = 3'b100  // imu_mac (CIM) result
    } wb_sel_e;

    // -------------------------------------------------------------------------
    // Pipeline Register Structs (Between Stages)
    // -------------------------------------------------------------------------
    
    // IF to ID Stage
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] instr;
        logic        valid;
    } if_id_reg_t;

    // ID to EX Stage
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] rs1_data;
        logic [31:0] rs2_data;
        logic [31:0] imm;
        logic [4:0]  rs1_addr;
        logic [4:0]  rs2_addr;
        logic [4:0]  rd_addr;
        alu_op_e     alu_op;
        logic        alu_src_b;     // 0: rs2, 1: imm
        logic        alu_src_a;     // 0: rs1, 1: pc (AUIPC)
        logic        is_branch;
        branch_op_e  branch_type;
        logic        is_jal;
        logic        is_jalr;
        logic        mem_read;
        logic        mem_write;
        mem_format_e mem_format;
        logic        reg_write;
        wb_sel_e     wb_sel;
        logic        is_m_ext;      // RV32M operation
        m_op_e       m_op;
        logic        is_cim;        // imu_mac instruction
        logic        valid;
    } id_ex_reg_t;

    // EX to MEM Stage
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] alu_result;
        logic [31:0] md_result;
        logic [31:0] cim_result;    // imu_mac result
        logic [31:0] rs2_data;      // Write data for store
        logic [4:0]  rd_addr;
        logic        mem_read;
        logic        mem_write;
        mem_format_e mem_format;
        logic        reg_write;
        wb_sel_e     wb_sel;
        logic        is_cim;
        logic        valid;
    } ex_mem_reg_t;

    // MEM to WB Stage
    typedef struct packed {
        logic [31:0] pc;
        logic [31:0] alu_result;
        logic [31:0] md_result;
        logic [31:0] cim_result;    // imu_mac result
        logic [31:0] mem_rdata;
        logic [4:0]  rd_addr;
        logic        reg_write;
        wb_sel_e     wb_sel;
        logic        is_cim;
        logic        valid;
    } mem_wb_reg_t;

    // -------------------------------------------------------------------------
    // Forwarding Control Enums
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        FWD_NONE = 2'b00,
        FWD_EX   = 2'b01, // Forward from EX/MEM
        FWD_MEM  = 2'b10  // Forward from MEM/WB
    } fwd_sel_e;

endpackage: riscv_pkg