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
    input wire id_csr_inst_sel,
    input wire ex_csr_inst_sel,
    input wire mem_csr_inst_sel,
    input wire wb_csr_inst_sel, 

    output reg if_id_flush,
    output reg id_ex_flush,

    output reg if_id_hold,
    output reg id_ex_hold
);

    logic ex_hazard;
    assign ex_hazard = ex_rf_wen & (ex_rf_waddr == id_inst[24:20] | ex_rf_waddr == id_inst[19:15]);   

    logic load_hazard;
    assign load_hazard = ex_wb_ren & ex_hazard;

    logic id_csr_branch, ex_csr_branch, mem_csr_branch, wb_csr_branch, csr_branch; 
    assign id_csr_branch = ((id_csr_inst_sel == ECALL) || (id_csr_inst_sel == EBREAK) || (id_csr_inst_sel == MRET));
    assign ex_csr_branch = ((ex_csr_inst_sel == ECALL) || (ex_csr_inst_sel == EBREAK) || (ex_csr_inst_sel == MRET));
    assign mem_csr_branch = ((mem_csr_inst_sel == ECALL) || (mem_csr_inst_sel == EBREAK) || (mem_csr_inst_sel == MRET));
    assign wb_csr_branch = ((wb_csr_inst_sel == ECALL) || (wb_csr_inst_sel == EBREAK) || (wb_csr_inst_sel == MRET));
    assign csr_branch = id_csr_branch | ex_csr_branch | mem_csr_branch | wb_csr_branch;
    
    always_comb begin
        if (branch | csr_branch) begin
            if_id_flush = `ENABLE;
            id_ex_flush = `ENABLE;
            if_id_hold = `DISABLE;
            id_ex_hold = `DISABLE;
        end else if (load_hazard) begin
            if_id_flush = `DISABLE;
            id_ex_flush = `ENABLE;
            if_id_hold = `ENABLE;
            id_ex_hold = `DISABLE;
        end else begin
            if_id_flush = `DISABLE;
            id_ex_flush = `DISABLE;
            if_id_hold = `DISABLE;
            id_ex_hold = `DISABLE;
        end
    end

endmodule