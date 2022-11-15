`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module hazard_detection_unit(
    input wire [`INST_BUS] id_inst,
    input wire [2:0] imm_type,
    
    input wire ex_wb_ren,
    
    input wire ex_rf_wen, 
    input wire [`REG_ADDR_BUS] ex_rf_waddr,
    input wire mem_rf_wen,
    input wire [`REG_ADDR_BUS] mem_rf_waddr,
    input wire wb_rf_wen,
    input wire [`REG_ADDR_BUS] wb_rf_waddr,

    output wire hazard
);

    // 简单版, 一直插气泡
    logic ex_hazard, mem_hazard, wb_hazard, branch_hazard;
    assign ex_hazard = ex_rf_wen & (ex_rf_waddr == id_inst[24:20] | ex_rf_waddr == id_inst[19:15]);
    assign mem_hazard = mem_rf_wen & (mem_rf_waddr == id_inst[24:20] | mem_rf_waddr == id_inst[19:15]);
    assign wb_hazard = wb_rf_wen & (wb_rf_waddr == id_inst[24:20] | wb_rf_waddr == id_inst[19:15]);
    assign branch_hazard = (imm_type == IMM_SB) & (ex_hazard | mem_hazard | wb_hazard);    

    logic load_hazard;
    assign load_hazard = ex_wb_ren & ex_hazard;

    assign hazard = load_hazard | branch_hazard;


endmodule