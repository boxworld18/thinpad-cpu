`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module ctz_decoder #(
    parameter DATA_WIDTH = 32
) (
    input wire [DATA_WIDTH-1:0] data,
    output reg sel,
    output reg [DATA_WIDTH/2-1:0] data_sel
);

    always_comb begin
        if (data[DATA_WIDTH/2-1:0] == 0) begin
            sel = 1'b1;
            data_sel = data[DATA_WIDTH-1:DATA_WIDTH/2];
        end else begin
            sel = 1'b0;
            data_sel = data[DATA_WIDTH/2-1:0];
        end
    end

endmodule