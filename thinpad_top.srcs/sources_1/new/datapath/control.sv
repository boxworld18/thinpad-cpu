`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module control(
    input wire [`ADDR_BUS] pc,
    input wire [`INST_BUS] inst,

    output reg [2:0] id_imm_type,
    // regfile
    output reg id_rf_wen,
    output reg id_rf_sel,
    // wishbone
    output wire id_wb_wen,
    output wire id_wb_ren,
    output reg [`SEL] id_wb_sel,
    // alu
    output reg [`ALU_OP_WIDTH-1:0] id_alu_op,
    output reg id_alu_sel
);

    // 提取指令字段
    logic [6:0] func7;
    logic [2:0] func3;
    logic [6:0] opcode;
    assign func7 = inst[31:25];
    assign func3 = inst[14:12];
    assign opcode = inst[6:0];

    // 判断指令类型, 设置选择信号
    logic [3:0] inst_type;

    always_comb begin
        case (opcode)
            `OPCODE_R: begin // add rd, rs1, rs2  
                inst_type = INST_R;
                id_rf_wen = `ENABLE;
                id_alu_sel = ALU_SEL_REG; // rs1 op rs2
                id_imm_type = IMM_NOP;
            end
            `OPCODE_I: begin // addi rd, rs1, imm
                inst_type = INST_I;
                id_rf_wen = `ENABLE;
                id_alu_sel = ALU_SEL_IMM; // rs1 op imm
                id_imm_type = IMM_I;
            end
            `OPCODE_S: begin // sw rs2, imm(rs1)
                inst_type = INST_S;
                id_rf_wen = `DISABLE;
                id_alu_sel = ALU_SEL_IMM; // rs1 + imm
                id_imm_type = IMM_S;
            end
            `OPCODE_SB: begin // beq rs1, rs2, imm
                inst_type = INST_SB;
                id_rf_wen = `DISABLE;
                id_alu_sel = ALU_SEL_IMM; // do nothing
                id_imm_type = IMM_SB;
            end
            `OPCODE_U: begin // lui rd, imm
                inst_type = INST_U;
                id_rf_wen = `ENABLE;
                id_alu_sel = ALU_SEL_IMM; // choose imm directly
                id_imm_type = IMM_U;
            end
            `OPCODE_L: begin // lw rd, imm(rs1)
                inst_type = INST_L;
                id_rf_wen = `ENABLE;
                id_alu_sel = ALU_SEL_IMM; // rs1 + imm
                id_imm_type = IMM_I;
            end
            default: begin // 不支持 jal jalr auipc 
                inst_type = INST_NOP;
                id_rf_wen = `DISABLE;
                id_alu_sel = ALU_SEL_IMM; // do nothing
                id_imm_type = IMM_NOP;
            end
        endcase
    end

    assign id_rf_sel = (inst_type == INST_L); // lw 读取 mem, 其他读取 alu_result

    // wishbone
    assign id_wb_wen = (inst_type == INST_S);
    assign id_wb_ren = (inst_type == INST_L);
    
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
        if (inst_type == INST_R || inst_type == INST_I) begin
            case (func3)
                3'b000: begin
                    if (inst_type == INST_R && func7 == 7'b0100000)
                        id_alu_op = ALU_OP_SUB;
                    else
                        id_alu_op = ALU_OP_ADD;
                end
                3'b001: id_alu_op = ALU_OP_SLL;
                3'b010: id_alu_op = ALU_OP_SLT; // alu 暂不支持
                3'b011: id_alu_op = ALU_OP_SLTU; // alu 暂不支持
                3'b100: id_alu_op = ALU_OP_XOR;
                3'b101: begin
                    if (func7 == 7'b0100000)
                        id_alu_op = ALU_OP_SRA;
                    else
                        id_alu_op = ALU_OP_SRL;
                end
                3'b110: id_alu_op = ALU_OP_OR;
                3'b111: id_alu_op = ALU_OP_AND;
                default: id_alu_op = ALU_OP_NOP;
            endcase
        end else if (inst_type == INST_U) begin // lui: choose imm directly
            id_alu_op = ALU_OP_B;
        end else begin
            id_alu_op = ALU_OP_ADD;
        end
    end

endmodule