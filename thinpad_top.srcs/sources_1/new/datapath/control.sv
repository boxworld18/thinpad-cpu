`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module control(
    input wire [`ADDR_BUS] pc,
    input wire [`INST_BUS] inst,
    input wire [1:0] mode,

    // regfile
    output reg id_rf_wen,
    output reg id_rf_sel,
    // wishbone
    output wire id_wb_wen,
    output wire id_wb_ren,
    output reg [`SEL] id_wb_sel,
    output reg id_wb_read_unsigned,
    // alu
    output reg [`ALU_OP_WIDTH-1:0] id_alu_op,
    output reg id_alu_sel_imm,
    output reg id_alu_sel_pc,
    output reg id_sel_csr,
    // csr
    output reg [`CSR_SEL_WIDTH-1:0] id_csr_inst_sel, // csr instruction type
    output reg [`CSR_ADDR_BUS] id_csr_raddr,
    output reg id_csr_imm_sel
);

    // 提取指令字段
    logic [6:0] func7;
    logic [2:0] func3;
    logic [6:0] opcode;
    logic [4:0] rs2;
    logic [4:0] rs1;
    logic [4:0] rd;
    logic [`CSR_ADDR_BUS] csr_addr;
    assign func7 = inst[31:25];
    assign func3 = inst[14:12];
    assign opcode = inst[6:0];
    assign rs2 = inst[24:20];
    assign rs1 = inst[19:15];
    assign rd = inst[11:7];
    assign csr_addr = inst[31:20];

    // 判断指令类型, 设置选择信号
    /*
        R:     add rd, rs1, rs2   ---  x[rd] = rs1 op rs2                        --- add, sub, and, or, xor, sll, srl, sra, slt, sltu
        I:     addi rd, rs1, imm  ---  x[rd] = rs1 op imm                        --- addi, andi, ori, xori, slli, srli, srai, slti, sltiu
        L:     lw rd, imm(rs1)    ---  x[rd] = mem[rs1 + imm]                    --- lb lw  还差 lbu lh lhu
        S:     sw rs2, imm(rs1)   ---  mem[rs2] = rs1 + imm                      --- sb sh sw
        SB:    beq rs1, rs2, imm  ---  pc = pc + imm                             --- beq bne blt bge bltu bgeu
        LUI:   lui rd, imm        ---  x[rd] = imm                               --- lui
        AUIPC: auipc rd, imm      ---  x[rd] = pc + imm                          --- auipc   
        JAL:   jal rd, imm        ---  x[rd] = pc + 4; pc = pc + imm             --- jal   
        JALR:  jalr rd, imm(rs1)  ---  x[rd] = pc + 4; pc = (x[rs1] + imm) & ~1; --- jalr
        PRIV:  CSRRW rd, csr, zimm[4:0](rs1) --- x[rd] = CSRs[csr], CSRs[csr] = x[rs1];  --- CSRRW, CSRRS, CSRRC
     */

    logic is_r, is_i, is_l, is_s, is_sb, is_lui, is_auipc, is_jal, is_jalr, is_priv;; 
    assign is_r = (opcode == `OPCODE_R);
    assign is_i = (opcode == `OPCODE_I);
    assign is_l = (opcode == `OPCODE_L);
    assign is_s = (opcode == `OPCODE_S);
    assign is_sb = (opcode == `OPCODE_SB);
    assign is_lui = (opcode == `OPCODE_LUI);
    assign is_auipc = (opcode == `OPCODE_AUIPC);
    assign is_jal = (opcode == `OPCODE_JAL);
    assign is_jalr = (opcode == `OPCODE_JALR);
    assign is_priv = (opcode == `OPCODE_PRIV);
    assign id_sel_csr = is_priv;

    // alu
    assign id_alu_sel_pc = (is_auipc || is_jal || is_jalr) ? ALU_SEL_PC : ALU_SEL_REG_A;
    assign id_alu_sel_imm = (is_r || is_priv) ? ALU_SEL_REG_B : ALU_SEL_IMM;

    // rf
    assign id_rf_sel = (is_l); // lw 读取 mem, 其他读取 alu_result
    assign id_rf_wen = ((is_s) || (is_sb)) ? `DISABLE : `ENABLE;

    // wishbone
    assign id_wb_wen = (is_s);
    assign id_wb_ren = (is_l);
    
    always_comb begin // 不代表最终的使能, 只确定字节数, 写入wishbone之前应左移 addr 的低2位
        case (func3)
            3'b000: begin id_wb_sel = 4'b0001; id_wb_read_unsigned = 1'b0; end // lb
            3'b001: begin id_wb_sel = 4'b0011; id_wb_read_unsigned = 1'b0; end // lh
            3'b010: begin id_wb_sel = 4'b1111; id_wb_read_unsigned = 1'b0; end // lw
            3'b100: begin id_wb_sel = 4'b0001; id_wb_read_unsigned = 1'b1; end // lbu
            3'b101: begin id_wb_sel = 4'b0011; id_wb_read_unsigned = 1'b1; end // lhu    
            default: begin id_wb_sel = 4'b0000; id_wb_read_unsigned = 1'b0; end
        endcase
    end

    // alu
    always_comb begin
        if (is_r || is_i) begin
            case (func3)
                3'b000: begin
                    if (is_r && func7 == 7'b0100000)
                        id_alu_op = ALU_OP_SUB;
                    else
                        id_alu_op = ALU_OP_ADD;
                end
                3'b001: begin
                    if (func7 == 7'b0100100)
                        id_alu_op = ALU_OP_SBCLR;
                    else if (func7 == 7'b0110000 && rs2 == 5'b00001)
                        id_alu_op = ALU_OP_CTZ;
                    else
                        id_alu_op = ALU_OP_SLL;
                end
                3'b010: id_alu_op = ALU_OP_SLT;
                3'b011: id_alu_op = ALU_OP_SLTU;
                3'b100: id_alu_op = ALU_OP_XOR;
                3'b101: begin
                    if (func7 == 7'b0100000)
                        id_alu_op = ALU_OP_SRA;
                    else
                        id_alu_op = ALU_OP_SRL;
                end
                3'b110: id_alu_op = ALU_OP_OR;
                3'b111: begin
                    if (func7 == 7'b0100000)
                        id_alu_op = ALU_OP_ANDN;
                    else
                        id_alu_op = ALU_OP_AND;
                end
                default: id_alu_op = ALU_OP_NOP;
            endcase
        end else if (is_lui || is_priv) begin // lui: choose imm directly
            id_alu_op = ALU_OP_B;
        end else if (is_jal || is_jalr) begin
            id_alu_op = ALU_OP_ADD_4;
        end else begin
            id_alu_op = ALU_OP_ADD;
        end
    end

    // CSR (Control and Status Registers)

    // logic csrrw_c_s, csr_ren_global, csr_wen_global;
    // csr_en csr_ren_reg, csr_wen_reg;
    // assign id_csr_ren = csr_ren_reg;
    // assign id_csr_wen = csr_wen_reg;
    // assign csrrw_c_s = (is_priv && (func3[2] == 1'b0 && func3[1:0] != 2'b00));
    // assign csr_ren_global = csrrw_c_s && (rd != 0 || func3 != 3'b001);
    // assign csr_wen_global = csrrw_c_s && (rs1 != 0 || func3 == 3'b001);

    /* 
        Attention Please ! ! ! 
        Current version does not support Table 9.1 in risv-spec.
        The current version is: 
            all CSRRW/S/C(I) instructions will both read and write CSR
        The correct version should be:
            CSRRW/S/C(I) will only read CSR when rd != 0
            CSRRW/S/C(I) will only write CSR when rs1/uimm != 0
        (Read/Write CSR may cause some problems in the future)    

        :)
    */
    always_comb begin
        if (is_priv) begin
            case (func3)
                3'b001: begin id_csr_inst_sel = CSRRW; id_csr_raddr = csr_addr; id_csr_imm_sel = 1'b0; end
                3'b010: begin id_csr_inst_sel = CSRRS; id_csr_raddr = csr_addr; id_csr_imm_sel = 1'b0; end
                3'b011: begin id_csr_inst_sel = CSRRC; id_csr_raddr = csr_addr; id_csr_imm_sel = 1'b0; end
                3'b101: begin id_csr_inst_sel = CSRRWI; id_csr_raddr = csr_addr; id_csr_imm_sel = 1'b1; end
                3'b110: begin id_csr_inst_sel = CSRRSI; id_csr_raddr = csr_addr; id_csr_imm_sel = 1'b1; end
                3'b111: begin id_csr_inst_sel = CSRRCI; id_csr_raddr = csr_addr; id_csr_imm_sel = 1'b1; end
                3'b000: begin
                    case (csr_addr) // TODO: 似乎不需要读csr了
                        `CSR_ECALL: begin id_csr_inst_sel = ECALL; id_csr_raddr = `CSR_MTVEC; end 
                        `CSR_EBREAK: begin id_csr_inst_sel = EBREAK; id_csr_raddr = `CSR_MTVEC; end
                        `CSR_MRET: begin id_csr_inst_sel = MRET; id_csr_raddr = `CSR_MEPC; end
                        `CSR_SRET: begin id_csr_inst_sel = SRET; id_csr_raddr = `CSR_SEPC; end
                        default: begin id_csr_inst_sel = CSR_INST_NOP; id_csr_raddr = 0; end
                    endcase
                    id_csr_imm_sel = 1'b0;
                end
                default: begin id_csr_inst_sel = CSR_INST_NOP; id_csr_raddr = 0; id_csr_imm_sel = 1'b0; end
            endcase
        end else begin
            id_csr_inst_sel = CSR_INST_NOP;
            id_csr_raddr = 0;
            id_csr_imm_sel = 1'b0;
        end
    end

endmodule