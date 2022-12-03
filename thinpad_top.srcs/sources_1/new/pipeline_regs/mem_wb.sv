`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module mem_wb(
    input wire clk,
    input wire rst,
    input wire stall,
    input wire flush,

    input wire mem_load_page_fault,
    input wire [`ADDR_BUS] mem_load_fault_va,
    input wire mem_store_page_fault,
    input wire [`ADDR_BUS] mem_store_fault_va,

    input wire [`ADDR_BUS] mem_pc,
    input wire [`INST_BUS] mem_inst,
    input wire mem_rf_wen,
    input wire [`REG_ADDR_BUS] mem_rf_waddr,
    input wire [`REG_DATA_BUS] mem_rf_wdata,

    input wire [`CSR_SEL_WIDTH-1:0] mem_csr_inst_sel,
    input wire [`CSR_ADDR_BUS] mem_csr_waddr,
    input wire [`CSR_DATA_BUS] mem_csr_wdata,

    output reg [`ADDR_BUS] wb_pc,
    output reg [`INST_BUS] wb_inst,
    output reg wb_rf_wen,
    output reg [`REG_ADDR_BUS] wb_rf_waddr,
    output reg [`REG_DATA_BUS] wb_rf_wdata,

    output reg [`CSR_SEL_WIDTH-1:0] wb_csr_inst_sel,
    output reg [`CSR_ADDR_BUS] wb_csr_waddr,
    output reg [`CSR_DATA_BUS] wb_csr_wdata,

    output reg [`ADDR_BUS] wb_load_fault_va,
    output reg [`ADDR_BUS] wb_store_fault_va
);

    always_ff @ (posedge clk) begin
        if (rst) begin
            wb_pc <= `ZERO_WORD;
            wb_inst <= `INST_NOP;
            wb_rf_wen <= 1'b0;
            wb_rf_waddr <= 0;
            wb_rf_wdata <= 0;
            wb_csr_inst_sel <= CSR_INST_NOP;
            wb_csr_waddr <= 0;
            wb_csr_wdata <= 0;
            wb_load_fault_va <= 0;
            wb_store_fault_va <= 0;
        end else if (!stall) begin
            if (flush) begin
                wb_pc <= `ZERO_WORD;
                wb_inst <= `INST_NOP;
                wb_rf_wen <= 1'b0;
                wb_rf_waddr <= 0;
                wb_rf_wdata <= 0;
                wb_csr_inst_sel <= CSR_INST_NOP;
                wb_csr_waddr <= 0;
                wb_csr_wdata <= 0;
                wb_load_fault_va <= 0;
                wb_store_fault_va <= 0;
            end else begin
                if (mem_load_page_fault || mem_store_page_fault) begin
                    wb_pc <= mem_pc;
                    wb_inst <= mem_inst;
                    wb_rf_wen <= 1'b0;
                    wb_rf_waddr <= 0;
                    wb_rf_wdata <= 0;
                    wb_csr_inst_sel <= (mem_load_page_fault) ? LOAD_PAGE_FAULT : STORE_PAGE_FAULT;
                    wb_csr_waddr <= 0;
                    wb_csr_wdata <= 0;
                    wb_load_fault_va <= mem_load_fault_va;
                    wb_store_fault_va <= mem_store_fault_va;
                end else begin
                    wb_pc <= mem_pc;
                    wb_inst <= mem_inst;
                    wb_rf_wen <= mem_rf_wen;
                    wb_rf_waddr <= mem_rf_waddr;
                    wb_rf_wdata <= mem_rf_wdata;
                    wb_csr_inst_sel <= mem_csr_inst_sel;
                    wb_csr_waddr <= mem_csr_waddr;
                    wb_csr_wdata <= mem_csr_wdata;
                    wb_load_fault_va <= 0;
                    wb_store_fault_va <= 0;
                end 
            end
        end
    end

endmodule