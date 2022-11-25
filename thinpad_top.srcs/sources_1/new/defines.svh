`ifndef _DEFINES_SVH_
`define _DEFINES_SVH_

// general
`define ZERO_WORD 32'h0000_0000
`define INST_NOP 32'h0000_0013 
`define ENABLE 1 // 使能
`define DISABLE 0 

// PC
`define PC_RESET 32'h8000_0000 // PC复位值

// WIDTH
`define ADDR_WIDTH 32 // 地址宽度
`define DATA_WIDTH 32 // 数据宽度
`define INST_WIDTH 32 // 指令宽度
`define ADDR_BUS `ADDR_WIDTH-1:0 // 地址总线宽度
`define DATA_BUS `DATA_WIDTH-1:0 // 数据总线宽度
`define INST_BUS `INST_WIDTH-1:0 // 指令总线宽度
`define SEL `DATA_WIDTH/8-1:0 // 选择信号宽度

// Regfile
`define REG_DATA_WIDTH 32 // 寄存器数据宽度
`define REG_DATA_BUS `REG_DATA_WIDTH-1:0 // 寄存器数据线宽度
`define REG_NUM 32 // 寄存器数量
`define REG_ADDR_BUS `REG_NUM/8:0 // 寄存器地址线宽度

// SRAM
`define SRAM_ADDR_WIDTH 20 // SRAM地址宽度
`define SRAM_DATA_WIDTH 32 // SRAM数据宽度
`define SRAM_BYTES `SRAM_DATA_WIDTH/8 // SRAM字节数
`define SRAM_ADDR_BUS `SRAM_ADDR_WIDTH-1:0 // SRAM地址线宽度
`define SRAM_DATA_BUS `SRAM_DATA_WIDTH-1:0 // SRAM数据线宽度
`define SRAM_SEL `SRAM_DATA_WIDTH/8-1:0 // SRAM选择信号宽度

// Instruction Decode

`define OPCODE_WIDTH 7 // 操作码宽度
`define FUNC3_WIDTH 3 // FUNC3宽度
`define FUNC7_WIDTH 7 // FUNC7宽度
`define OPCODE_R 7'b0110011 // R-type add sub sll srl sra and or xor slt sltu       REG OP REG  
`define OPCODE_I 7'b0010011 // I-type addi slli srli srai andi ori xori slti sltiu  REG OP IMM 
`define OPCODE_S 7'b0100011 // S-type sb sh sw                           REG + IMM
`define OPCODE_SB 7'b1100011 // SB-type beq bne blt bge bltu bgeu        PC + IMM   
`define OPCODE_LUI 7'b0110111 // U-type lui                                     IMM
`define OPCODE_JAL 7'b1101111 // UJ-type jal                             PC + IMM
`define OPCODE_L 7'b0000011 // load lb lh lw lbu lhu                     REG + IMM   
`define OPCODE_AUIPC 7'b0010111 // auipc                                 PC + IMM   
`define OPCODE_JALR 7'b1100111 // jalr                                   REG + IMM
`define OPCODE_NOP 7'b0000000 // nop                                     REG + REG
`define OPCODE_PRIV 7'b1110011 // CSRRC CSRRS CSRRW EBREAK ECALL MRET

// ALU OP
`define ALU_OP_WIDTH 5 // ALU操作码宽度 TBD
typedef enum logic [4:0] {
    ALU_OP_NOP = 5'd0,
    ALU_OP_ADD = 5'd1,
    ALU_OP_SUB = 5'd2,
    ALU_OP_AND = 5'd3,
    ALU_OP_OR  = 5'd4,
    ALU_OP_XOR = 5'd5,
    ALU_OP_SLL = 5'd6,
    ALU_OP_SRL = 5'd7,
    ALU_OP_SRA = 5'd8,
    ALU_OP_B   = 5'd9, // 直接选data_b
    ALU_OP_SLT = 5'd10,
    ALU_OP_SLTU = 5'd11,
    ALU_OP_ADD_4 = 5'd12,
    ALU_OP_ANDN = 5'd13,
    ALU_OP_SBCLR = 5'd14,
    ALU_OP_CTZ = 5'd15,
    ALU_OP_A = 5'd16 // 直接选data_a
} alu_op_t;

// ALU Select
`define ALU_SEL_WIDTH 2 // ALU选择信号宽度
typedef enum logic [1:0] {
    ALU_SEL_REG_B = 2'b00, // ALU选择信号：寄存器
    ALU_SEL_IMM = 2'b01, // ALU选择信号：立即数
    ALU_SEL_4 = 2'b10 // ALU选择信号：4
} alu_sel_imm_t;

typedef enum logic {
    ALU_SEL_REG_A = 1'b0, // ALU选择信号：寄存器
    ALU_SEL_PC = 1'b1 // ALU选择信号：PC
} alu_sel_pc_t;

typedef enum logic [1:0] {
    ALU_SEL_NOP = 2'b00,
    ALU_SEL_EX = 2'b01,
    ALU_SEL_MEM = 2'b10,
    ALU_SEL_WB   = 2'b11
} alu_sel_t;

// CSR
`define CSR_ADDR_WIDTH 12 // CSR地址宽度
`define CSR_DATA_WIDTH 32 // CSR数据宽度
`define CSR_ADDR_BUS `CSR_ADDR_WIDTH-1:0 // CSR地址线宽度 11:0
`define CSR_DATA_BUS `CSR_DATA_WIDTH-1:0 // CSR数据线宽度 31:0
`define CSR_MTVEC 12'h305 // CSR mtvec地址
`define CSR_MSCRATCH 12'h340 // CSR mscratch地址
`define CSR_MEPC 12'h341 // CSR mepc地址
`define CSR_MCAUSE 12'h342 // CSR mcause地址
`define CSR_MSTATUS 12'h300 // CSR mstatus地址
`define CSR_MIE 12'h304 // CSR mie地址
`define CSR_MIP 12'h344 // CSR mip地址

`define CSR_ECALL 12'h000 // CSR ecall地址
`define CSR_EBREAK 12'h001 // CSR ebreak地址
`define CSR_MRET 12'h302 // CSR mret地址

`define CSR_NUM 7 // CSR数量
`define CSR_SEL_BUS `CSR_NUM-1:0 // CSR选择信号宽度
`define CSR_TOTAL_DATA_BUS ((`CSR_NUM)*(`CSR_DATA_WIDTH))-1:0 // CSR总数据线宽度

typedef struct packed
{
    logic mtvec;
    logic mepc;  
    logic mcause;
    logic mstatus;
    logic mscratch; 
    logic mie;
    logic mip;
} csr_en;

typedef struct packed
{
    logic [`CSR_DATA_BUS] mtvec;        // BASE(31:2) MODE(1:0)
    logic [`CSR_DATA_BUS] mepc;
    logic [`CSR_DATA_BUS] mcause;       // Interrupt (31) Exception Code(30:0)
    logic [`CSR_DATA_BUS] mstatus;      // MPP(12:11) SPP(8) MPIE(7) SPIE(5) UPIE(4) MIE(3) SIE(1) UIE(0)
    logic [`CSR_DATA_BUS] mscratch;
    logic [`CSR_DATA_BUS] mie;
    logic [`CSR_DATA_BUS] mip;
} csr_data;

typedef enum logic [2:0] {
    CSR_INST_NOP = 0,
    CSRRW = 1,
    CSRRS = 2,
    CSRRC = 3,
    ECALL = 4,
    EBREAK = 5,
    MRET = 6
} csr_inst_t;

`endif