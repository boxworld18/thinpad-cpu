`timescale 1ns / 1ps
`default_nettype none
`include "defines.svh"

module cpu (
    input wire clk_i,
    input wire rst_i,

    // wishbone master 0 (IF)
    input wire wbm0_ack_i, 
    input wire [`DATA_BUS] wbm0_dat_i,
    input wire wbm0_err_i,
    input wire wbm0_rty_i,

    output reg wbm0_cyc_o,
    output reg wbm0_stb_o,
    output reg [`ADDR_BUS] wbm0_adr_o,
    output reg [`DATA_BUS] wbm0_dat_o,
    output reg [`SEL] wbm0_sel_o,
    output reg wbm0_we_o,

    // wishbone master 1 (MEM)
    input wire wbm1_ack_i,
    input wire [`DATA_BUS] wbm1_dat_i,
    input wire wbm1_err_i,
    input wire wbm1_rty_i,

    output reg wbm1_cyc_o,
    output reg wbm1_stb_o,
    output reg [`ADDR_BUS] wbm1_adr_o,
    output reg [`DATA_BUS] wbm1_dat_o,
    output reg [`SEL] wbm1_sel_o,
    output reg wbm1_we_o
);
    // interrupt
    logic time_interrupt;
    logic time_interrupt_enable;
    logic time_interrupt_happen;
    assign time_interrupt_happen = time_interrupt & time_interrupt_enable;

    // mode
    logic [1:0] mode; // 0: U_MODE 1: S_MODE 3: M_MODE

    // page fault
    logic inst_page_fault, load_page_fault, store_page_fault;
    logic [`ADDR_BUS] inst_fault_va;
    logic [`ADDR_BUS] load_fault_va;
    logic [`ADDR_BUS] store_fault_va;

    // stall -> used by if_master and mem_master

    logic if_master_stall, mem_master_stall; 
    logic stall; 
    assign stall = if_master_stall | mem_master_stall;

    // flush 
    logic if_id_flush;
    logic id_ex_flush;

    // hold
    logic if_id_hold;
    logic id_ex_hold;

    /* =========== IF begin =========== */

    logic [`ADDR_BUS] if_pc;
    logic [`INST_BUS] if_inst;    

    logic [`ADDR_BUS] id_pc;
    logic [`INST_BUS] id_inst;

    logic [`ADDR_BUS] pc_branch;
    logic branch; 

    cpu_if_master u_cpu_if_master (
        .clk(clk_i),
        .rst(rst_i),
        .stall(stall),
        .hold(if_id_hold),

        .branch(branch),
        .pc_branch(pc_branch),
        
        .wb_ack_i(wbm0_ack_i),
        .wb_dat_i(wbm0_dat_i),
        
        .wb_cyc_o(wbm0_cyc_o), 
        .wb_stb_o(wbm0_stb_o),
        .wb_adr_o(wbm0_adr_o),
        .wb_dat_o(wbm0_dat_o),
        .wb_sel_o(wbm0_sel_o),
        .wb_we_o(wbm0_we_o),

        .pc(if_pc),
        .inst(if_inst),
        .if_master_stall(if_master_stall),

        .inst_page_fault(inst_page_fault),
        .inst_fault_va(inst_fault_va)
    );

    /* =========== IF end =========== */    

    if_id u_if_id(
        .clk(clk_i),
        .rst(rst_i),
        .stall(stall),
        .flush(if_id_flush),
        .hold(if_id_hold),
        .if_pc(if_pc),
        .if_inst(if_inst),
        .id_pc(id_pc),
        .id_inst(id_inst)
    );

    /* =========== ID begin =========== */

    // imm generator
    logic [`DATA_BUS] id_imm;
    logic [2:0] id_imm_type;
    imm_gen u_imm_gen(
        .inst(id_inst),
        .imm(id_imm)
    );

    // hazard detection unit

    // declare here for hazard detect
    logic ex_wb_ren; 
    logic ex_rf_wen;
    logic [`REG_ADDR_BUS] ex_rf_waddr; 
    logic mem_rf_wen;
    logic [`REG_ADDR_BUS] mem_rf_waddr;
    logic wb_rf_wen;
    logic [`REG_ADDR_BUS] wb_rf_waddr;
    

    // regfile
    logic id_rf_wen;
    logic id_rf_sel;
    // wishbone
    logic id_wb_wen;
    logic id_wb_ren;
    logic [`SEL] id_wb_sel;
    logic id_wb_read_unsigned;
    // alu
    logic [`ALU_OP_WIDTH-1:0] id_alu_op;
    logic id_alu_sel_imm;
    logic id_alu_sel_pc;
    logic id_sel_csr;
    // csr
    logic [`CSR_SEL_WIDTH-1:0] id_csr_inst_sel;
    logic [`CSR_ADDR_BUS] id_csr_raddr;
    logic id_csr_imm_sel;

    control u_control(
        .pc(id_pc),
        .inst(id_inst),

        .id_rf_wen(id_rf_wen),
        .id_rf_sel(id_rf_sel),

        .id_wb_wen(id_wb_wen),
        .id_wb_ren(id_wb_ren),
        .id_wb_sel(id_wb_sel),
        .id_wb_read_unsigned(id_wb_read_unsigned),

        .id_alu_op(id_alu_op),
        .id_alu_sel_imm(id_alu_sel_imm),
        .id_alu_sel_pc(id_alu_sel_pc),
        .id_sel_csr(id_sel_csr),

        .id_csr_inst_sel(id_csr_inst_sel),
        .id_csr_raddr(id_csr_raddr),
        .id_csr_imm_sel(id_csr_imm_sel)
    );

    logic [`REG_DATA_BUS] id_rf_data_a;
    logic [`REG_DATA_BUS] id_rf_data_b;
    logic [`REG_DATA_BUS] wb_rf_wdata; 
    regfile u_regfile(
        .clk(clk_i),
        .rst(rst_i),

        .raddr_a(id_inst[19:15]),
        .raddr_b(id_inst[24:20]),
        .waddr(wb_rf_waddr),
        .wdata(wb_rf_wdata),
        .wen(wb_rf_wen),

        .rdata_a(id_rf_data_a),
        .rdata_b(id_rf_data_b)
    );

    logic [`CSR_DATA_BUS] id_csr_rdata;
    logic [`CSR_SEL_WIDTH-1:0] wb_csr_inst_sel;
    logic [`CSR_ADDR_BUS] wb_csr_waddr;
    logic [`CSR_DATA_BUS] wb_csr_wdata;
    logic [`CSR_DATA_BUS] csr_mtvec;

    csr u_csr(
        .clk(clk_i),
        .rst(rst_i),

        .raddr(id_csr_raddr),
        .rdata(id_csr_rdata),

        .wb_pc(wb_pc),
        .sel(wb_csr_inst_sel),
        .waddr(wb_csr_waddr),
        .wdata(wb_csr_wdata),

        .csr_mtvec(csr_mtvec),
        .time_interrupt_enable(time_interrupt_enable),
        .mode_o(mode)
    );

    /* =========== ID end =========== */

    logic [`ADDR_BUS] ex_pc;
    logic [`INST_BUS] ex_inst;
    logic [`DATA_BUS] ex_rf_data_a;
    logic [`DATA_BUS] ex_rf_data_b;
    logic ex_rf_sel;
    logic ex_wb_wen;
    logic [`SEL] ex_wb_sel;
    logic ex_wb_read_unsigned;
    logic [`ALU_OP_WIDTH-1:0] ex_alu_op;
    logic ex_alu_sel_imm;
    logic ex_alu_sel_pc;
    logic ex_sel_csr;
    logic [`CSR_SEL_WIDTH-1:0] ex_csr_inst_sel;
    logic [`CSR_ADDR_BUS] ex_csr_waddr;
    logic [`CSR_ADDR_BUS] ex_csr_raddr;
    logic [`CSR_DATA_BUS] ex_csr_rdata;
    logic ex_csr_imm_sel;
    logic [`REG_ADDR_BUS] ex_rs1;
    logic [`REG_ADDR_BUS] ex_rs2;
    logic [`DATA_BUS] ex_imm;

    id_ex u_id_ex(
        .clk(clk_i),
        .rst(rst_i),
        .stall(stall),
        .flush(id_ex_flush),
        .hold(id_ex_hold),

        .id_pc(id_pc),
        .id_inst(id_inst),
        .id_rf_wen(id_rf_wen),
        .id_rf_waddr(id_inst[11:7]),
        .id_rf_data_a(id_rf_data_a),
        .id_rf_data_b(id_rf_data_b),
        .id_rf_sel(id_rf_sel),
        .id_wb_wen(id_wb_wen),
        .id_wb_ren(id_wb_ren),
        .id_wb_sel(id_wb_sel),
        .id_wb_read_unsigned(id_wb_read_unsigned),
        .id_alu_op(id_alu_op),
        .id_alu_sel_imm(id_alu_sel_imm),
        .id_alu_sel_pc(id_alu_sel_pc),
        .id_sel_csr(id_sel_csr),
        .id_csr_inst_sel(id_csr_inst_sel),
        .id_csr_waddr(id_inst[31:20]),
        .id_csr_raddr(id_csr_raddr),
        .id_csr_rdata(id_csr_rdata),
        .id_csr_imm_sel(id_csr_imm_sel),
        .id_rs1(id_inst[19:15]),
        .id_rs2(id_inst[24:20]),
        .id_imm(id_imm),

        .time_interrupt(time_interrupt_happen),
        .mtvec(csr_mtvec),

        .ex_pc(ex_pc),
        .ex_inst(ex_inst),
        .ex_rf_wen(ex_rf_wen),
        .ex_rf_waddr(ex_rf_waddr),
        .ex_rf_data_a(ex_rf_data_a),
        .ex_rf_data_b(ex_rf_data_b),
        .ex_rf_sel(ex_rf_sel),
        .ex_wb_wen(ex_wb_wen),
        .ex_wb_ren(ex_wb_ren),
        .ex_wb_sel(ex_wb_sel),
        .ex_wb_read_unsigned(ex_wb_read_unsigned),
        .ex_alu_op(ex_alu_op),
        .ex_alu_sel_imm(ex_alu_sel_imm),
        .ex_alu_sel_pc(ex_alu_sel_pc),
        .ex_sel_csr(ex_sel_csr),
        .ex_csr_inst_sel(ex_csr_inst_sel),
        .ex_csr_waddr(ex_csr_waddr),
        .ex_csr_raddr(ex_csr_raddr),
        .ex_csr_rdata(ex_csr_rdata),
        .ex_csr_imm_sel(ex_csr_imm_sel),
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .ex_imm(ex_imm)
    );

    /* =========== EX begin =========== */

    // ex_alu_sel_imm: reg or imm
    // ex_alu_sel_pc: reg or pc
    // ex_alu_sel_a/b: forward unit

    logic [`ALU_SEL_WIDTH-1:0] ex_alu_sel_a;
    logic [`ALU_SEL_WIDTH-1:0] ex_alu_sel_b;

    logic [`DATA_BUS] alu_rf_data_a;
    logic [`DATA_BUS] alu_rf_data_b;

    logic [`DATA_BUS] mem_data; // declare here for forward

    always_comb begin
        case (ex_alu_sel_a)
            ALU_SEL_NOP: alu_rf_data_a = 0;
            ALU_SEL_EX:  alu_rf_data_a = ex_rf_data_a; 
            ALU_SEL_MEM: alu_rf_data_a = mem_data;  
            ALU_SEL_WB:  alu_rf_data_a = wb_rf_wdata;
        endcase        
    end

    logic [`CSR_DATA_BUS] mem_csr_wdata; // declare ahead for forward
    always_comb begin
        case (ex_alu_sel_b)
            ALU_SEL_NOP: alu_rf_data_b = 0;
            ALU_SEL_EX:  alu_rf_data_b = ex_rf_data_b; 
            ALU_SEL_MEM: alu_rf_data_b = mem_data;  
            ALU_SEL_WB:  alu_rf_data_b = wb_rf_wdata;
        endcase
    end

    logic [`CSR_DATA_BUS] alu_csr_rdata;
    logic [1:0] ex_alu_sel_csr;

    always_comb begin
        case (ex_alu_sel_csr)
            ALU_SEL_NOP: alu_csr_rdata = 0;
            ALU_SEL_EX:  alu_csr_rdata = ex_csr_rdata; 
            ALU_SEL_MEM: alu_csr_rdata = mem_csr_wdata;  
            ALU_SEL_WB:  alu_csr_rdata = wb_csr_wdata;
        endcase
    end
    
    branch_comp u_branch_comp(
        .pc(ex_pc),
        .inst(ex_inst),
        .imm(ex_imm),
        .data_a(alu_rf_data_a),
        .data_b(alu_rf_data_b),
        .csr_inst_sel(ex_csr_inst_sel),
        .csr_rdata(alu_csr_rdata),

        .pc_branch(pc_branch), // branch target
        .branch(branch)  // branch taken
    );

    logic [`DATA_BUS] alu_data_o;
    alu u_alu(
        .a(ex_alu_sel_pc == ALU_SEL_PC ? ex_pc : alu_rf_data_a),
        .b(ex_alu_sel_imm == ALU_SEL_IMM ? ex_imm : (ex_sel_csr ? alu_csr_rdata : alu_rf_data_b)),
        .op(ex_alu_op),
        .y(alu_data_o)
    );

    logic [`CSR_DATA_BUS] ex_csr_wdata;
    csr_alu u_csr_alu(
        .sel(ex_csr_inst_sel),
        .imm_sel(ex_csr_imm_sel),
        .rs1_data(alu_rf_data_a),
        .imm(ex_imm),

        .mode(mode),
        .rdata(alu_csr_rdata),
        .waddr(ex_csr_waddr),
        .wdata(ex_csr_wdata)
    );

    /* =========== EX end =========== */    

    logic [`ADDR_BUS] mem_pc;
    logic [`DATA_BUS] mem_wb_wdata;
    logic mem_wb_wen;
    logic mem_wb_ren;
    logic [`SEL] mem_wb_sel;
    logic mem_wb_read_unsigned;
    logic mem_rf_sel;
    logic [`CSR_SEL_WIDTH-1:0] mem_csr_inst_sel;
    logic [`CSR_ADDR_BUS] mem_csr_waddr;
    
    ex_mem u_ex_mem(
        .clk(clk_i),
        .rst(rst_i),
        .stall(stall),

        .ex_pc(ex_pc),
        .ex_data(alu_data_o),
        .ex_wb_wdata(alu_rf_data_b),
        .ex_wb_wen(ex_wb_wen),
        .ex_wb_ren(ex_wb_ren),
        .ex_wb_sel(ex_wb_sel),
        .ex_wb_read_unsigned(ex_wb_read_unsigned),
        .ex_rf_wen(ex_rf_wen),
        .ex_rf_waddr(ex_rf_waddr),
        .ex_rf_sel(ex_rf_sel),
        .ex_csr_inst_sel(ex_csr_inst_sel),
        .ex_csr_waddr(ex_csr_waddr),
        .ex_csr_wdata(ex_csr_wdata),

        .mem_pc(mem_pc),
        .mem_data(mem_data),
        .mem_wb_wdata(mem_wb_wdata),
        .mem_wb_wen(mem_wb_wen),
        .mem_wb_ren(mem_wb_ren),
        .mem_wb_sel(mem_wb_sel),
        .mem_wb_read_unsigned(mem_wb_read_unsigned),
        .mem_rf_wen(mem_rf_wen),
        .mem_rf_waddr(mem_rf_waddr),
        .mem_rf_sel(mem_rf_sel),
        .mem_csr_inst_sel(mem_csr_inst_sel),
        .mem_csr_waddr(mem_csr_waddr),
        .mem_csr_wdata(mem_csr_wdata)
    );

    /* =========== MEM begin =========== */

    logic [`DATA_BUS] mem_read_data;
    cpu_mem_master u_cpu_mem_master (
        .clk(clk_i),
        .rst(rst_i),
        .addr(mem_data),
        .data(mem_wb_wdata),
        .wen(mem_wb_wen),
        .ren(mem_wb_ren),
        .sel(mem_wb_sel),
        .read_unsigned(mem_wb_read_unsigned),
        .stall(stall),

        .wb_ack_i(wbm1_ack_i),
        .wb_dat_i(wbm1_dat_i),
        
        .wb_cyc_o(wbm1_cyc_o), 
        .wb_stb_o(wbm1_stb_o),
        .wb_adr_o(wbm1_adr_o),
        .wb_dat_o(wbm1_dat_o),
        .wb_sel_o(wbm1_sel_o),
        .wb_we_o(wbm1_we_o),

        .mem_read_data(mem_read_data),
        .mem_master_stall(mem_master_stall),
        .time_interrupt(time_interrupt),

        .load_page_fault(load_page_fault),
        .load_fault_va(load_fault_va),
        .store_page_fault(store_page_fault),
        .store_fault_va(store_fault_va)
    );

    /* =========== MEM end =========== */

    logic [`ADDR_BUS] wb_pc;
    logic [`REG_DATA_BUS] mem_rf_wdata;
    assign mem_rf_wdata = mem_rf_sel ? mem_read_data : mem_data;

    mem_wb u_mem_wb(
        .clk(clk_i),
        .rst(rst_i),      
        .stall(stall),

        .mem_pc(mem_pc),
        .mem_rf_wen(mem_rf_wen),
        .mem_rf_waddr(mem_rf_waddr),
        .mem_rf_wdata(mem_rf_wdata),
        .mem_csr_inst_sel(mem_csr_inst_sel),
        .mem_csr_waddr(mem_csr_waddr),
        .mem_csr_wdata(mem_csr_wdata),

        .wb_pc(wb_pc),
        .wb_rf_wen(wb_rf_wen),
        .wb_rf_waddr(wb_rf_waddr),
        .wb_rf_wdata(wb_rf_wdata),
        .wb_csr_inst_sel(wb_csr_inst_sel),
        .wb_csr_waddr(wb_csr_waddr),
        .wb_csr_wdata(wb_csr_wdata)        
    );

    /* =========== WB begin =========== */    

    // write back (WB)
    // nothing to do here
    // all the work is done in the regfile module

    /* =========== WB end =========== */    

    /* =========== Forward Unit begin =========== */     

    forward_unit u_forward_unit(
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .mem_rd(mem_rf_waddr),
        .mem_rf_wen(mem_rf_wen),
        .wb_rd(wb_rf_waddr),
        .wb_rf_wen(wb_rf_wen),

        .ex_csr_raddr(ex_csr_raddr),
        .mem_csr_waddr(mem_csr_waddr),
        .mem_csr_wdata(mem_csr_wdata),
        .wb_csr_waddr(wb_csr_waddr),
        .wb_csr_wdata(wb_csr_wdata),

        .alu_sel_a(ex_alu_sel_a),
        .alu_sel_b(ex_alu_sel_b),
        .alu_sel_csr(ex_alu_sel_csr)
    );

    /* =========== Forward Unit end =========== */ 

    hazard_detection_unit u_hazard_detection_unit(
        .id_inst(id_inst),
        .ex_wb_ren(ex_wb_ren),
        .ex_rf_wen(ex_rf_wen),
        .ex_rf_waddr(ex_rf_waddr),
        .branch(branch),

        .id_csr_inst_sel(id_csr_inst_sel),
        .ex_csr_inst_sel(ex_csr_inst_sel),
        .mem_csr_inst_sel(mem_csr_inst_sel),
        .wb_csr_inst_sel(wb_csr_inst_sel),

        .if_id_flush(if_id_flush),
        .id_ex_flush(id_ex_flush),
        .if_id_hold(if_id_hold),
        .id_ex_hold(id_ex_hold)
    );

endmodule
