`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module cpu_mem_master(
    input wire clk,
    input wire rst,
    input wire [`ADDR_BUS] addr,
    input wire [`DATA_BUS] data,
    input wire wen,
    input wire ren,
    input wire [`SEL] sel,
    input wire read_unsigned,

    // master
    input wire wb_ack_i,
    input wire [`DATA_BUS] wb_dat_i,
    
    output reg wb_cyc_o,
    output reg wb_stb_o,
    output reg [`ADDR_BUS] wb_adr_o,
    output reg [`DATA_BUS] wb_dat_o,
    output reg [`SEL] wb_sel_o,
    output reg wb_we_o,

    // cpu mem
    output reg [`DATA_BUS] mem_read_data,
    output reg mem_master_stall
);

    typedef enum logic [1:0] {
        IDLE,
        READ_DATA_ACTION,
        WRITE_DATA_ACTION
    } state_t;
    state_t state;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            wb_stb_o <= 1'b0;
            wb_cyc_o <= 1'b0;
            wb_adr_o <= 0;
            wb_sel_o <= 0;
            wb_we_o <= 1'b0;
            mem_read_data <= 0;
            mem_master_stall <= 1'b0;
        end else begin
            case (state)
               IDLE: begin     
                    if (ren) begin
                        state <= READ_DATA_ACTION;
                        wb_stb_o <= 1'b1;
                        wb_cyc_o <= 1'b1;
                        wb_adr_o <= addr;
                        wb_sel_o <= (sel << addr[1:0]);
                        wb_we_o <= 1'b0;
                        mem_master_stall <= 1'b1;
                    end else if (wen) begin
                        state <= WRITE_DATA_ACTION;
                        wb_stb_o <= 1'b1;
                        wb_cyc_o <= 1'b1;
                        wb_adr_o <= addr;
                        wb_dat_o <= data;
                        wb_sel_o <= (sel << addr[1:0]);
                        wb_we_o <= 1'b1;    
                        mem_master_stall <= 1'b1;
                    end else begin
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        wb_we_o <= 1'b0;    
                        mem_master_stall <= 1'b0;
                    end       
                end
                READ_DATA_ACTION: begin
                    if (wb_ack_i) begin
                        state <= IDLE;    
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        mem_master_stall <= 1'b0;
                        case (wb_sel_o) 
                            4'b0001: mem_read_data <= {24'b0, wb_dat_i[7:0]};
                            4'b0010: mem_read_data <= {24'b0, wb_dat_i[15:8]};
                            4'b0100: mem_read_data <= {24'b0, wb_dat_i[23:16]};
                            4'b1000: mem_read_data <= {24'b0, wb_dat_i[31:24]};
                            4'b1111: mem_read_data <= wb_dat_i;
                            default: mem_read_data <= 0;
                        endcase
                    end
                end
                WRITE_DATA_ACTION: begin
                    if (wb_ack_i) begin
                        state <= IDLE;
                        mem_master_stall <= 1'b0;
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        wb_we_o <= 1'b0;
                    end
                end
            endcase
        end
    end

    

endmodule