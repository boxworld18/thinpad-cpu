`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module control(
    input wire [`ADDR_BUS] pc,
    input wire [`INST_BUS] inst,

    // regfile
    output reg id_rf_wen,
    output reg id_rf_sel,
    // wishbone
    output wire id_wb_wen,
    output wire id_wb_ren,
    output reg [`SEL] id_wb_sel,
    // alu
    output reg [`ALU_OP_WIDTH-1:0] id_alu_op,
    output reg id_alu_sel_imm,
    output reg id_alu_sel_pc
);

    // 提取指令字段
    logic [6:0] func7;
    logic [2:0] func3;
    logic [6:0] opcode;
    logic [4:0] rs2;
    assign func7 = inst[31:25];
    assign func3 = inst[14:12];
    assign opcode = inst[6:0];
    assign rs2 = inst[24:20];

    // 判断指令类型, 设置选择信号
    /*
        R:     add rd, rs1, rs2   ---  x[rd] = rs1 op rs2                        --- add, sub, and, or, xor, sll, srl, sra, 
        I:     addi rd, rs1, imm  ---  x[rd] = rs1 op imm                        --- addi, andi, ori, xori, slli, srli, srai,
        L:     lw rd, imm(rs1)    ---  x[rd] = mem[rs1 + imm]                    --- lb lh lw  还差 lbu lhu
        S:     sw rs2, imm(rs1)   ---  mem[rs2] = rs1 + imm                      --- sb sh sw
        SB:    beq rs1, rs2, imm  ---  pc = pc + imm                             --- beq bne blt bge bltu bgeu
        LUI:   lui rd, imm        ---  x[rd] = imm                               --- lui
        AUIPC: auipc rd, imm      ---  x[rd] = pc + imm                          --- auipc   
        JAL:   jal rd, imm        ---  x[rd] = pc + 4; pc = pc + imm             --- jal   
        JALR:  jalr rd, imm(rs1)  ---  x[rd] = pc + 4; pc = (x[rs1] + imm) & ~1; --- jalr
     */

    logic is_r, is_i, is_l, is_s, is_sb, is_lui, is_auipc, is_jal, is_jalr; 
    assign is_r = (opcode == `OPCODE_R);
    assign is_i = (opcode == `OPCODE_I);
    assign is_l = (opcode == `OPCODE_L);
    assign is_s = (opcode == `OPCODE_S);
    assign is_sb = (opcode == `OPCODE_SB);
    assign is_lui = (opcode == `OPCODE_LUI);
    assign is_auipc = (opcode == `OPCODE_AUIPC);
    assign is_jal = (opcode == `OPCODE_JAL);
    assign is_jalr = (opcode == `OPCODE_JALR);

    // alu
    assign id_alu_sel_pc = (is_auipc || is_jal || is_jalr) ? ALU_SEL_PC : ALU_SEL_REG_A;
    assign id_alu_sel_imm = (is_r) ? ALU_SEL_REG_B : ALU_SEL_IMM;

    // rf
    assign id_rf_sel = (is_l); // lw 读取 mem, 其他读取 alu_result
    assign id_rf_wen = ((is_s) || (is_sb)) ? `DISABLE : `ENABLE;

    // wishbone
    assign id_wb_wen = (is_s);
    assign id_wb_ren = (is_l);
    
    always_comb begin // 不代表最终的使能, 只确定字节数, 写入wishbone之前应左移 addr 的低2位
        case (func3)
            3'b000: id_wb_sel = 4'b0001;
            3'b100: id_wb_sel = 4'b0001;
            3'b001: id_wb_sel = 4'b0011;
            3'b101: id_wb_sel = 4'b0011;
            3'b010: id_wb_sel = 4'b1111;
            default: id_wb_sel = 4'b0000;
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
                3'b010: id_alu_op = ALU_OP_SLT; // alu 暂不支持
                3'b011: id_alu_op = ALU_OP_SLTU; // alu 暂不支持
                3'b100: begin
                    if (func7 == 7'b0010100)
                        id_alu_op = ALU_OP_X;
                    else
                        id_alu_op = ALU_OP_XOR;
                end
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
        end else if (is_lui) begin // lui: choose imm directly
            id_alu_op = ALU_OP_B;
        end else if (is_jal || is_jalr) begin
            id_alu_op = ALU_OP_ADD_4;
        end else begin
            id_alu_op = ALU_OP_ADD;
        end
    end

endmodule