`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module csr(
    input wire clk,
    input wire rst,
    
    input wire [`CSR_ADDR_BUS] raddr,
    output reg [`CSR_DATA_BUS] rdata,

    input wire [`ADDR_BUS] wb_pc,
    input wire [2:0] sel, // 指令 sel
    input wire [`CSR_ADDR_BUS] waddr,
    input wire [`CSR_DATA_BUS] wdata,

    output reg [`CSR_DATA_BUS] csr_mstatus,
    output reg [`CSR_DATA_BUS] csr_mie,
    output reg [`CSR_DATA_BUS] csr_mip
);

    // csr_data csr_regs;
    logic [`CSR_DATA_BUS] mtvec;    // BASE(31:2) MODE(1:0)
    logic [`CSR_DATA_BUS] mepc;    
    logic [`CSR_DATA_BUS] mcause;   // Interrupt (31) Exception Code(30:0)
    logic [`CSR_DATA_BUS] mstatus;  // MPP(12:11) SPP(8) MPIE(7) SPIE(5) UPIE(4) MIE(3) SIE(1) UIE(0)
    logic [`CSR_DATA_BUS] mscratch; 
    logic [`CSR_DATA_BUS] mie;      
    logic [`CSR_DATA_BUS] mip;

    always_comb begin
        case (raddr)
            `CSR_MTVEC:     rdata = mtvec;
            `CSR_MEPC:      rdata = mepc;
            `CSR_MCAUSE:    rdata = mcause;
            `CSR_MSTATUS:   rdata = mstatus;
            `CSR_MSCRATCH:  rdata = mscratch;
            `CSR_MIE:       rdata = mie;
            `CSR_MIP:       rdata = mip;  
            default:        rdata = 0;
        endcase
    end

    always_ff @ (posedge clk) begin
        if (rst) begin
            mtvec <= 0;
            mepc <= 0;
            mcause <= 0;
            mstatus <= 0;
            mscratch <= 0;
            mie <= 0;
            mip <= 0;
        end else begin
            case (sel)
                CSR_INST_NOP: ;
                CSRRW: begin
                    case (waddr)
                        `CSR_MTVEC:     mtvec <= wdata;
                        `CSR_MEPC:      mepc <= wdata;
                        `CSR_MCAUSE:    mcause <= wdata;
                        `CSR_MSTATUS:   mstatus <= wdata;
                        `CSR_MSCRATCH:  mscratch <= wdata;
                        `CSR_MIE:       mie <= wdata;
                        `CSR_MIP:       mip <= wdata;  
                        default: ;
                    endcase
                end
                CSRRS: begin
                    case (waddr)
                        `CSR_MTVEC:     mtvec <= mtvec | wdata;
                        `CSR_MEPC:      mepc <= mepc | wdata;
                        `CSR_MCAUSE:    mcause <= mcause | wdata;
                        `CSR_MSTATUS:   mstatus <= mstatus | wdata;
                        `CSR_MSCRATCH:  mscratch <= mscratch | wdata;
                        `CSR_MIE:       mie <= mie | wdata;
                        `CSR_MIP:       mip <= mip | wdata;  
                        default: ;
                    endcase
                end
                CSRRC: begin
                    case (waddr)
                        `CSR_MTVEC:     mtvec <= mtvec & ~wdata;
                        `CSR_MEPC:      mepc <= mepc & ~wdata;
                        `CSR_MCAUSE:    mcause <= mcause & ~wdata;
                        `CSR_MSTATUS:   mstatus <= mstatus & ~wdata;
                        `CSR_MSCRATCH:  mscratch <= mscratch & ~wdata;
                        `CSR_MIE:       mie <= mie & ~wdata;
                        `CSR_MIP:       mip <= mip & ~wdata;  
                        default: ;
                    endcase
                end
                ECALL: begin
                    mepc <= wb_pc;
                    mcause <= `CAUSE_ECALL;
                    mstatus[`STATUS_MPIE] <= mstatus[`STATUS_MIE];
                    mstatus[`STATUS_MIE] <= 0;
                    mstatus[`STATUS_MPP] <= 0;
                end
                EBREAK: begin
                    mepc <= wb_pc;
                    mcause <= `CAUSE_EBREAK;
                    mstatus[`STATUS_MPIE] <= mstatus[`STATUS_MIE];
                    mstatus[`STATUS_MIE] <= 0;
                    mstatus[`STATUS_MPP] <= 0;
                end
                MRET: begin
                    mstatus[`STATUS_MIE] <= mstatus[`STATUS_MPIE];
                    mstatus[`STATUS_MPP] <= 0;
                    mstatus[`STATUS_MPIE] <= 1;
                end
                default: ;
            endcase
        end
    end
    
endmodule