`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module csr(
    input wire clk,
    input wire rst,
    
    input wire [`CSR_SEL_WIDTH-1:0] sel, // instruction type  
    
    // raddr rdata waddr wdata 都只用于 CSRRW/S/C
    input wire [`CSR_ADDR_BUS] raddr,
    output reg [`CSR_DATA_BUS] rdata,
    input wire [`CSR_ADDR_BUS] waddr,
    input wire [`CSR_DATA_BUS] wdata,

    input wire [`ADDR_BUS] wb_pc,
    // output reg [`CSR_DATA_BUS] csr_mstatus,
    // output reg [`CSR_DATA_BUS] csr_mie,
    // output reg [`CSR_DATA_BUS] csr_mip,

    output reg [`CSR_DATA_BUS] csr_mtvec,
    output reg time_interrupt_enable,

    output wire [1:0] mode_o
);

    // mode
    logic [1:0] mode; // 0: user, 1: supervisor, 3: machine
    assign mode_o = mode;

    // M-MODE
    logic [`CSR_DATA_BUS] mtvec;    // BASE(31:2) MODE(1:0)
    logic [`CSR_DATA_BUS] mepc;    
    logic [`CSR_DATA_BUS] mcause;   // Interrupt (31) Exception Code(30:0)
    logic [`CSR_DATA_BUS] mstatus;  // MPP(12:11) SPP(8) MPIE(7) SPIE(5) UPIE(4) MIE(3) SIE(1) UIE(0)
    logic [`CSR_DATA_BUS] mscratch; 
    logic [`CSR_DATA_BUS] mie;      
    logic [`CSR_DATA_BUS] mip;
    logic [`CSR_DATA_BUS] mtval;
    logic [`CSR_DATA_BUS] mideleg; 
    logic [`CSR_DATA_BUS] medeleg; 
    logic [`CSR_DATA_BUS] mhartid;  // 0
    logic [63:0] rdtime;

    // S-MODE
    logic [`CSR_DATA_BUS] stvec; 
    logic [`CSR_DATA_BUS] sepc;    
    logic [`CSR_DATA_BUS] scause;  
    logic [`CSR_DATA_BUS] sstatus;  
    logic [`CSR_DATA_BUS] sscratch; 
    logic [`CSR_DATA_BUS] sie;      
    logic [`CSR_DATA_BUS] sip;
    logic [`CSR_DATA_BUS] stval;

    // 无关寄存器, 防止报错
    logic [`CSR_DATA_BUS] pmpcfg0;
    logic [`CSR_DATA_BUS] pmpaddr0;

    assign csr_mtvec = mtvec; // TODO: pass this signal in pipeline
    assign time_interrupt_enable = (mie[`MIE_MTIE] && 
                                    (mode == U_MODE || (mode == M_MODE && mstatus[`MSTATUS_MIE] == 1))
                                    );
                                    
    always_comb begin
        case (raddr)
            `CSR_MTVEC:     rdata = mtvec;
            `CSR_MEPC:      rdata = mepc;
            `CSR_MCAUSE:    rdata = mcause;
            `CSR_MSTATUS:   rdata = mstatus;
            `CSR_MSCRATCH:  rdata = mscratch;
            `CSR_MIE:       rdata = mie;
            `CSR_MIP:       rdata = mip;
            `CSR_MTVAL:     rdata = mtval;
            `CSR_MIDELEG:   rdata = mideleg;
            `CSR_MEDELEG:   rdata = medeleg;
            `CSR_MHARTID:   rdata = mhartid;  
            `CSR_RDTIME:    rdata = rdtime[31:0];
            `CSR_RDTIMEH:   rdata = rdtime[63:32];

            `CSR_STVEC:     rdata = stvec;
            `CSR_SEPC:      rdata = sepc;
            `CSR_SCAUSE:    rdata = scause;
            `CSR_SSTATUS:   rdata = sstatus;
            `CSR_SSCRATCH:  rdata = sscratch;
            `CSR_SIE:       rdata = sie;
            `CSR_SIP:       rdata = sip;
            `CSR_STVAL:     rdata = stval;

            `CSR_PMPCFG0:   rdata = pmpcfg0;
            `CSR_PMPADDR0:  rdata = pmpaddr0;
            default:        rdata = 0;
        endcase
    end

    /* restrict view 
        mstatus  -  sstatus
        mip      -  sip
        mie      -  sie    
    */

    always_comb begin
        sstatus = mstatus;
        sstatus[`MSTATUS_MPP] = 0;
        sstatus[`MSTATUS_MPIE] = 0;
        sstatus[`MSTATUS_MIE] = 0;
    end

    always_comb begin
        sip = mip;
        sip[`MIP_MTIP] = 0;
    end

    always_comb begin
        sie = mie;
        sie[`MIE_MTIE] = 0;
    end

    logic [30:0] cause_exception_code;
    always_comb begin
        case (sel)
            ECALL: begin
                case (mode) 
                    M_MODE: cause_exception_code = `EXCEPTION_CODE_ECALL_M_MODE;
                    S_MODE: cause_exception_code = `EXCEPTION_CODE_ECALL_S_MODE;
                    U_MODE: cause_exception_code = `EXCEPTION_CODE_ECALL_U_MODE;
                    default: cause_exception_code = `EXCEPTION_CODE_ECALL_M_MODE;
                endcase
            end
            EBREAK: cause_exception_code = `EXCEPTION_CODE_BREAKPOINT;
            INST_PAGE_FAULT: cause_exception_code = `EXCEPTION_CODE_INST_PAGE_FAULT;
            LOAD_PAGE_FAULT: cause_exception_code = `EXCEPTION_CODE_LOAD_PAGE_FAULT;
            STORE_PAGE_FAULT: cause_exception_code = `EXCEPTION_CODE_STORE_AMO_PAGE_FAULT;
            default: cause_exception_code = 31'h8fffffff;
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
            mtval <= 0;
            mideleg <= 0;
            medeleg <= 0;
            mhartid <= 0;

            stvec <= 0;
            sepc <= 0;
            scause <= 0;
            sscratch <= 0;
            stval <= 0;

            pmpcfg0 <= 0;
            pmpaddr0 <= 0;
            mode <= M_MODE;
        end else begin
            case (sel)
                CSR_INST_NOP: ;
                CSRRW, CSRRWI, CSRRS, CSRRSI, CSRRC, CSRRCI: begin
                    case (waddr)
                        `CSR_MTVEC:     mtvec <= wdata;
                        `CSR_MEPC:      mepc <= wdata;
                        `CSR_MCAUSE:    mcause <= wdata;
                        `CSR_MSTATUS:   mstatus <= wdata; 
                        `CSR_MSCRATCH:  mscratch <= wdata;
                        `CSR_MIE:       mie <= wdata;
                        `CSR_MIP:       mip <= wdata;
                        `CSR_MTVAL:     mtval <= wdata;
                        `CSR_MIDELEG:   mideleg <= wdata;
                        `CSR_MEDELEG:   medeleg <= wdata;
                        `CSR_MHARTID:   mhartid <= wdata;

                        `CSR_STVEC:     stvec <= wdata;
                        `CSR_SEPC:      sepc <= wdata;
                        `CSR_SCAUSE:    scause <= wdata;
                        `CSR_SSTATUS:   mstatus <= (wdata & `SSTATUS_MASK) | (mstatus & ~`SSTATUS_MASK);
                        `CSR_SSCRATCH:  sscratch <= wdata;
                        `CSR_SIE:       mie <= (wdata & `SIE_MASK) | (mie & ~`SIE_MASK);
                        `CSR_SIP:       mip <= (wdata & `SIP_MASK) | (mip & ~`SIP_MASK);
                        `CSR_STVAL:     stval <= wdata;

                        `CSR_PMPCFG0:   pmpcfg0 <= wdata;
                        `CSR_PMPADDR0:  pmpaddr0 <= wdata;
                        default: ;
                    endcase
                end
                ECALL, EBREAK, INST_PAGE_FAULT, LOAD_PAGE_FAULT, STORE_PAGE_FAULT: begin  
                    if (medeleg[`EXCEPTION_CODE_ECALL_S_MODE] && (mode != M_MODE)) begin
                        sepc <= wb_pc;
                        scause[`CAUSE_INTERRUPT] <= `EXCEPTION;
                        scause[`CAUSE_EXCEPTION_CODE] <= cause_exception_code;
                        mstatus[`MSTATUS_SPP] <= mode;
                        mstatus[`MSTATUS_SPIE] <= mstatus[`MSTATUS_SIE];
                        mstatus[`MSTATUS_SIE] <= 0;
                        mode <= S_MODE;
                    end else begin
                        mepc <= wb_pc;
                        mcause[`CAUSE_INTERRUPT] <= `EXCEPTION;
                        mcause[`CAUSE_EXCEPTION_CODE] <= cause_exception_code;
                        mstatus[`MSTATUS_MPP] <= mode;
                        mstatus[`MSTATUS_MPIE] <= mstatus[`MSTATUS_MIE];
                        mstatus[`MSTATUS_MIE] <= 0;
                        mode <= M_MODE;
                    end
                end
                MRET: begin
                    if (mode == M_MODE) begin
                        mode <= mstatus[`MSTATUS_MPP];
                        mstatus[`MSTATUS_MIE] <= mstatus[`MSTATUS_MPIE];
                        mstatus[`MSTATUS_MPP] <= U_MODE;
                        mstatus[`MSTATUS_MPIE] <= 1;
                    end
                end
                SRET: begin
                    if (mode == M_MODE || mode == S_MODE) begin
                        mode <= mstatus[`MSTATUS_SPP];
                        mstatus[`MSTATUS_SIE] <= mstatus[`MSTATUS_SPIE];
                        mstatus[`MSTATUS_SPP] <= U_MODE;
                        mstatus[`MSTATUS_SPIE] <= 1;
                    end
                end
                // TODO: ! ! ! ! ! !
                // 需要重写, 现在完全不对
                // TIME_INTERRUPT: begin  // correct version: assign mip[`MIP_MTIP] = mtime >= mtimecmp
                    
                //     if (mie[`MIE_MTIE]) begin
                //         if (mode == U_MODE) begin
                //             mepc <= wb_pc;
                //             mcause[`CAUSE_INTERRUPT] <= `INTERRUPT;
                //              if (mode == M_MODE) begin
                //                 mcause[`CAUSE_EXCEPTION_CODE] <= `EXCEPTION_CODE_M_TIME_INTERRUPT;
                //             end else if (mode == S_MODE) begin
                //                 mcause[`CAUSE_EXCEPTION_CODE] <= `EXCEPTION_CODE_S_TIME_INTERRUPT;
                //             end else if (mode == U_MODE) begin
                //                 mcause[`CAUSE_EXCEPTION_CODE] <= `EXCEPTION_CODE_U_TIME_INTERRUPT;
                //             end
                //             mstatus[`MSTATUS_MPIE] <= mstatus[`MSTATUS_MIE];
                //             mstatus[`MSTATUS_MIE] <= 0;
                //             mstatus[`MSTATUS_MPP] <= 0;
                //             mip[`MIP_MTIP] <= 1;
                //             mode <= M_MODE;
                //         end else if (mode == M_MODE && mstatus[`MSTATUS_MIE] == 1) begin
                //             mepc <= wb_pc;
                //             mcause <= `EXCEPTION_CODE_M_TIME_INTERRUPT;
                //             mstatus[`MSTATUS_MPIE] <= mstatus[`MSTATUS_MIE];
                //             mstatus[`MSTATUS_MIE] <= 0;
                //             mstatus[`MSTATUS_MPP] <= M_MODE;
                //             mip[`MIP_MTIP] <= 1;
                //         end
                //     end
                // end
                default: ;
            endcase
        end
    end

    always_ff @ (posedge clk) begin
        if (rst) begin
            rdtime <= 64'b0;
        end else begin
            rdtime <= rdtime + 1;
        end
    end
    
endmodule