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

    // page fault
    output reg inst_page_fault,
    output reg [`ADDR_BUS] inst_fault_va

    // paging related
    input wire [`DATA_BUS] satp,
    input wire [1:0] mode
);

    logic [`ADDR_BUS] pc_reg;
    logic [`ADDR_BUS] L1_pte;
    logic [`ADDR_BUS] L2_pte;

    logic L1_invalid;
    assign L1_invalid = (L1_pte[`PTE_V] == 0) || (L1_pte[`PTE_R] == 0 && L1_pte[`PTE_W] == 1);
    logic L2_invalid;
    assign L2_invalid = (L2_pte[`PTE_V] == 0) 
                        || (L2_pte[`PTE_R] == 0 && L2_pte[`PTE_W] == 1) 
                        || (L2_pte[`PTE_U] == 0 && mode == U_MODE) 
                        || (L2_pte[`PTE_X] == 0 && L2_pte[`PTE_R] == 0)
                        || (L2_pte[`PTE_A] == 0);

    typedef enum logic [2:0] {
        IDLE = 0,
        L1_FETCH = 1,
        L1_FETCH_DONE = 2,
        L2_FETCH = 3,
        L2_FETCH_DONE = 4,
        FETCH_DONE = 5,
        READ_DATA_ACTION = 6
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
            inst_page_fault <= 1'b0;
            inst_fault_va <= 32'h0000_0000;
            L1_pte <= 32'h0000_0000;
            L2_pte <= 32'h0000_0000;
        end else begin
            case (state)
                IDLE: begin
                    if (!stall) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        if_master_stall <= 1'b1;
                        pc_reg <= branch ? pc_branch : pc_reg + 4;
                        state <= L1_FETCH;
                    end
                end
                L1_FETCH: begin
                    if(mode == M_MODE) begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= pc_reg;
                        wb_sel_o <= 4'hF;
                        wb_we_o <= 1'b0;
                        if_master_stall <= 1'b1;
                        state <= READ_DATA_ACTION;
                    end else begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= satp[`SATP_PPN]<<`PAGE_SIZE + pc_reg[`VA_VPN1]<<PTE_SIZE;
                        wb_sel_o <= 4'hF;
                        wb_we_o <= 1'b0;
                        if_master_stall <= 1'b1;
                        state <= L1_FETCH_DONE;
                    end
                end
                L1_FETCH_DONE: begin
                    if (wb_ack_i) begin
                        L1_pte <= wb_dat_i;
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        state <= L2_FETCH;
                    end
                end
                L2_FETCH: begin
                    if (L1_invalid) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        inst_page_fault <= 1'b1;
                        inst_fault_va <= pc_reg;
                        state <= IDLE;
                    end else begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= L1_pte[`PTE_PPN0]<<`PAGE_SIZE + pc_reg[`VA_VPN0]<<PTE_SIZE;
                        wb_sel_o <= 4'hF;
                        wb_we_o <= 1'b0;
                        if_master_stall <= 1'b1;
                        state <= L2_FETCH_DONE;
                    end
                end
                L2_FETCH_DONE: begin
                    if (wb_ack_i) begin
                        L2_pte <= wb_dat_i;
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        state <= FETCH_DONE;
                    end
                end
                FETCH_DONE: begin
                    if (L2_invalid) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        inst_page_fault <= 1'b1;
                        inst_fault_va <= pc_reg;
                        state <= IDLE;
                    end else begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= {L2_pte[`PTE_PPN1], L2_pte[`PTE_PPN0], pc_reg[11:2], L2_pte[11:10]};
                        wb_sel_o <= 4'hF;
                        wb_we_o <= 1'b0;
                        if_master_stall <= 1'b1;
                        state <= READ_DATA_ACTION;
                    end
                end
                READ_DATA_ACTION: begin
                    if (wb_ack_i) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        pc <= pc_reg;
                        inst <= wb_dat_i; 
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