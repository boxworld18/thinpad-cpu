`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module mem_wb(
    input wire clk,
    input wire rst,
    input wire stall,

    input wire [`ADDR_BUS] mem_pc,
    input wire mem_rf_wen,
    input wire [`REG_ADDR_BUS] mem_rf_waddr,
    input wire [`REG_DATA_BUS] mem_rf_wdata,

    output reg [`ADDR_BUS] wb_pc,
    output reg wb_rf_wen,
    output reg [`REG_ADDR_BUS] wb_rf_waddr,
    output reg [`REG_DATA_BUS] wb_rf_wdata
);

    always_ff @ (posedge clk) begin
        if (rst) begin
            wb_pc <= 0;
            wb_rf_wen <= 1'b0;
            wb_rf_waddr <= 0;
            wb_rf_wdata <= 0;
        end else if (!stall) begin
            wb_pc <= mem_pc;
            wb_rf_wen <= mem_rf_wen;
            wb_rf_waddr <= mem_rf_waddr;
            wb_rf_wdata <= mem_rf_wdata;
        end
    end

endmodule