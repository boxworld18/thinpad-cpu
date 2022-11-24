`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module csr(
    input wire clk,
    input wire rst,

    input wire ren,
    input wire [`CSR_ADDR_BUS] raddr,
    output reg [`CSR_DATA_BUS] rdata,

    input wire wen,
    input wire [`CSR_ADDR_BUS] waddr,
    input wire [`CSR_DATA_BUS] wdata
);

    logic [`CSR_DATA_BUS] mtvec;    // BASE(31:2) MODE(1:0)
    logic [`CSR_DATA_BUS] mepc;    
    logic [`CSR_DATA_BUS] mcause;   // Interrupt (31) Exception Code(30:0)
    logic [`CSR_DATA_BUS] mstatus;  // MPP(12:11) SPP(8) MPIE(7) SPIE(5) UPIE(4) MIE(3) SIE(1) UIE(0)
    logic [`CSR_DATA_BUS] mscratch; 
    logic [`CSR_DATA_BUS] mie;      
    logic [`CSR_DATA_BUS] mip;

    always_ff @ (posedge clk) begin
        if (rst) begin
            mtvec <= 32'b0;
            mepc <= 32'b0;
            mcause <= 32'b0;
            mstatus <= 32'b0;
            mscratch <= 32'b0;
            mie <= 32'b0;
            mip <= 32'b0;
        end else begin
            
        end
    end


endmodule