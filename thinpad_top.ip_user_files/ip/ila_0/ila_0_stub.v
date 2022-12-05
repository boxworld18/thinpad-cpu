// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
// Date        : Mon Dec  5 22:39:24 2022
// Host        : DESKTOP-M19K5L1 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub E:/cod22-grp01/thinpad_top.srcs/sources_1/ip/ila_0/ila_0_stub.v
// Design      : ila_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tfgg676-2L
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ila,Vivado 2019.2" *)
module ila_0(clk, probe0, probe1, probe2, probe3, probe4, probe5, 
  probe6, probe7, probe8, probe9, probe10, probe11, probe12, probe13, probe14, probe15, probe16, probe17, 
  probe18, probe19, probe20)
/* synthesis syn_black_box black_box_pad_pin="clk,probe0[31:0],probe1[31:0],probe2[31:0],probe3[31:0],probe4[31:0],probe5[0:0],probe6[0:0],probe7[31:0],probe8[31:0],probe9[31:0],probe10[31:0],probe11[31:0],probe12[3:0],probe13[3:0],probe14[3:0],probe15[3:0],probe16[31:0],probe17[31:0],probe18[1:0],probe19[63:0],probe20[63:0]" */;
  input clk;
  input [31:0]probe0;
  input [31:0]probe1;
  input [31:0]probe2;
  input [31:0]probe3;
  input [31:0]probe4;
  input [0:0]probe5;
  input [0:0]probe6;
  input [31:0]probe7;
  input [31:0]probe8;
  input [31:0]probe9;
  input [31:0]probe10;
  input [31:0]probe11;
  input [3:0]probe12;
  input [3:0]probe13;
  input [3:0]probe14;
  input [3:0]probe15;
  input [31:0]probe16;
  input [31:0]probe17;
  input [1:0]probe18;
  input [63:0]probe19;
  input [63:0]probe20;
endmodule
