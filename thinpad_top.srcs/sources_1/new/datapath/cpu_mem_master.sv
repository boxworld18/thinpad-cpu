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
    input wire read_unsigned, // UNUSED UNCONNECTED
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

    // time
    output reg time_interrupt
);

    typedef enum logic [1:0] {
        IDLE,
        READ_DATA_ACTION,
        WRITE_DATA_ACTION,
        DONE
    } state_t;
    state_t state;

    logic [63:0] mtime;
    logic [63:0] mtimecmp;   

    logic read_time_register;  // 是否读取mtime、mtimecmp寄存器
    logic [`DATA_BUS] time_register_rdata;
    logic write_time_register; // 是否写入mtime、mtimecmp寄存器
    // logic [`SEL] time_sel; // mtime、mtimecmp寄存器的选择信号 (4位) 

    assign time_interrupt = (mtime >= mtimecmp) ? 1'b1 : 1'b0;

    always_comb begin
        case (addr) // 目前只支持4字节访问
            `MTIME_ADDR_LOW: begin
                read_time_register = ren;
                write_time_register = wen;
                time_register_rdata = mtime[31:0];
            end
            `MTIME_ADDR_HIGH: begin
                read_time_register = ren;
                write_time_register = wen;
                time_register_rdata = mtime[63:32];
            end
            `MTIMECMP_ADDR_LOW: begin
                read_time_register = ren;
                write_time_register = wen;
                time_register_rdata = mtimecmp[31:0];
            end
            `MTIMECMP_ADDR_HIGH: begin
                read_time_register = ren;
                write_time_register = wen;
                time_register_rdata = mtimecmp[63:32];
            end
            default: begin
                read_time_register = 1'b0;
                write_time_register = 1'b0;
                time_register_rdata = 0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            mtime <= 0;
            mtimecmp <= 32'h10000;
        end else begin
            if (wen && state == IDLE) begin
                case (addr) // 目前只支持4字节访问
                    `MTIME_ADDR_LOW: begin
                        mtime[31:0] <= data;
                    end
                    `MTIME_ADDR_HIGH: begin
                        mtime[63:32] <= data;
                    end
                    `MTIMECMP_ADDR_LOW: begin
                        mtimecmp[31:0] <= data;
                    end
                    `MTIMECMP_ADDR_HIGH: begin
                        mtimecmp[63:32] <= data;
                    end
                    default: ;
                endcase
            end else begin
                mtime <= mtime + 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            wb_stb_o <= 1'b0;
            wb_cyc_o <= 1'b0;
            wb_adr_o <= 0;
            wb_dat_o <= 0;
            wb_sel_o <= 0;
            wb_we_o <= 1'b0;
            mem_read_data <= 0;
            mem_master_stall <= 1'b0;
        end else begin
            case (state)
               IDLE: begin     
                    if (ren) begin
                        if (read_time_register) begin
                            mem_read_data <= time_register_rdata; 
                            state <= DONE;           
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
                        if (write_time_register) begin
                            state <= DONE;
                        end else begin
                            state <= WRITE_DATA_ACTION;
                            wb_stb_o <= 1'b1;
                            wb_cyc_o <= 1'b1;
                            wb_adr_o <= addr;
                            wb_dat_o <= data;
                            wb_sel_o <= (sel << addr[1:0]);
                            wb_we_o <= 1'b1;    
                            mem_master_stall <= 1'b1;      
                        end                  
                    end else begin
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        wb_we_o <= 1'b0;    
                        mem_master_stall <= 1'b0;
                        state <= DONE;
                    end       
                end
                READ_DATA_ACTION: begin
                    if (wb_ack_i) begin
                        state <= DONE;    
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        mem_master_stall <= 1'b0;
                        case (wb_sel_o) // 不支持 lh lhu
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
                        state <= DONE;
                        mem_master_stall <= 1'b0;
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        wb_we_o <= 1'b0;
                    end
                end
                DONE: begin
                    if (!stall) 
                        state <= IDLE; 
                end
            endcase
        end
    end

    

endmodule