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

    logic if_master_stall, mem_master_stall; 
    logic stall; 
    logic hazard;
    logic flush;
    assign stall = if_master_stall | mem_master_stall;

    /* =========== IF begin =========== */

    logic [`ADDR_BUS] if_pc;
    logic [`INST_BUS] if_inst;    

    logic [`ADDR_BUS] id_pc;
    logic [`INST_BUS] id_inst;

    logic [`ADDR_BUS] pc_branch;
    logic pc_sel; 

    cpu_if_master u_cpu_if_master (
        .clk(clk_i),
        .rst(rst_i),
        .hazard(hazard),
        .flush(flush),
        .stall(stall),

        .pc_sel(pc_sel),
        .pc_branch(pc_branch),
        .pc(if_pc),

        .wb_ack_i(wbm0_ack_i),
        .wb_dat_i(wbm0_dat_i),
        
        .wb_cyc_o(wbm0_cyc_o), 
        .wb_stb_o(wbm0_stb_o),
        .wb_adr_o(wbm0_adr_o),
        .wb_dat_o(wbm0_dat_o),
        .wb_sel_o(wbm0_sel_o),
        .wb_we_o(wbm0_we_o),

        .inst(if_inst),
        .if_master_stall(if_master_stall)
    );

    /* =========== IF end =========== */    

    if_id u_if_id(
        .clk(clk_i),
        .rst(rst_i),
        .stall(stall),
        .hazard(hazard),
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
        .imm_type(id_imm_type),
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
    hazard_detection_unit u_hazard_detection_unit(
        .id_inst(id_inst),
        .imm_type(id_imm_type),

        .ex_wb_ren(ex_wb_ren),
        .ex_rf_wen(ex_rf_wen),
        .ex_rf_waddr(ex_rf_waddr),
        .mem_rf_wen(mem_rf_wen),
        .mem_rf_waddr(mem_rf_waddr),
        .wb_rf_wen(wb_rf_wen),
        .wb_rf_waddr(wb_rf_waddr),

        .hazard(hazard)
    );

    // regfile
    logic id_rf_wen;
    logic id_rf_sel;
    // wishbone
    logic id_wb_wen;
    logic id_wb_ren;
    logic [`SEL] id_wb_sel;
    // alu
    logic [`ALU_OP_WIDTH-1:0] id_alu_op;
    logic id_alu_sel;

    control u_control(
        .pc(id_pc),
        .inst(id_inst),

        .id_imm_type(id_imm_type),

        .id_rf_wen(id_rf_wen),
        .id_rf_sel(id_rf_sel),

        .id_wb_wen(id_wb_wen),
        .id_wb_ren(id_wb_ren),
        .id_wb_sel(id_wb_sel),

        .id_alu_op(id_alu_op),
        .id_alu_sel(id_alu_sel)
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

    logic rf_data_equ;
    assign pc_branch = rf_data_equ ? (id_pc + id_imm) : (id_pc + 4);
    assign rf_data_equ = (id_rf_data_a == id_rf_data_b);
    assign pc_sel = (id_imm_type == IMM_SB);
    assign flush = (id_imm_type == IMM_SB) & !hazard;

    /* =========== ID end =========== */

    logic [`ADDR_BUS] ex_pc;
    logic [`INST_BUS] ex_inst;
    logic [`DATA_BUS] ex_rf_data_a;
    logic [`DATA_BUS] ex_rf_data_b;
    logic ex_rf_sel;
    logic ex_wb_wen;
    logic [`SEL] ex_wb_sel;
    logic [`ALU_OP_WIDTH-1:0] ex_alu_op;
    logic ex_alu_sel;
    logic [`REG_ADDR_BUS] ex_rs1;
    logic [`REG_ADDR_BUS] ex_rs2;
    logic [`DATA_BUS] ex_imm;

    id_ex u_id_ex(
        .clk(clk_i),
        .rst(rst_i),
        .stall(stall),
        .insert_nop(hazard),

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
        .id_alu_op(id_alu_op),
        .id_alu_sel(id_alu_sel),
        .id_rs1(id_inst[19:15]),
        .id_rs2(id_inst[24:20]),
        .id_imm(id_imm),

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
        .ex_alu_op(ex_alu_op),
        .ex_alu_sel(ex_alu_sel),
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .ex_imm(ex_imm)
    );

    /* =========== EX begin =========== */

    // ex_alu_sel: reg or imm
    // ex_alu_sel_a/b: forward unit

    logic [`ALU_SEL_WIDTH-1:0] ex_alu_sel_a;
    logic [`ALU_SEL_WIDTH-1:0] ex_alu_sel_b;

    logic [`DATA_BUS] alu_data_a;
    logic [`DATA_BUS] alu_data_b;

    logic [`DATA_BUS] mem_data; // declare here for forward

    always_comb begin
        case (ex_alu_sel_a)
            ALU_SEL_NOP: alu_data_a = 0;
            ALU_SEL_EX:  alu_data_a = ex_rf_data_a; 
            ALU_SEL_MEM: alu_data_a = mem_data;  
            ALU_SEL_WB:  alu_data_a = wb_rf_wdata;
        endcase        
    end

    always_comb begin
        case (ex_alu_sel_b)
            ALU_SEL_NOP: alu_data_b = 0;
            ALU_SEL_EX:  alu_data_b = ex_rf_data_b; 
            ALU_SEL_MEM: alu_data_b = mem_data;  
            ALU_SEL_WB:  alu_data_b = wb_rf_wdata;
        endcase
    end

    logic [`DATA_BUS] alu_data_o;
    alu u_alu(
        .a(alu_data_a),
        .b(ex_alu_sel == ALU_SEL_IMM ? ex_imm : alu_data_b),
        .op(ex_alu_op),
        .y(alu_data_o)
    );

    /* =========== EX end =========== */    

    logic [`DATA_BUS] mem_wb_wdata;
    logic mem_wb_wen;
    logic mem_wb_ren;
    logic [`SEL] mem_wb_sel;
    logic mem_rf_sel;

    ex_mem u_ex_mem(
        .clk(clk_i),
        .rst(rst_i),
        .stall(stall),

        .ex_data(alu_data_o),
        .ex_wb_wdata(alu_data_b),
        .ex_wb_wen(ex_wb_wen),
        .ex_wb_ren(ex_wb_ren),
        .ex_wb_sel(ex_wb_sel),
        .ex_rf_wen(ex_rf_wen),
        .ex_rf_waddr(ex_rf_waddr),
        .ex_rf_sel(ex_rf_sel),

        .mem_data(mem_data),
        .mem_wb_wdata(mem_wb_wdata),
        .mem_wb_wen(mem_wb_wen),
        .mem_wb_ren(mem_wb_ren),
        .mem_wb_sel(mem_wb_sel),
        .mem_rf_wen(mem_rf_wen),
        .mem_rf_waddr(mem_rf_waddr),
        .mem_rf_sel(mem_rf_sel)
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

        .wb_ack_i(wbm1_ack_i),
        .wb_dat_i(wbm1_dat_i),
        
        .wb_cyc_o(wbm1_cyc_o), 
        .wb_stb_o(wbm1_stb_o),
        .wb_adr_o(wbm1_adr_o),
        .wb_dat_o(wbm1_dat_o),
        .wb_sel_o(wbm1_sel_o),
        .wb_we_o(wbm1_we_o),

        .mem_read_data(mem_read_data),
        .mem_master_stall(mem_master_stall)
    );

    /* =========== MEM end =========== */

    logic [`REG_DATA_BUS] mem_rf_wdata;
    assign mem_rf_wdata = mem_rf_sel ? mem_read_data : mem_data;

    mem_wb u_mem_wb(
        .clk(clk_i),
        .rst(rst_i),      
        .stall(stall),
        .mem_rf_wen(mem_rf_wen),
        .mem_rf_waddr(mem_rf_waddr),
        .mem_rf_wdata(mem_rf_wdata),
        .wb_rf_wen(wb_rf_wen),
        .wb_rf_waddr(wb_rf_waddr),
        .wb_rf_wdata(wb_rf_wdata)        
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

        .alu_sel_a(ex_alu_sel_a),
        .alu_sel_b(ex_alu_sel_b)
    );

    /* =========== Forward Unit end =========== */ 

endmodule
