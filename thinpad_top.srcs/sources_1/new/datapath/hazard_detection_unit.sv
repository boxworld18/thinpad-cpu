`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module hazard_detection_unit(
    input wire [`INST_BUS] id_inst,
    
    input wire ex_wb_ren,
    input wire ex_rf_wen, 
    input wire [`REG_ADDR_BUS] ex_rf_waddr,

    input wire branch,

    output reg if_id_flush,
    output reg id_ex_flush,

    output reg if_id_hold,
    output reg id_ex_hold
);

    logic ex_hazard;
    assign ex_hazard = ex_rf_wen & (ex_rf_waddr == id_inst[24:20] | ex_rf_waddr == id_inst[19:15]);   

    logic load_hazard;
    assign load_hazard = ex_wb_ren & ex_hazard;

    always_comb begin
        if (branch) begin
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