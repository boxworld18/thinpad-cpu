`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module imm_gen(
    input wire [`INST_BUS] inst,
    output reg [`DATA_BUS] imm
);

    // 立即数符号扩展

    logic [10:0] sign_extend_jtype;
    assign sign_extend_jtype = inst[31] ? 11'h7ff : 11'h0;

    logic [19:0] sign_extend_itype;
    assign sign_extend_itype = inst[31] ? 20'hfffff : 20'h0;

    always_comb begin
        case (inst[6:0])
            `OPCODE_I, `OPCODE_L, `OPCODE_JALR:
                imm = {sign_extend_itype, inst[31:20]};
            `OPCODE_S:
                imm = {sign_extend_itype, inst[31:25], inst[11:7]};
            `OPCODE_SB:
                imm = {sign_extend_itype, inst[7], inst[30:25], inst[11:8], 1'b0};
            `OPCODE_LUI, `OPCODE_AUIPC:
                imm = {inst[31:12], 12'b0};
            `OPCODE_JAL:
                imm = {sign_extend_jtype, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
            `OPCODE_PRIV:
                imm = {27'b0, inst[19:15]};
            default:
                imm = 32'b0;
        endcase
    end

endmodule