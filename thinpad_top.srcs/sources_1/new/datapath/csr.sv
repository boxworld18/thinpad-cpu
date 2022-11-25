`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module csr(
    input wire clk,
    input wire rst,
    
    input wire [`CSR_ADDR_BUS] raddr,
    output reg [`CSR_DATA_BUS] rdata,

    input wire [2:0] sel,
    input wire [`CSR_ADDR_BUS] waddr,
    input wire [`CSR_DATA_BUS] wdata
);

    csr_data csr_regs;
    // logic [`CSR_DATA_BUS] mtvec;    // BASE(31:2) MODE(1:0)
    // logic [`CSR_DATA_BUS] mepc;    
    // logic [`CSR_DATA_BUS] mcause;   // Interrupt (31) Exception Code(30:0)
    // logic [`CSR_DATA_BUS] mstatus;  // MPP(12:11) SPP(8) MPIE(7) SPIE(5) UPIE(4) MIE(3) SIE(1) UIE(0)
    // logic [`CSR_DATA_BUS] mscratch; 
    // logic [`CSR_DATA_BUS] mie;      
    // logic [`CSR_DATA_BUS] mip;

    always_comb begin
        case (raddr)
            `CSR_MTVEC:     rdata = csr_regs.mtvec;
            `CSR_MEPC:      rdata = csr_regs.mepc;
            `CSR_MCAUSE:    rdata = csr_regs.mcause;
            `CSR_MSTATUS:   rdata = csr_regs.mstatus;
            `CSR_MSCRATCH:  rdata = csr_regs.mscratch;
            `CSR_MIE:       rdata = csr_regs.mie;
            `CSR_MIP:       rdata = csr_regs.mip;  
            default:        rdata = 0;
        endcase
    end

    genvar m;
    generate
        for (m = 0; m < `CSR_NUM; m = m + 1)
        begin: generate_csr_controller
            always_ff @ (posedge clk) begin
                if (rst) begin
                    csr_regs[m] <= 0;
                end else begin
                    if (wen[m]) begin
                        csr_regs[m] <= wdata[m];
                    end
                    if (ren[m]) begin
                        csr_rdata_regs[m] <= csr_regs[m];
                    end
                end
            end
        end
    endgenerate
    
endmodule