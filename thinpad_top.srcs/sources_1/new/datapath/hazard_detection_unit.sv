`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module hazard_detection_unit(
    input wire [`INST_BUS] id_inst,
    
    input wire ex_wb_ren,
    input wire ex_rf_wen, 
    input wire [`REG_ADDR_BUS] ex_rf_waddr,

    input wire branch,
    input wire [`ADDR_BUS] ex_inst,
    input wire [`ADDR_BUS] mem_inst,
    input wire [`ADDR_BUS] wb_inst,
    
    // csr
    input wire id_inst_page_fault,
    input wire mem_load_page_fault,
    input wire mem_store_page_fault,

    input wire [`CSR_SEL_WIDTH-1:0] id_csr_inst_sel,
    input wire [`CSR_SEL_WIDTH-1:0] ex_csr_inst_sel,
    input wire [`CSR_SEL_WIDTH-1:0] mem_csr_inst_sel,
    input wire [`CSR_SEL_WIDTH-1:0] wb_csr_inst_sel, 

    output reg if_id_flush,
    output reg id_ex_flush,
    output reg ex_mem_flush,
    output reg mem_wb_flush,

    output reg if_id_hold,
    output reg id_ex_hold
);

    /*                      ========>    branch  <===========
        if      |      id        |      ex         |       mem             |      wb
     page fault |   ecall        |     ecall       |   page fault / ecall  |     ecall
                          timer interrupt

        所有异常相关的问题, 都在wb阶段跳转   
        if/mem读到page-fault后, 清空前面所有流水线, 直到wb阶段发生跳转
        只要id/ex/mem/wb有ecall, 就往if_id插气泡     
        wb 判断到ecall 时，给if_id插气泡, 给if_master另一个pc_branch     
    */

    /*
        mem page fault: (优先级高) —— mem_wb时, 所有使能都为0, wb_inst_sel = LOAD/STORE_PAGE_FAULT (在id_ex做判断)
        1. mem阶段: 向if_id id_ex ex_mem插气泡
        2. wb阶段: 向if_id插气泡

        if page fault: (优先级低) —— 译码时, 所有使能都为0, ex_inst_sel = INST_PAGE_FAULT (在id_ex做判断)
        1. if阶段: 忽略
        2. id阶段: 向if_id插气泡
        3. ex阶段: 向if_id插气泡
        4. mem阶段: 向if_id插气泡
        5. wb阶段: 向if_id插气泡

        以上: 插气泡时, 令 if_id_hold = 1
    */

    logic ex_hazard;
    assign ex_hazard = ex_rf_wen & (ex_rf_waddr == id_inst[24:20] | ex_rf_waddr == id_inst[19:15]);   

    logic load_hazard;
    assign load_hazard = ex_wb_ren & ex_hazard;

    logic id_csr_branch, ex_csr_branch, mem_csr_branch, wb_csr_branch, csr_branch; 
    assign id_csr_branch = ((id_csr_inst_sel == ECALL) || (id_csr_inst_sel == EBREAK) || (id_csr_inst_sel == MRET) || (id_csr_inst_sel == SRET) ||
                            id_inst_page_fault);
    assign ex_csr_branch = ((ex_csr_inst_sel == ECALL) || (ex_csr_inst_sel == EBREAK) || (ex_csr_inst_sel == MRET) || (ex_csr_inst_sel == SRET) ||
                            (ex_csr_inst_sel == M_TIME_INTERRUPT) || (ex_csr_inst_sel == S_TIME_INTERRUPT) || 
                            (mem_csr_inst_sel == INST_PAGE_FAULT));
    assign mem_csr_branch = ((mem_csr_inst_sel == ECALL) || (mem_csr_inst_sel == EBREAK) || (mem_csr_inst_sel == MRET) || (mem_csr_inst_sel == SRET) || 
                            (mem_csr_inst_sel == M_TIME_INTERRUPT) || (mem_csr_inst_sel == S_TIME_INTERRUPT) ||
                            (mem_csr_inst_sel == INST_PAGE_FAULT) || mem_load_page_fault || mem_store_page_fault);
    assign wb_csr_branch = ((wb_csr_inst_sel == ECALL) || (wb_csr_inst_sel == EBREAK) || (wb_csr_inst_sel == MRET) || (wb_csr_inst_sel == SRET) || 
                            (wb_csr_inst_sel == M_TIME_INTERRUPT) || (wb_csr_inst_sel == S_TIME_INTERRUPT) ||
                            (wb_csr_inst_sel == INST_PAGE_FAULT) || (wb_csr_inst_sel == LOAD_PAGE_FAULT) || (wb_csr_inst_sel == STORE_PAGE_FAULT));

    logic priv_hazard;
    assign priv_hazard = (id_csr_inst_sel != CSR_INST_NOP || id_inst_page_fault) && (ex_inst != `INST_NOP || mem_inst != `INST_NOP || wb_inst != `INST_NOP);
    
    always_comb begin
        if (wb_csr_branch) begin  // 最优先wb阶段跳转 ecall ebreak mret sret m_time_interrupt s_time_interrupt inst_page_fault load_page_fault store_page_fault
            if_id_flush = `ENABLE;
            if_id_hold = `ENABLE;

            id_ex_flush = `ENABLE;
            id_ex_hold = `DISABLE;

            ex_mem_flush = `ENABLE;
            mem_wb_flush = `ENABLE;
        end else if (mem_csr_branch) begin // mem page fault, ex跳转也没用, 前面的阶段直接清空
            if_id_flush = `ENABLE;
            if_id_hold = `ENABLE; 

            id_ex_flush = `ENABLE;
            id_ex_hold = `DISABLE;

            ex_mem_flush = `ENABLE;
            mem_wb_flush = `DISABLE;
        end else if (branch || ex_csr_branch) begin  // ex阶段的跳转
            if_id_flush = `ENABLE;
            if_id_hold = `ENABLE; 

            id_ex_flush = `ENABLE; 
            id_ex_hold = `DISABLE;

            ex_mem_flush = `DISABLE;
            mem_wb_flush = `DISABLE;
        end else if (priv_hazard) begin     // 无跳转, id阶段csr指令, 让id后面的阶段排空, 
                                            // 此时可能发生time_interrupt (id_ex时, time_interrupt优先级更高, 所以流水线又会存在非空指令)
                                            // 当全部为空时, 才能执行CSR指令
            if_id_flush = `DISABLE;  
            if_id_hold = `ENABLE;

            id_ex_flush = `ENABLE;
            id_ex_hold = `DISABLE;

            ex_mem_flush = `DISABLE;
            mem_wb_flush = `DISABLE;
        end else if (load_hazard) begin
            if_id_flush = `DISABLE;
            if_id_hold = `ENABLE;

            id_ex_flush = `ENABLE;
            id_ex_hold = `DISABLE;

            ex_mem_flush = `DISABLE;
            mem_wb_flush = `DISABLE;
        end else begin
            if_id_flush = `DISABLE;
            id_ex_flush = `DISABLE;
            if_id_hold = `DISABLE;
            id_ex_hold = `DISABLE;
            ex_mem_flush = `DISABLE;
            mem_wb_flush = `DISABLE;
        end
    end

    


endmodule