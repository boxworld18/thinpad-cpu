`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module id_ex(
    input wire clk,
    input wire rst,
    input wire stall,
    input wire insert_nop,
    // PC Inst
    input wire [`ADDR_BUS] id_pc,
    input wire [`INST_BUS] id_inst,
    // regfile (EX + WB)
    input wire id_rf_wen,
    input wire [`REG_ADDR_BUS] id_rf_waddr,
    input wire [`DATA_BUS] id_rf_data_a,
    input wire [`DATA_BUS] id_rf_data_b,
    input wire id_rf_sel,
    // wishbone (MEM)
    input wire id_wb_wen,
    input wire id_wb_ren,
    input wire [`SEL] id_wb_sel,
    // alu (EX)
    input wire [`ALU_OP_WIDTH-1:0] id_alu_op,
    input wire id_alu_sel,
    // forward 
    input wire [`REG_ADDR_BUS] id_rs1,
    input wire [`REG_ADDR_BUS] id_rs2,
    // imm
    input wire [`DATA_BUS] id_imm,

    // output
    output reg [`ADDR_BUS] ex_pc,
    output reg [`INST_BUS] ex_inst,
    output reg ex_rf_wen,
    output reg [`REG_ADDR_BUS] ex_rf_waddr,
    output reg [`DATA_BUS] ex_rf_data_a,
    output reg [`DATA_BUS] ex_rf_data_b,
    output reg ex_rf_sel,
    output reg ex_wb_wen,
    output reg ex_wb_ren,
    output reg [`SEL] ex_wb_sel,
    output reg [`ALU_OP_WIDTH-1:0] ex_alu_op,
    output reg ex_alu_sel,
    output reg [`REG_ADDR_BUS] ex_rs1,
    output reg [`REG_ADDR_BUS] ex_rs2,
    output reg [`DATA_BUS] ex_imm

);

    always_ff @(posedge clk) begin
        if (rst) begin
            ex_pc <= 0;
            ex_inst <= 0;
            ex_rf_wen <= 1'b0;
            ex_rf_waddr <= 0;
            ex_rf_data_a <= 0;
            ex_rf_data_b <= 0;
            ex_rf_sel <= 1'b0;
            ex_wb_wen <= 1'b0;
            ex_wb_ren <= 1'b0;
            ex_wb_sel <= 0;
            ex_alu_op <= 0;
            ex_alu_sel <= 1'b0;
            ex_rs1 <= 0;
            ex_rs2 <= 0;
            ex_imm <= 0;
        end else if (!stall) begin
            if (insert_nop) begin
                ex_pc <= 0;
                ex_inst <= 0;
                ex_rf_wen <= 1'b0;
                ex_rf_waddr <= 0;
                ex_rf_data_a <= 0;
                ex_rf_data_b <= 0;
                ex_rf_sel <= 1'b0;
                ex_wb_wen <= 1'b0;
                ex_wb_ren <= 1'b0;
                ex_wb_sel <= 0;
                ex_alu_op <= 0;
                ex_alu_sel <= 1'b0;
                ex_rs1 <= 0;
                ex_rs2 <= 0;
                ex_imm <= 0;
            end else begin
                ex_pc <= id_pc;
                ex_inst <= id_inst;
                ex_rf_wen <= id_rf_wen;
                ex_rf_waddr <= id_rf_waddr;
                ex_rf_data_a <= id_rf_data_a;
                ex_rf_data_b <= id_rf_data_b;
                ex_rf_sel <= id_rf_sel;
                ex_wb_wen <= id_wb_wen;
                ex_wb_ren <= id_wb_ren;
                ex_wb_sel <= id_wb_sel;
                ex_alu_op <= id_alu_op;
                ex_alu_sel <= id_alu_sel;
                ex_rs1 <= id_rs1;
                ex_rs2 <= id_rs2;
                ex_imm <= id_imm;
            end
        end
    end

endmodule