`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module hazard_detection_unit(
    input wire [`INST_BUS] id_inst,
    
    input wire ex_wb_ren,
    input wire ex_rf_wen, 
    input wire [`REG_ADDR_BUS] ex_rf_waddr,

    input wire branch,

    // 有ECALL EBREAK MRET, 直接给if_id插气泡
    input wire [`CSR_SEL_WIDTH-1:0] id_csr_inst_sel,
    input wire [`CSR_SEL_WIDTH-1:0] ex_csr_inst_sel,
    input wire [`CSR_SEL_WIDTH-1:0] mem_csr_inst_sel,
    input wire [`CSR_SEL_WIDTH-1:0] wb_csr_inst_sel, 

    output reg if_id_flush,
    output reg id_ex_flush,

    output reg if_id_hold,
    output reg id_ex_hold
);

    logic ex_hazard;
    assign ex_hazard = ex_rf_wen & (ex_rf_waddr == id_inst[24:20] | ex_rf_waddr == id_inst[19:15]);   

    logic load_hazard;
    assign load_hazard = ex_wb_ren & ex_hazard;

    // id遇到CSR指令, 首先让后面全部bubble, 然后再执行CSR指令
    logic priv_hazard;
    assign priv_hazard = (id_csr_inst_sel && (ex_csr_inst_sel != 0 || mem_csr_inst_sel != 0 || wb_csr_inst_sel));

    logic id_csr_branch, ex_csr_branch, mem_csr_branch, wb_csr_branch, csr_branch; 
    assign id_csr_branch = ((id_csr_inst_sel == ECALL) || (id_csr_inst_sel == EBREAK) || (id_csr_inst_sel == MRET) || (id_csr_inst_sel == SRET) || (id_csr_inst_sel == TIME_INTERRUPT));
    assign ex_csr_branch = ((ex_csr_inst_sel == ECALL) || (ex_csr_inst_sel == EBREAK) || (ex_csr_inst_sel == MRET) || (ex_csr_inst_sel == SRET) || (ex_csr_inst_sel == TIME_INTERRUPT));
    assign mem_csr_branch = ((mem_csr_inst_sel == ECALL) || (mem_csr_inst_sel == EBREAK) || (mem_csr_inst_sel == MRET) || (mem_csr_inst_sel == SRET) || (mem_csr_inst_sel == TIME_INTERRUPT));
    assign wb_csr_branch = ((wb_csr_inst_sel == ECALL) || (wb_csr_inst_sel == EBREAK) || (wb_csr_inst_sel == MRET) || (wb_csr_inst_sel == SRET) || (wb_csr_inst_sel == TIME_INTERRUPT));
    assign csr_branch = id_csr_branch | ex_csr_branch | mem_csr_branch | wb_csr_branch;
    
    always_comb begin
        if (priv_hazard) begin
            if_id_flush = `DISABLE;
            if_id_hold = `ENABLE;  // hold if master and if-id

            id_ex_flush = `ENABLE; // flush id-ex
            id_ex_hold = `DISABLE;
        end else if (branch) begin
            if_id_flush = `ENABLE; // flush if-id
            if_id_hold = `ENABLE;  // hold if master

            id_ex_flush = `ENABLE; // flush id-ex
            id_ex_hold = `DISABLE;
        end else if (csr_branch) begin
            if_id_flush = `ENABLE; // flush if-id
            if_id_hold = `ENABLE;  // hold if master

            id_ex_flush = `DISABLE;
            id_ex_hold = `DISABLE;
        end else if (load_hazard) begin
            if_id_flush = `DISABLE;
            if_id_hold = `ENABLE; // hold if master and if-id

            id_ex_flush = `ENABLE; // flush id-ex
            id_ex_hold = `DISABLE;
        end else begin
            if_id_flush = `DISABLE;
            id_ex_flush = `DISABLE;
            if_id_hold = `DISABLE;
            id_ex_hold = `DISABLE;
        end
    end

endmodule