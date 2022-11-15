`timescale 1ns / 1ps
`default_nettype none

module button_in (
    input wire clk,
    input wire reset,
    input wire push_btn,
    output wire trigger
);

  logic trigger_reg;
  logic last_push_btn_reg;

  always_ff @(posedge clk) begin
    if (reset) begin
      last_push_btn_reg <= 1'b0;
      trigger_reg <= 1'b0;
    end else begin
      if ((!last_push_btn_reg) && push_btn)
        trigger_reg <= 1'b1;
      else
        trigger_reg <= 1'b0;
      last_push_btn_reg <= push_btn;
    end
  end

  assign trigger = trigger_reg;

endmodule