module bram_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,

    parameter BRAM_ADDR_WIDTH = 19,
    parameter BRAM_DATA_WIDTH = 8
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

    // bram interface
    output wire [BRAM_ADDR_WIDTH-1:0] bram_addr,
    output wire [BRAM_DATA_WIDTH-1:0] bram_data,
    output reg bram_we_n
);

  logic [BRAM_DATA_WIDTH-1:0] bram_data_o;

  typedef enum logic [1:0] {
    STATE_IDLE = 0,
    STATE_READ = 1,
    STATE_WRITE = 2
  } state_t;

  state_t state;

  assign bram_addr = wb_adr_i[BRAM_ADDR_WIDTH-1:0];
  assign bram_data = bram_data_o;
  assign wb_dat_o = 32'h0;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      // 复位各个输出信号
      state <= STATE_IDLE;
      wb_ack_o <= 1'b0;
      wb_dat_o <= 32'h0;
      bram_we_n <= 1'b1;
    end else begin
      case (state)
        STATE_IDLE: begin
          wb_ack_o <= 1'b0;
          bram_we_n <= 1'b1;
          if (wb_stb_i && wb_cyc_i && !wb_ack_o) begin            
            if (wb_we_i) begin 
              state <= STATE_WRITE;
              case (wb_sel_i)
                4'b0001: bram_data_o <= wb_dat_i[ 7: 0];
                4'b0010: bram_data_o <= wb_dat_i[15: 8];
                4'b0100: bram_data_o <= wb_dat_i[23:16];
                4'b1000: bram_data_o <= wb_dat_i[31:24];
                default: bram_data_o <= 8'h0;
              endcase
            end else begin 
              state <= STATE_READ;              
            end
          end
        end

        STATE_READ: begin
          wb_ack_o <= 1'b1;
          state <= STATE_IDLE;
        end

        STATE_WRITE: begin
          state <= STATE_IDLE;
          bram_we_n <= 1'b0;
          wb_ack_o <= 1'b1;
        end

        default: begin
          state <= STATE_IDLE;
        end
      endcase
    end
  end

endmodule
