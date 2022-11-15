`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module alu(
    input wire [`DATA_BUS] a,
    input wire [`DATA_BUS] b,
    input wire [`ALU_OP_WIDTH-1:0] op,
    output reg [`DATA_BUS] y
);

    always_comb begin
        case (op)
            ALU_OP_ADD: y = a + b;
            ALU_OP_SUB: y = a - b;
            ALU_OP_AND: y = a & b;
            ALU_OP_OR: y = a | b;
            ALU_OP_XOR: y = a ^ b;
            ALU_OP_SLL: y = a << b;
            ALU_OP_SRL: y = a >> b;
            ALU_OP_SRA: y = $signed(a) >>> b;
            ALU_OP_B: y = b;
            ALU_OP_ADD_4: y = a + 4;
            default: y = 0;
        endcase
    end

endmodule