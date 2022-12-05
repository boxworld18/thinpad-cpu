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

// CSR M-MODE
`define CSR_MTVEC 12'h305 // CSR mtvec地址
`define CSR_MSCRATCH 12'h340 // CSR mscratch地址
`define CSR_MEPC 12'h341 // CSR mepc地址
`define CSR_MCAUSE 12'h342 // CSR mcause地址
`define CSR_MSTATUS 12'h300 // CSR mstatus地址
`define CSR_MIE 12'h304 // CSR mie地址
`define CSR_MIP 12'h344 // CSR mip地址
`define CSR_MTVAL 12'h343 // CSR mtval地址
`define CSR_MIDELEG 12'h303 // CSR mideleg地址
`define CSR_MEDELEG 12'h302 // CSR medeleg地址
`define CSR_MHARTID 12'hf14 // CSR mhartid地址

// CSR S-MODE
`define CSR_STVEC 12'h105 // CSR stvec地址
`define CSR_SSCRATCH 12'h140 // CSR sscratch地址
`define CSR_SEPC 12'h141 // CSR sepc地址
`define CSR_SCAUSE 12'h142 // CSR scause地址
`define CSR_SSTATUS 12'h100 // CSR sstatus地址
`define CSR_SIE 12'h104 // CSR sie地址
`define CSR_SIP 12'h144 // CSR sip地址
`define CSR_STVAL 12'h143 // CSR stval地址
`define CSR_SATP 12'h180 // CSR satp地址

`define CSR_PMPCFG0 12'h3a0 // CSR pmpcfg0地址
`define CSR_PMPADDR0 12'h3b0 // CSR pmpaddr0地址

`define CSR_RDTIME 12'hC01 // CSR rdtime地址
`define CSR_RDTIMEH 12'hC81 // CSR rdtimeh地址

`define CSR_ECALL 12'h000 // CSR ecall
`define CSR_EBREAK 12'h001 // CSR ebreak
`define CSR_MRET 12'h302 // CSR mret
`define CSR_SRET 12'h102 // CSR sret

`define CSR_NUM 7 // CSR数量
`define CSR_SEL_BUS `CSR_NUM-1:0 // CSR选择信号宽度
`define CSR_TOTAL_DATA_BUS ((`CSR_NUM)*(`CSR_DATA_WIDTH))-1:0 // CSR总数据线宽度

`define MHARTID_HARTID 31:0 // mhartid hartid位宽度

`define TVEC_BASE 31:2 // m/s tvec base位宽度
`define TVEC_MODE 1:0 // m/s tvec mode位宽度

`define CAUSE_INTERRUPT 31 // m/s cause interrupt位宽度
`define CAUSE_EXCEPTION_CODE 30:0 // m/s cause exception code位宽度

`define SATP_PPN 21:0 // satp ppn位
`define SATP_MODE 31 // satp mode位
`define SATP_ASID 30:22 // satp asid位

`define VA_VPN1 31:22 // va vpn1位
`define VA_VPN0 21:12 // va vpn0位
`define VA_OFFSET 11:0 // va offset位

`define PTE_V 0 // pte v位
`define PTE_R 1 // pte r位
`define PTE_W 2 // pte w位
`define PTE_X 3 // pte x位
`define PTE_U 4 // pte u位
`define PTE_G 5 // pte g位
`define PTE_A 6 // pte a位
`define PTE_D 7 // pte d位
`define PTE_RSW 9:8 // pte rsw位
`define PTE_PPN0 19:10 // pte ppn0位
`define PTE_PPN1 31:20 // pte ppn1位
`define PTE_PPN 31:10 // pte ppn位

`define PAGE_SIZE 12 // 页大小
`define LEVELS 2 // 页表层数
`define PTE_SIZE 4 // PTE大小

`define INTERRUPT 1'b1
`define EXCEPTION 1'b0

// `define EXCEPTION_CODE_U_TIME_INTERRUPT 4 // not support
`define EXCEPTION_CODE_S_TIME_INTERRUPT 5 
`define EXCEPTION_CODE_M_TIME_INTERRUPT 7  
`define EXCEPTION_CODE_BREAKPOINT 3
`define EXCEPTION_CODE_ECALL_U_MODE 8
`define EXCEPTION_CODE_ECALL_S_MODE 9
`define EXCEPTION_CODE_ECALL_M_MODE 11
`define EXCEPTION_CODE_INST_PAGE_FAULT 12
`define EXCEPTION_CODE_LOAD_PAGE_FAULT 13
`define EXCEPTION_CODE_STORE_AMO_PAGE_FAULT 15

`define MSTATUS_SUM 18
`define MSTATUS_MPP 12:11 
`define MSTATUS_SPP 8
`define MSTATUS_MPIE 7
`define MSTATUS_SPIE 5
// `define MSTATUS_UPIE 4
`define MSTATUS_MIE 3
`define MSTATUS_SIE 1
// `define MSTATUS_UIE 0

`define SSTATUS_SUM 18
`define SSTATUS_SPP 8
`define SSTATUS_SPIE 5
// `define SSTATUS_UPIE 4
`define SSTATUS_SIE 1
// `define SSTATUS_UIE 0
`define SSTATUS_MASK 32'h00040133

// `define MIP_MEIP 11
// `define MIP_SEIP 9
// `define MIP_UEIP 8
`define MIP_MTIP 7
`define MIP_STIP 5
// `define MIP_UTIP 4
// `define MIP_MSIP 3
// `define MIP_SSIP 1
// `define MIP_USIP 0

// `define MIE_MEIE 11
// `define MIE_SEIE 9
// `define MIE_UEIE 8
`define MIE_MTIE 7 
`define MIE_STIE 5
// `define MIE_UTIE 4
// `define MIE_MSIE 3
// `define MIE_SSIE 1
// `define MIE_USIE 0

// `define SIP_SEIP 9
// `define SIP_UEIP 8
`define SIP_STIP 5
// `define SIP_UTIP 4
// `define SIP_SSIP 1
// `define SIP_USIP 0
`define SIP_MASK 32'h00000333 

// `define SIE_SEIE 9
// `define SIE_UEIE 8
`define SIE_STIE 5
// `define SIE_UTIE 4
// `define SIE_SSIE 1
// `define SIE_USIE 0
`define SIE_MASK 32'h00000333

// time interrupt
`define MTIME_ADDR_LOW 32'h200BFF8
`define MTIME_ADDR_HIGH 32'h200BFFC
`define MTIMECMP_ADDR_LOW 32'h2004000
`define MTIMECMP_ADDR_HIGH 32'h2004004 

`define CSR_SEL_WIDTH 4 // CSR选择信号宽度
typedef enum logic [3:0] {
    CSR_INST_NOP = 0,
    CSRRW = 1,
    CSRRS = 2,
    CSRRC = 3,
    CSRRWI = 4,
    CSRRSI = 5,
    CSRRCI = 6,
    ECALL = 7,
    EBREAK = 8,
    MRET = 9,
    SRET = 10,
    INST_PAGE_FAULT = 11,
    LOAD_PAGE_FAULT = 12,
    STORE_PAGE_FAULT = 13,
    M_TIME_INTERRUPT = 14,
    S_TIME_INTERRUPT = 15
} csr_inst_t;

typedef enum logic [1:0] {
    U_MODE = 2'b00,
    S_MODE = 2'b01,
    M_MODE = 2'b11
} mode_t;

typedef enum  logic [1:0] {
    MODE_DIRECT = 2'b00,
    MODE_VECTORED = 2'b01,
    MODE_RESERVED = 2'b10
} tvec_mode_t;

`endif