`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module cpu_if_master(
    input wire clk,
    input wire rst,
    input wire hazard,
    input wire flush,
    input wire stall,

    input wire pc_sel,
    input wire [`ADDR_BUS] pc_branch,
    output reg [`ADDR_BUS] pc,

    // master
    input wire wb_ack_i,
    input wire [`DATA_BUS] wb_dat_i,
    
    output reg wb_cyc_o,
    output reg wb_stb_o,
    output reg [`ADDR_BUS] wb_adr_o,
    output reg [`DATA_BUS] wb_dat_o,
    output reg [`SEL] wb_sel_o,
    output reg wb_we_o,

    // cpu if
    output reg [`INST_BUS] inst,
    output reg [`ADDR_BUS] pc_old,
    output reg if_master_stall
);

    logic [`ADDR_BUS] pc_reg;

    typedef enum logic [1:0] {
        IDLE,
        READ_DATA_ACTION,
        READ_DONE
    } state_t;
    state_t state;

    always_ff @(posedge clk) begin
        if (rst) begin
            wb_cyc_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_adr_o <= 32'h0000_0000;
            wb_dat_o <= 32'h0000_0000;
            wb_sel_o <= 4'h0;
            wb_we_o <= 1'b0;
            inst <= 32'h0000_0000;
            pc_reg <= `PC_RESET - 4;
            pc <= `PC_RESET;
            if_master_stall <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (!stall) begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= pc_sel ? pc_branch : pc_reg + 4;
                        wb_sel_o <= 4'hF;
                        if_master_stall <= 1'b1;
                        pc_reg <= pc_sel ? pc_branch : pc_reg + 4;
                        state <= READ_DATA_ACTION;
                    end
                end
                READ_DATA_ACTION: begin
                    if (wb_ack_i) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        if (flush) begin
                            pc <= `ZERO_WORD;
                            inst <= `ZERO_WORD;
                        end else if (!hazard) begin
                            pc <= pc_reg;
                            inst <= wb_dat_i;    
                        end else begin
                            pc_reg <= pc_reg - 4;
                        end
                        if_master_stall <= 1'b0;
                        state <= IDLE;
                    end
                end
                default: ;
            endcase
        end
    end

    

endmodule