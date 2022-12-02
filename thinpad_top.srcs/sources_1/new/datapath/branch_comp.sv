`timescale 1ns / 1ps
`default_nettype none
`include "../defines.svh"

module branch_comp(
    input wire [`ADDR_BUS] pc,
    input wire [`INST_BUS] inst,
    input wire [`DATA_BUS] imm,
    input wire [`DATA_BUS] data_a,
    input wire [`DATA_BUS] data_b,

    input wire [`CSR_SEL_WIDTH-1:0] csr_inst_sel,
    input wire [`CSR_DATA_BUS] csr_rdata,

    output wire [`ADDR_BUS] pc_branch, // branch target
    output reg branch  // branch taken
);

    logic csr_branch;
    assign csr_branch = ((csr_inst_sel == ECALL) || (csr_inst_sel == EBREAK) || (csr_inst_sel == MRET) || (csr_inst_sel == SRET) || (csr_inst_sel == TIME_INTERRUPT));
    assign pc_branch = (inst[6:0] == `OPCODE_JALR) ? ((data_a + imm) & 32'hffff_fffe) : (csr_branch ? {csr_rdata[`TVEC_BASE], 2'b00} : pc + imm);

    always_comb begin
        if (inst[6:0] == `OPCODE_SB) begin
            case (inst[14:12])
                3'b000: branch = (data_a == data_b);
                3'b001: branch = (data_a != data_b);
                3'b100: branch = ($signed(data_a) < $signed(data_b)); // TODO: 研究一下这里
                3'b101: branch = ($signed(data_a) >= $signed(data_b));
                3'b110: branch = (data_a < data_b);
                3'b111: branch = (data_a >= data_b);
                default: branch = 1'b0;
            endcase
        end else if (inst[6:0] == `OPCODE_JAL || inst[6:0] == `OPCODE_JALR || csr_branch) begin 
            branch = 1'b1;
        end else begin
            branch = 1'b0;
        end
    end

endmodule