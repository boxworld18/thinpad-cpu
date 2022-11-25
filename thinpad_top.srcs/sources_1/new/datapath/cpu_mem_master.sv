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

    input wire stall,

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
    output reg mem_master_stall,

    // data cache
    output reg [`ADDR_BUS] data_cache_addr_o,
    output reg [`DATA_BUS] data_cache_data_o,
    output reg is_add_o,
    input wire [`DATA_BUS] data_cache_data_i,
    input wire is_hit_i
);

    typedef enum logic [2:0] {
        IDLE = 0,
        QUERY_CACHE = 1,
        READ_DATA_ACTION = 2,
        WRITE_DATA_ACTION = 3,
        DONE = 4
    } state_t;
    state_t state;

    logic highest_bit;
    assign highest_bit = addr[`ADDR_WIDTH-1];

    logic [`ADDR_BUS] addr_cache;

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
            data_cache_addr_o <= 0;
            data_cache_data_o <= 0;
            is_add_o <= 1'b0;
        end else begin
            case (state)
               IDLE: begin
                    is_add_o <= 1'b0;
                    if (ren) begin
                        if(highest_bit) begin
                            state <= QUERY_CACHE;
                            wb_stb_o <= 1'b0;
                            wb_cyc_o <= 1'b0;
                            wb_we_o <= 1'b0;
                            mem_master_stall <= 1'b1;
                            data_cache_addr_o <= addr;
                            addr_cache <= addr;
                        end else begin
                            state <= READ_DATA_ACTION;
                            wb_stb_o <= 1'b1;
                            wb_cyc_o <= 1'b1;
                            wb_adr_o <= addr;
                            wb_sel_o <= (sel << addr[1:0]);
                            wb_we_o <= 1'b0;
                            mem_master_stall <= 1'b1;
                        end
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
                QUERY_CACHE: begin
                    if (is_hit_i) begin
                        state <= DONE;
                        case(sel << addr[1:0])
                            4'b0001: mem_read_data <= {24'b0, data_cache_data_i[7:0]};
                            4'b0010: mem_read_data <= {24'b0, data_cache_data_i[15:8]};
                            4'b0100: mem_read_data <= {24'b0, data_cache_data_i[23:16]};
                            4'b1000: mem_read_data <= {24'b0, data_cache_data_i[31:24]};
                            4'b1111: mem_read_data <= data_cache_data_i;
                            default: mem_read_data <= 0;
                        endcase
                        mem_master_stall <= 1'b0;
                    end else begin
                        state <= READ_DATA_ACTION;
                        wb_stb_o <= 1'b1;
                        wb_cyc_o <= 1'b1;
                        wb_adr_o <= addr_cache;
                        wb_sel_o <= (sel << addr[1:0]);
                        wb_we_o <= 1'b0;
                        mem_master_stall <= 1'b1;
                    end
                end
                READ_DATA_ACTION: begin
                    if (wb_ack_i) begin
                        state <= DONE;
                        
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
                        if(highest_bit) begin
                            data_cache_addr_o <= addr_cache;
                            data_cache_data_o <= wb_dat_i;
                            is_add_o <= 1'b1;
                        end
                    end
                end
                WRITE_DATA_ACTION: begin
                    if (wb_ack_i) begin
                        state <= DONE;
                        mem_master_stall <= 1'b0;
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        wb_we_o <= 1'b0;
                        
                        if(highest_bit) begin
                            data_cache_addr_o <= addr;
                            data_cache_data_o <= data;
                            is_add_o <= 1'b1;
                        end
                    end
                end
                DONE: begin
                    is_add_o <= 1'b0;
                    if (!stall) begin
                        state <= IDLE;
                    end
                end
                default: ;
                
            endcase
        end
    end

    

endmodule