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
            ALU_OP_X: begin
                logic [7:0] index0 = b[7:0];
                logic [7:0] index1 = b[15:8];
                logic [7:0] index2 = b[23:16];
                logic [7:0] index3 = b[31:24];

                logic [7:0] elem0 = a[7:0];
                logic [7:0] elem1 = a[15:8];
                logic [7:0] elem2 = a[23:16];
                logic [7:0] elem3 = a[31:24];
                
                case (index0)
                    0: y[7:0] = elem0;
                    1: y[7:0] = elem1;
                    2: y[7:0] = elem2;
                    3: y[7:0] = elem3;
                    default: y[7:0] = 8'd0;
                endcase
                case (index1)
                    0: y[15:8] = elem0;
                    1: y[15:8] = elem1;
                    2: y[15:8] = elem2;
                    3: y[15:8] = elem3;
                    default: y[15:8] = 8'd0;
                endcase
                case (index2)
                    0: y[23:16] = elem0;
                    1: y[23:16] = elem1;
                    2: y[23:16] = elem2;
                    3: y[23:16] = elem3;
                    default: y[23:16] = 8'd0;
                endcase
                case (index3)
                    0: y[31:24] = elem0;
                    1: y[31:24] = elem1;
                    2: y[31:24] = elem2;
                    3: y[31:24] = elem3;
                    default: y[31:24] = 8'd0;
                endcase
                
                // y[31:24] = ~|((b[31:24]) & `ALU_OP_X_MASK) ? a[b[25:24]] : 32'd0;
                // y[23:16] = ~|((b[23:16]) & `ALU_OP_X_MASK) ? a[b[17:16]] : 32'd0;
                // y[15:8] = ~|((b[15:8]) & `ALU_OP_X_MASK) ? a[b[9:8]] : 32'd0;
                // y[7:0] = ~|((b[7:0]) & `ALU_OP_X_MASK) ? a[b[1:0]] : 32'd0;
            end
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