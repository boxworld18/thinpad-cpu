`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module csr_alu(
    input wire [`CSR_SEL_WIDTH-1:0] sel,
    input wire imm_sel,
    input wire [`DATA_BUS] rs1_data,
    input wire [`DATA_BUS] imm,
    input wire [`CSR_DATA_BUS] csr_rdata,

    output reg [`CSR_DATA_BUS] wdata
);

    logic [`DATA_BUS] data;
    assign data = imm_sel ? imm : rs1_data;

    always_comb begin
        case (sel)
            CSRRW, CSRRWI: wdata = data;
            CSRRS, CSRRSI: wdata = csr_rdata | data;
            CSRRC, CSRRCI: wdata = csr_rdata & ~data;
            default: wdata = csr_rdata;
        endcase 
    end

endmodule