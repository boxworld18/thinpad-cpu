module sram_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,

    parameter SRAM_ADDR_WIDTH = 20,
    parameter SRAM_DATA_WIDTH = 32,

    localparam SRAM_BYTES = SRAM_DATA_WIDTH / 8,
    localparam SRAM_BYTE_WIDTH = $clog2(SRAM_BYTES)
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_adr_i,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input wire wb_we_i,

    // sram interface
    output wire [SRAM_ADDR_WIDTH-1:0] sram_addr,
    inout wire [SRAM_DATA_WIDTH-1:0] sram_data,
    output wire sram_ce_n,
    output wire sram_oe_n,
    output reg sram_we_n,
    output wire [SRAM_BYTES-1:0] sram_be_n
);

  // tri-state gate
  wire [SRAM_DATA_WIDTH-1:0] sram_data_i;
  logic [SRAM_DATA_WIDTH-1:0] sram_data_o;
  logic sram_data_t;

  assign sram_data = sram_data_t ? 32'bz : sram_data_o;
  assign sram_data_i = sram_data;

  typedef enum logic [2:0] {
    STATE_IDLE = 0,
    STATE_READ = 1,
    STATE_WRITE = 2,
    STATE_WRITE_2 = 3,

    // 备用
    STATE_READ_2 = 4,
    STATE_WRITE_3 = 5
  } state_t;

  state_t state;

  assign sram_be_n = ~wb_sel_i;
  assign sram_addr = wb_adr_i[SRAM_ADDR_WIDTH+1:2];
  assign sram_ce_n = ~wb_stb_i | ~wb_cyc_i | wb_ack_o;
  assign sram_oe_n = ~wb_stb_i | ~wb_cyc_i | wb_ack_o | wb_we_i;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      // 复位各个输出信号
      state <= STATE_IDLE;
      wb_ack_o <= 1'b0;
      wb_dat_o <= 32'h0;
      sram_data_t <= 1'h1;
      sram_we_n <= 1'b1;
    end else begin
      case (state)
        STATE_IDLE: begin
          wb_ack_o <= 1'b0;
          sram_we_n <= 1'b1;
          if (wb_stb_i && wb_cyc_i && !wb_ack_o) begin            
            if (wb_we_i) begin 
              state <= STATE_WRITE;
              sram_data_o <= wb_dat_i;
              sram_data_t <= 1'b0;
            end else begin 
              state <= STATE_READ;              
            end
          end
        end

        STATE_READ: begin
          state <= STATE_READ;
        end

        STATE_READ_2: begin
          wb_dat_o <= sram_data_i;
          wb_ack_o <= 1'b1;
          state <= STATE_IDLE;
        end

        STATE_WRITE: begin
          state <= STATE_WRITE_2;
          sram_we_n <= 1'b0;
        end

        STATE_WRITE_2: begin
          state <= STATE_IDLE;
          sram_we_n <= 1'b1;
          wb_ack_o <= 1'b1;
          sram_data_t <= 1'b1;
        end

        default: begin
          state <= STATE_IDLE;
        end
      endcase
    end
  end

endmodule
