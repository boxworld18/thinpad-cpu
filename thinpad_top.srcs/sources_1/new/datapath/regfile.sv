`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module regfile(
    input wire clk,
    input wire rst,

    input wire [`REG_ADDR_BUS] raddr_a,
    input wire [`REG_ADDR_BUS] raddr_b, 
    input wire [`REG_ADDR_BUS] waddr,  
    input wire [`REG_DATA_BUS] wdata, 
    input wire wen,          

    output wire [`REG_DATA_BUS] rdata_a, 
    output wire [`REG_DATA_BUS] rdata_b  
);

    logic [`REG_DATA_BUS][`REG_NUM-1:0] regs;

    assign rdata_a = regs[raddr_a];
    assign rdata_b = regs[raddr_b];

    always_ff @ (posedge clk) begin
        if (rst) begin
            regs <= {(`REG_DATA_WIDTH * `REG_NUM){1'h0}}; 
        end else begin
            if (wen && waddr != 0) begin
                regs[waddr] <= wdata;
            end
        end
    end

endmodule