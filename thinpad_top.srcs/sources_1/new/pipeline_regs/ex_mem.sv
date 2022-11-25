`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module ex_mem(
    input wire clk,
    input wire rst,
    input wire stall,
    
    // pc
    input wire [`ADDR_BUS] ex_pc,

    input wire [`DATA_BUS] ex_data,
    input wire [`DATA_BUS] ex_wb_wdata,
    // wishbone
    input wire ex_wb_wen, // write enable
    input wire ex_wb_ren, // read enable
    input wire [`SEL] ex_wb_sel,
    // regfile
    input wire ex_rf_wen,
    input wire [`REG_ADDR_BUS] ex_rf_waddr,
    input wire ex_rf_sel,
    // csr
    input wire [2:0] ex_csr_inst_sel,
    input wire ex_csr_waddr,
    input wire ex_csr_wdata,

    //output
    output reg [`ADDR_BUS] mem_pc,

    output reg [`DATA_BUS] mem_data,
    output reg [`DATA_BUS] mem_wb_wdata,

    output reg mem_wb_wen,
    output reg mem_wb_ren,
    output reg [`SEL] mem_wb_sel,

    output reg mem_rf_wen,
    output reg [`REG_ADDR_BUS] mem_rf_waddr,
    output reg mem_rf_sel,

    output reg [2:0] mem_csr_inst_sel,
    output reg mem_csr_waddr,
    output reg mem_csr_wdata
);

    always_ff @ (posedge clk) begin
        if (rst) begin
            mem_pc <= 0;
            mem_data <= 0;
            mem_wb_wdata <= 0;
            mem_wb_wen <= 1'b0;
            mem_wb_ren <= 1'b0;
            mem_wb_sel <= 0;
            mem_rf_wen <= 1'b0;
            mem_rf_waddr <= 0;
            mem_rf_sel <= 1'b0;
            mem_csr_inst_sel <= 0;
            mem_csr_waddr <= 0;
            mem_csr_wdata <= 0;
        end else if (!stall) begin
            mem_pc <= ex_pc;
            mem_data <= ex_data;
            mem_wb_wdata <= ex_wb_wdata;
            mem_wb_wen <= ex_wb_wen;
            mem_wb_ren <= ex_wb_ren;
            mem_wb_sel <= ex_wb_sel;
            mem_rf_wen <= ex_rf_wen;
            mem_rf_waddr <= ex_rf_waddr;
            mem_rf_sel <= ex_rf_sel;
            mem_csr_inst_sel <= ex_csr_inst_sel;
            mem_csr_waddr <= ex_csr_waddr;
            mem_csr_wdata <= ex_csr_wdata;
        end
    end

endmodule