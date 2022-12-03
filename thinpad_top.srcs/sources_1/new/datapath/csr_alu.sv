`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

// ex stage
module csr_alu(
    input wire [`CSR_SEL_WIDTH-1:0] sel,
    input wire imm_sel,
    input wire [`DATA_BUS] rs1_data,
    input wire [`DATA_BUS] imm,

    // csr
    input wire [1:0] mode,
    input wire [`CSR_DATA_BUS] rdata,
    input wire [`CSR_ADDR_BUS] waddr,
    output reg [`CSR_DATA_BUS] wdata
);

    logic [`DATA_BUS] reg_data;
    assign reg_data = imm_sel ? imm : rs1_data;

    logic [`CSR_DATA_BUS] tmp;

    always_comb begin
        case (sel)
            CSRRW, CSRRWI: tmp = reg_data;
            CSRRS, CSRRSI: tmp = rdata | reg_data;
            CSRRC, CSRRCI: tmp = rdata & ~reg_data;
            default: tmp = rdata;
        endcase 
    end

    logic m_en, s_en, u_en; // enable
    assign m_en = (mode == M_MODE);
    assign s_en = (mode == S_MODE || mode == M_MODE);
    assign u_en = (mode == U_MODE || mode == S_MODE || mode == M_MODE);

    // m/s cause
    logic mcause_valid, scause_valid;
    always_comb begin
        case (tmp[`CAUSE_EXCEPTION_CODE])            
            `EXCEPTION_CODE_M_TIME_INTERRUPT,
            `EXCEPTION_CODE_ECALL_M_MODE: begin
                mcause_valid = 1'b1;
                scause_valid = 1'b0;
            end
            // `EXCEPTION_CODE_U_TIME_INTERRUPT,
            `EXCEPTION_CODE_S_TIME_INTERRUPT,
            `EXCEPTION_CODE_ECALL_U_MODE,
            `EXCEPTION_CODE_ECALL_S_MODE,
            `EXCEPTION_CODE_INST_PAGE_FAULT,
            `EXCEPTION_CODE_LOAD_PAGE_FAULT,
            `EXCEPTION_CODE_STORE_AMO_PAGE_FAULT: begin
                mcause_valid = 1'b1;
                scause_valid = 1'b1;
            end
            default: begin 
                mcause_valid = 1'b0;
                scause_valid = 1'b0;
            end
        endcase
    end

    always_comb begin
        wdata = rdata; // initialize
        case (waddr)
            `CSR_MHARTID: ;               // read only
            `CSR_MTVEC: begin             // mtvec_mode: direct(00) / vectored(01) 
                if (m_en) begin
                    wdata[`TVEC_BASE] = tmp[`TVEC_BASE];
                    if (tmp[`TVEC_MODE] == MODE_DIRECT || tmp[`TVEC_MODE] == MODE_VECTORED) begin
                        wdata[`TVEC_MODE] = tmp[`TVEC_MODE];
                    end
                end
            end   
            `CSR_MEPC: begin              // assign mepc[1:0] = 0
                if (m_en) begin           // TODO: check valid physical and virtual address
                    wdata = tmp & ~2'b11;
                end
            end 
            /* only support: 
                interrupt(31)   exception_code(30:0)            description
                    1                 5                  Supervisor timer interrupt
                    1                 7                     Machine timer interrupt
                    0                 9                 Environment call from S-mode     
                    0                 11                Environment call from M-mode     
                    0                 12                Instruction page fault    
                    0                 13                       Load page fault
                    0                 15                  Store/AMO page fault
            */       
            `CSR_MCAUSE: begin   
                if (m_en) begin
                    wdata[`CAUSE_INTERRUPT] = tmp[`CAUSE_INTERRUPT];
                    if (mcause_valid)
                        wdata[`CAUSE_EXCEPTION_CODE] = tmp[`CAUSE_EXCEPTION_CODE];    
                end
            end                                                                   
            `CSR_MSTATUS: begin           //
                if (m_en) begin
                    wdata[`MSTATUS_SIE] = tmp[`MSTATUS_SIE];
                    wdata[`MSTATUS_MIE] = tmp[`MSTATUS_MIE];
                    wdata[`MSTATUS_SPIE] = tmp[`MSTATUS_SPIE];
                    if (tmp[`MSTATUS_MPIE] != 2'b10) wdata[`MSTATUS_MPIE] =  tmp[`MSTATUS_MPIE];
                    wdata[`MSTATUS_SPP] = tmp[`MSTATUS_SPP];
                    if (tmp[`MSTATUS_MPP] != 2'b10) wdata[`MSTATUS_MPP] = tmp[`MSTATUS_MPP];
                    wdata[`MSTATUS_SUM] = tmp[`MSTATUS_SUM];
                end
            end
            `CSR_MSCRATCH: begin          // read/write
                if (m_en) begin
                    wdata = tmp;
                end
            end
            `CSR_MIE: begin               // MTIE, STIE: read/write
                if (m_en) begin
                    wdata[`MIE_MTIE] = tmp[`MIE_MTIE];
                    wdata[`MIE_STIE] = tmp[`MIE_STIE];
                end
            end
            `CSR_MIP: begin               // MTIP: read only  STIP: read/write
                if (m_en) begin
                    wdata[`MIP_STIP] = tmp[`MIP_STIP];
                end
            end
            `CSR_MTVAL: begin             // read/write
                if (m_en) begin
                    wdata = tmp;
                end
            end
            `CSR_MIDELEG: begin           // s-mode only support: u-time-interrupt, s-time-interrupt 
                if (m_en) begin
                    // wdata[`EXCEPTION_CODE_U_TIME_INTERRUPT] = tmp[`EXCEPTION_CODE_U_TIME_INTERRUPT];
                    wdata[`EXCEPTION_CODE_S_TIME_INTERRUPT] = tmp[`EXCEPTION_CODE_S_TIME_INTERRUPT];
                end
            end
            `CSR_MEDELEG: begin           // s-mode only support: ebreak, ecall-u-mode, ecall-s-mode, inst-page-fault, load-page-fault, store-amo-page-fault
                if (m_en) begin
                    wdata[`EXCEPTION_CODE_BREAKPOINT] = tmp[`EXCEPTION_CODE_BREAKPOINT];
                    wdata[`EXCEPTION_CODE_ECALL_U_MODE] = tmp[`EXCEPTION_CODE_ECALL_U_MODE];
                    wdata[`EXCEPTION_CODE_ECALL_S_MODE] = tmp[`EXCEPTION_CODE_ECALL_S_MODE];
                    wdata[`EXCEPTION_CODE_INST_PAGE_FAULT] = tmp[`EXCEPTION_CODE_INST_PAGE_FAULT];
                    wdata[`EXCEPTION_CODE_LOAD_PAGE_FAULT] = tmp[`EXCEPTION_CODE_LOAD_PAGE_FAULT];
                    wdata[`EXCEPTION_CODE_STORE_AMO_PAGE_FAULT] = tmp[`EXCEPTION_CODE_STORE_AMO_PAGE_FAULT];
                end
            end
            `CSR_RDTIME:  ;               // read only
            `CSR_RDTIMEH: ;               // read only
            `CSR_STVEC: begin             // stvec_mode: direct(00) / vectored(01) 
                if (s_en) begin
                    wdata[`TVEC_BASE] = tmp[`TVEC_BASE];
                    if (tmp[`TVEC_MODE] == MODE_DIRECT || tmp[`TVEC_MODE] == MODE_VECTORED) begin
                        wdata[`TVEC_MODE] = tmp[`TVEC_MODE];
                    end
                end
            end
            `CSR_SEPC: begin              // assign sepc[1:0] = 0
                if (s_en) begin
                    wdata = tmp & ~2'b11; // TODO: check valid physical and virtual address
                end
            end
            `CSR_SCAUSE: begin            // same with mcause
                if (s_en) begin
                    wdata[`CAUSE_INTERRUPT] = tmp[`CAUSE_INTERRUPT];
                    if (scause_valid)
                        wdata[`CAUSE_EXCEPTION_CODE] = tmp[`CAUSE_EXCEPTION_CODE];   
                end
            end
            `CSR_SSTATUS: begin           // 
                if (s_en) begin
                    wdata[`SSTATUS_SIE] = tmp[`SSTATUS_SIE];
                    wdata[`SSTATUS_SPIE] = tmp[`SSTATUS_SPIE];
                    wdata[`SSTATUS_SPP] = tmp[`SSTATUS_SPP];
                    wdata[`SSTATUS_SUM] = tmp[`SSTATUS_SUM]; // TODO: can S-mode write this bit?
                end
            end
            `CSR_SSCRATCH: begin          // read/write
                if (s_en) begin
                    wdata = tmp;
                end
            end
            `CSR_SIE: begin               // STIE: read/write
                if (s_en) begin
                    wdata[`SIE_STIE] = tmp[`SIE_STIE];
                end
            end
            `CSR_SIP: begin               // STIP: read only
                // nothing can be changed
            end
            `CSR_STVAL: begin             // read/write
                if (s_en) begin
                    wdata = tmp;
                end
            end
            `CSR_PMPCFG0: begin           // arbitrary read/write (ignore)
                wdata = tmp;
            end
            `CSR_PMPADDR0: begin          // arbitrary read/write (ignore)
                wdata = tmp;
            end
            default: ;       // do not change anything
        endcase
    end

endmodule