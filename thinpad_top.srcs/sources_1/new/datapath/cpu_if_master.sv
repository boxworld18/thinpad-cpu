`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module cpu_if_master(
    input wire clk,
    input wire rst,
    input wire stall,
    input wire hold,

    input wire branch,
    input wire [`ADDR_BUS] pc_branch,

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
    output reg [`ADDR_BUS] pc,
    output reg if_master_stall,

    //inst_cache
    output reg [`ADDR_BUS] inst_cache_addr_o,
    output reg [`INST_BUS] inst_cache_data_o,
    output reg is_add_o,
    input wire [`INST_BUS] inst_cache_data_i,
    input wire is_hit_i
);

    logic [`ADDR_BUS] pc_reg;

    typedef enum logic [1:0] {
        IDLE = 0,
        QUERY_CACHE = 1,
        READ_DATA_ACTION = 2
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
            inst_cache_addr_o <= 32'h0000_0000;
            inst_cache_data_o <= 32'h0000_0000;
            is_add_o <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (!stall) begin
                        pc_reg <= branch ? pc_branch : pc_reg + 4;
                        if_master_stall <= 1'b1;
                        inst_cache_addr_o <= branch ? pc_branch : pc_reg + 4;
                        is_add_o <= 1'b0;
                        inst_cache_data_o <= 32'h0000_0000;
                        state <= QUERY_CACHE;
                    end
                end
                QUERY_CACHE: begin
                    if (is_hit_i) begin
                        inst <= inst_cache_data_i;
                        pc <= pc_reg;
                        if (hold) begin
                            pc_reg <= pc_reg - 4;
                        end
                        if_master_stall <= 1'b0;
                        state <= IDLE;
                    end else begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= pc_reg;
                        wb_dat_o <= 32'h0000_0000;
                        wb_sel_o <= 4'hF;
                        wb_we_o <= 1'b0;
                        state <= READ_DATA_ACTION;
                    end
                end
                READ_DATA_ACTION: begin
                    if (wb_ack_i) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        pc <= pc_reg;
                        inst <= wb_dat_i;
                        is_add_o <= 1'b1;
                        inst_cache_data_o <= wb_dat_i;
                        inst_cache_addr_o <= pc_reg;
                        if (hold) begin
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