`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module if_id(
    input wire clk,
    input wire rst,
    input wire stall,
    input wire flush,
    input wire hold,
    input wire if_inst_page_fault,

    input wire [`ADDR_BUS] if_pc,
    input wire [`INST_BUS] if_inst,

    output reg [`ADDR_BUS] id_pc,
    output reg [`INST_BUS] id_inst,
    output reg id_inst_page_fault
);

    always_ff @ (posedge clk) begin
        if (rst) begin
            id_pc <= `ZERO_WORD;
            id_inst <= `INST_NOP;
            id_inst_page_fault <= 1'b0;
        end else if (~stall) begin
            if (flush) begin
                id_pc <= `ZERO_WORD;
                id_inst <= `INST_NOP;
                id_inst_page_fault <= 1'b0;
            end else if (~hold) begin
                id_pc <= if_pc;
                id_inst <= if_inst_page_fault ? `INST_NOP : if_inst;
                id_inst_page_fault <= if_inst_page_fault;
            end
        end
    end

endmodule