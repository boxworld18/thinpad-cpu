`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module if_id(
    input wire clk,
    input wire rst,
    input wire stall,
    input wire hazard,

    input wire [`ADDR_BUS] if_pc,
    input wire [`INST_BUS] if_inst,

    output reg [`ADDR_BUS] id_pc,
    output reg [`INST_BUS] id_inst
);

    always_ff @ (posedge clk) begin
        if (rst) begin
            id_pc <= `ZERO_WORD;
            id_inst <= `ZERO_WORD;
        end else if ((~stall) & (~hazard)) begin
            id_pc <= if_pc;
            id_inst <= if_inst;
        end
    end

endmodule