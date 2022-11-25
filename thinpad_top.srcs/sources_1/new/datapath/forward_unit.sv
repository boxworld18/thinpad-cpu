`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module forward_unit(
    input wire [`REG_ADDR_BUS] ex_rs1,
    input wire [`REG_ADDR_BUS] ex_rs2,
    input wire [`REG_ADDR_BUS] mem_rd,
    input wire mem_rf_wen, 
    input wire [`REG_ADDR_BUS] wb_rd,
    input wire wb_rf_wen,

    input wire [`CSR_ADDR_BUS] ex_csr_raddr,
    input wire [`CSR_ADDR_BUS] mem_csr_waddr,
    input wire [`CSR_DATA_BUS] mem_csr_wdata,
    input wire [`CSR_ADDR_BUS] wb_csr_waddr,
    input wire [`CSR_DATA_BUS] wb_csr_wdata,

    output wire [1:0] alu_sel_a,
    output wire [1:0] alu_sel_b,
    output wire [1:0] alu_sel_csr
);
    logic mem_pos, wb_pos, mem_forward_a, mem_forward_b, wb_forward_a, wb_forward_b;
    assign mem_pos = mem_rf_wen & (mem_rd != 0);
    assign wb_pos = wb_rf_wen & (wb_rd != 0);

    assign mem_forward_a = mem_pos & (mem_rd == ex_rs1);
    assign mem_forward_b = mem_pos & (mem_rd == ex_rs2);
    assign wb_forward_a = wb_pos & (wb_rd == ex_rs1);
    assign wb_forward_b = wb_pos & (wb_rd == ex_rs2);

    assign alu_sel_a = mem_forward_a ? ALU_SEL_MEM : (wb_forward_a ? ALU_SEL_WB : ALU_SEL_EX);
    assign alu_sel_b = mem_forward_b ? ALU_SEL_MEM : (wb_forward_b ? ALU_SEL_WB : ALU_SEL_EX);

    logic mem_forward_csr, wb_forward_csr;
    assign mem_forward_csr = (mem_csr_waddr == ex_csr_raddr);
    assign wb_forward_csr = (wb_csr_waddr == ex_csr_raddr);
    assign alu_sel_csr = mem_forward_csr ? ALU_SEL_MEM : (wb_forward_csr ? ALU_SEL_WB : ALU_SEL_EX);

endmodule