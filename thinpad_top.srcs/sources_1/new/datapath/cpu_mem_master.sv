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
    output wire [63:0] mtime_o,
    output wire [63:0] mtimecmp_o,

    // page fault
    output reg load_page_fault,
    output reg [`ADDR_BUS] load_fault_va, 
    output reg store_page_fault,
    output reg [`ADDR_BUS] store_fault_va

    // paging related
    input wire [`DATA_BUS] satp,
    input wire [1:0] mode
);

    typedef enum logic [3:0] {
        IDLE = 0,
        L1_FETCH = 1,
        L1_FETCH_DONE = 2,
        L2_FETCH = 3,
        L2_FETCH_DONE = 4,
        FETCH_DONE = 5,
        READ_DATA_ACTION = 6,
        WRITE_DATA_ACTION = 7,
        DONE = 8
    } state_t;
    state_t state;

    logic [63:0] mtime;
    logic [63:0] mtimecmp;   

    assign mtime_o = mtime;
    assign mtimecmp_o = mtimecmp;

    logic read_time_register;  // 是否读取mtime、mtimecmp寄存器
    logic [`DATA_BUS] time_register_rdata;
    logic write_time_register; // 是否写入mtime、mtimecmp寄存器
    // logic [`SEL] time_sel; // mtime、mtimecmp寄存器的选择信号 (4位) 

    logic [`DATA_BUS] data_shift;
    assign data_shift = addr[1:0] << 3;

    logic is_read;
    logic [`ADDR_BUS] L1_PTE;
    logic [`ADDR_BUS] L2_PTE;
    logic [`ADDR_BUS] VA;

    logic L1_invalid;
    assign L1_invalid = (L1_pte[`PTE_V] == 0) || (L1_pte[`PTE_R] == 0 && L1_pte[`PTE_W] == 1);
    logic L2_invalid;
    assign L2_invalid = (L2_pte[`PTE_V] == 0) 
                        || (L2_pte[`PTE_R] == 0 && L2_pte[`PTE_W] == 1) 
                        || (L2_pte[`PTE_U] == 0 && mode == U_MODE) 
                        || (L2_pte[`PTE_X] == 0 && L2_pte[`PTE_R] == 0);

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
            load_page_fault <= 1'b0;
            load_fault_va <= 0;
            store_page_fault <= 1'b0;
            store_fault_va <= 0;
            is_read <= 1'b0;
            L1_PTE <= 0;
            L2_PTE <= 0;
        end else begin
            case (state)
               IDLE: begin     
                    if (ren) begin
                        if (read_time_register) begin
                            mem_read_data <= time_register_rdata; 
                            state <= DONE;           
                        end else begin
                            // is_read <= 1'b1;
                            // state <= READ_DATA_ACTION;
                            // wb_stb_o <= 1'b1;
                            // wb_cyc_o <= 1'b1;
                            // wb_adr_o <= addr;
                            // wb_sel_o <= (sel << addr[1:0]);
                            // wb_we_o <= 1'b0;
                            // mem_master_stall <= 1'b1;
                            is_read <= 1'b1;
                            state <= L1_FETCH;
                            wb_cyc_o <= 1'b0;
                            wb_stb_o <= 1'b0;
                            mem_master_stall <= 1'b1;
                            VA <= addr;
                        end
                    end else if (wen) begin
                        if (write_time_register) begin
                            state <= DONE;
                        end else begin
                            // is_read <= 1'b0;
                            // state <= WRITE_DATA_ACTION;
                            // wb_stb_o <= 1'b1;
                            // wb_cyc_o <= 1'b1;
                            // wb_adr_o <= addr;
                            // wb_dat_o <= data << data_shift;
                            // wb_sel_o <= (sel << addr[1:0]);
                            // wb_we_o <= 1'b1;    
                            // mem_master_stall <= 1'b1;    
                            is_read <= 1'b0;
                            state <= L1_FETCH;
                            wb_cyc_o <= 1'b0;
                            wb_stb_o <= 1'b0;
                            mem_master_stall <= 1'b1;
                            VA <= addr;
                        end                  
                    end else begin
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        wb_we_o <= 1'b0;    
                        mem_master_stall <= 1'b0;
                        state <= DONE;
                    end       
                end
                L1_FETCH: begin
                    if(mode == M_MODE) begin
                        if(is_read) begin
                            state <= READ_DATA_ACTION;
                            wb_stb_o <= 1'b1;
                            wb_cyc_o <= 1'b1;
                            wb_adr_o <= VA;
                            wb_sel_o <= (sel << VA[1:0]);
                            wb_we_o <= 1'b0;
                            mem_master_stall <= 1'b1;
                        end else begin
                            state <= WRITE_DATA_ACTION;
                            wb_stb_o <= 1'b1;
                            wb_cyc_o <= 1'b1;
                            wb_adr_o <= VA;
                            wb_dat_o <= data << data_shift;
                            wb_sel_o <= (sel << VA[1:0]);
                            wb_we_o <= 1'b1;    
                            mem_master_stall <= 1'b1;    
                        end
                    end else begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= satp[`SATP_PPN]<<`PAGE_SIZE + VA[`VA_VPN1]<<PTE_SIZE;
                        wb_sel_o <= 4'hF;
                        wb_we_o <= 1'b0;
                        mem_master_stall <= 1'b1;
                        state <= L1_FETCH_DONE;
                    end
                end
                L1_FETCH_DONE: begin
                    if(wb_ack_i) begin
                        L1_pte <= wb_dat_i;
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        state <= L2_FETCH;
                    end
                end
                L2_FETCH: begin
                    if(L1_invalid) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        load_page_fault <= 1'b1;
                        load_fault_va <= VA;
                        state <= DONE;
                    end else begin
                        wb_cyc_o <= 1'b1;
                        wb_stb_o <= 1'b1;
                        wb_adr_o <= L1_pte[`PTE_PPN]<<`PAGE_SIZE + VA[`VA_VPN2]<<PTE_SIZE;
                        wb_sel_o <= 4'hF;
                        wb_we_o <= 1'b0;
                        mem_master_stall <= 1'b1;
                        state <= L2_FETCH_DONE;
                    end
                end
                L2_FETCH_DONE: begin
                    if(wb_ack_i) begin
                        mem_master_stall <= 1'b1;
                        L2_pte <= wb_dat_i;
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        state <= FETCH_DONE;
                    end
                end
                FETCH_DONE: begin
                    if(L2_invalid) begin
                        wb_cyc_o <= 1'b0;
                        wb_stb_o <= 1'b0;
                        load_page_fault <= 1'b1;
                        load_fault_va <= VA;
                        state <= DONE;
                    end else begin
                        if(is_read) begin
                            state <= READ_DATA_ACTION;
                            wb_stb_o <= 1'b1;
                            wb_cyc_o <= 1'b1;
                            wb_adr_o <={L2_pte[`PTE_PPN1], L2_pte[`PTE_PPN0], VA[11:2], L2_pte[11:10]};;
                            wb_sel_o <= (sel << VA[1:0]);
                            wb_we_o <= 1'b0;
                            mem_master_stall <= 1'b1;
                        end else begin
                            state <= WRITE_DATA_ACTION;
                            wb_stb_o <= 1'b1;
                            wb_cyc_o <= 1'b1;
                            wb_adr_o <= L2_pte[`PTE_PPN]<<`PAGE_SIZE + VA[`VA_VPN3]<<2;
                            wb_dat_o <= data << data_shift;
                            wb_sel_o <= (sel << VA[1:0]);
                            wb_we_o <= 1'b1;    
                            mem_master_stall <= 1'b1;    
                        end
                    end
                end
                READ_DATA_ACTION: begin
                    if (wb_ack_i) begin
                        state <= DONE;    
                        wb_stb_o <= 1'b0;
                        wb_cyc_o <= 1'b0;
                        mem_master_stall <= 1'b0;
                        case (wb_sel_o)
                            4'b0001: mem_read_data <= (read_unsigned ? {24'b0, wb_dat_i[7:0]} : {{24{wb_dat_i[7]}}, wb_dat_i[7:0]});
                            4'b0010: mem_read_data <= (read_unsigned ? {24'b0, wb_dat_i[15:8]} : {{24{wb_dat_i[15]}}, wb_dat_i[15:8]});
                            4'b0100: mem_read_data <= (read_unsigned ? {24'b0, wb_dat_i[23:16]} : {{24{wb_dat_i[23]}}, wb_dat_i[23:16]});
                            4'b1000: mem_read_data <= (read_unsigned ? {24'b0, wb_dat_i[31:24]} : {{24{wb_dat_i[31]}}, wb_dat_i[31:24]});
                            4'b0011: mem_read_data <= (read_unsigned ? {16'b0, wb_dat_i[15:0]} : {{16{wb_dat_i[15]}}, wb_dat_i[15:0]});
                            4'b0110: mem_read_data <= (read_unsigned ? {16'b0, wb_dat_i[23:8]} : {{16{wb_dat_i[23]}}, wb_dat_i[23:8]});
                            4'b1100: mem_read_data <= (read_unsigned ? {16'b0, wb_dat_i[31:16]} : {{16{wb_dat_i[31]}}, wb_dat_i[31:16]});
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
            mtimecmp <= 32'hf0000000; // TODO: set a proper initial value
        end else begin
            // 禁用时钟中断, 减少调试内容
            // mtime <= mtime + 1;  // TODO: use a timer to count
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
            end
        end
    end

endmodule