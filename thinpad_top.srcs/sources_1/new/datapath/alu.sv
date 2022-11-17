`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module alu(
    input wire [`DATA_BUS] a,
    input wire [`DATA_BUS] b,
    input wire [`ALU_OP_WIDTH-1:0] op,
    output reg [`DATA_BUS] y
);

    logic [4:0] ctz_result;
    always_comb begin
        case (op)
            ALU_OP_ADD: y = a + b;
            ALU_OP_SUB: y = a - b;
            ALU_OP_AND: y = a & b;
            ALU_OP_OR: y = a | b;
            ALU_OP_XOR: y = a ^ b;
            ALU_OP_SLL: y = a << b[4:0];
            ALU_OP_SRL: y = a >> b[4:0];
            ALU_OP_SRA: y = $signed(a) >>> b[4:0];
            ALU_OP_B: y = b;
            ALU_OP_ADD_4: y = a + 4;
            ALU_OP_ANDN: y = a & ~b;
            ALU_OP_SBCLR: y = a & ~(32'b1 << b[4:0]);
            ALU_OP_CTZ: y = ((a == 0) ? 32'd32 : { 27'b0, ctz_result });
            default: y = 0;
        endcase
    end

    logic [31:0] ctz_sel [4:0];
    ctz_decoder #(
      .DATA_WIDTH(32)
    ) u_ctz_decoder_0(
        .data(a),
        .sel(ctz_result[4]),
        .data_sel(ctz_sel[4])
    );

    genvar m;
    generate
        for (m = 4; m >= 1; m = m - 1)
        begin: generate_decoder
            ctz_decoder #(
                .DATA_WIDTH(1 << m)
            )  u_ctz_decoder(
                .data(ctz_sel[m]),
                .sel(ctz_result[m-1]),
                .data_sel(ctz_sel[m-1])
            );
        end
    endgenerate

endmodule