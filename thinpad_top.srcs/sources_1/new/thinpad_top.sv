`default_nettype none
`include "defines.svh"

module thinpad_top (
    input wire clk_50M,     // 50MHz 时钟输入
    input wire clk_11M0592, // 11.0592MHz 时钟输入（备用，可不用）

    input wire push_btn,  // BTN5 按钮开关，带消抖电路，按下时为 1
    input wire reset_btn, // BTN6 复位按钮，带消抖电路，按下时为 1

    input  wire [ 3:0] touch_btn,  // BTN1~BTN4，按钮开关，按下时为 1
    input  wire [31:0] dip_sw,     // 32 位拨码开关，拨到“ON”时为 1
    output wire [15:0] leds,       // 16 位 LED，输出时 1 点亮
    output wire [ 7:0] dpy0,       // 数码管低位信号，包括小数点，输出 1 点亮
    output wire [ 7:0] dpy1,       // 数码管高位信号，包括小数点，输出 1 点亮

    // CPLD 串口控制器信号
    output wire uart_rdn,        // 读串口信号，低有效
    output wire uart_wrn,        // 写串口信号，低有效
    input  wire uart_dataready,  // 串口数据准备好
    input  wire uart_tbre,       // 发送数据标志
    input  wire uart_tsre,       // 数据发送完毕标志

    // BaseRAM 信号
    inout wire [31:0] base_ram_data,  // BaseRAM 数据，低 8 位与 CPLD 串口控制器共享
    output wire [19:0] base_ram_addr,  // BaseRAM 地址
    output wire [3:0] base_ram_be_n,  // BaseRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire base_ram_ce_n,  // BaseRAM 片选，低有效
    output wire base_ram_oe_n,  // BaseRAM 读使能，低有效
    output wire base_ram_we_n,  // BaseRAM 写使能，低有效

    // ExtRAM 信号
    inout wire [31:0] ext_ram_data,  // ExtRAM 数据
    output wire [19:0] ext_ram_addr,  // ExtRAM 地址
    output wire [3:0] ext_ram_be_n,  // ExtRAM 字节使能，低有效。如果不使用字节使能，请保持为 0
    output wire ext_ram_ce_n,  // ExtRAM 片选，低有效
    output wire ext_ram_oe_n,  // ExtRAM 读使能，低有效
    output wire ext_ram_we_n,  // ExtRAM 写使能，低有效

    // 直连串口信号
    output wire txd,  // 直连串口发送端
    input  wire rxd,  // 直连串口接收端

    // Flash 存储器信号，参考 JS28F640 芯片手册
    output wire [22:0] flash_a,  // Flash 地址，a0 仅在 8bit 模式有效，16bit 模式无意义
    inout wire [15:0] flash_d,  // Flash 数据
    output wire flash_rp_n,  // Flash 复位信号，低有效
    output wire flash_vpen,  // Flash 写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,  // Flash 片选信号，低有效
    output wire flash_oe_n,  // Flash 读使能信号，低有效
    output wire flash_we_n,  // Flash 写使能信号，低有效
    output wire flash_byte_n, // Flash 8bit 模式选择，低有效。在使用 flash 的 16 位模式时请设为 1

    // USB 控制器信号，参考 SL811 芯片手册
    output wire sl811_a0,
    // inout  wire [7:0] sl811_d,     // USB 数据线与网络控制器的 dm9k_sd[7:0] 共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    // 网络控制器信号，参考 DM9000A 芯片手册
    output wire dm9k_cmd,
    inout wire [15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input wire dm9k_int,

    // 图像输出信号
    output wire [2:0] video_red,    // 红色像素，3 位
    output wire [2:0] video_green,  // 绿色像素，3 位
    output wire [1:0] video_blue,   // 蓝色像素，2 位
    output wire       video_hsync,  // 行同步（水平同步）信号
    output wire       video_vsync,  // 场同步（垂直同步）信号
    output wire       video_clk,    // 像素时钟输出
    output wire       video_de      // 行数据有效信号，用于区分消隐区

    // output wire [31:0] wb_pc,
    // output wire [31:0] wb_inst
);

  /* =========== Demo code begin =========== */

  // PLL 分频示例
  logic locked, clk_10M, clk_20M, clk_75M, clk_100M, clk_200M;
  pll_example clock_gen (
      // Clock in ports
      .clk_in1(clk_50M),  // 外部时钟输入
      // Clock out ports
      .clk_out1(clk_10M),  // 时钟输出 1，频率在 IP 配置界面中设置
      .clk_out2(clk_20M),  // 时钟输出 2，频率在 IP 配置界面中设置
      .clk_out3(clk_100M),
      .clk_out4(clk_200M),
      .clk_out5(clk_75M),
      // Status and control signals
      .reset(reset_btn),  // PLL 复位输入
      .locked(locked)  // PLL 锁定指示输出，"1"表示时钟稳定，
                       // 后级电路复位信号应当由它生成（见下）
  );

  logic reset_of_clk10M;
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk10M
  always_ff @(posedge clk_10M or negedge locked) begin
    if (~locked) reset_of_clk10M <= 1'b1;
    else reset_of_clk10M <= 1'b0;
  end

  logic reset_of_clk20M;
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk20M
  always_ff @(posedge clk_20M or negedge locked) begin
    if (~locked) reset_of_clk20M <= 1'b1;
    else reset_of_clk20M <= 1'b0;
  end

  logic reset_of_clk100M;
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk100M
  always_ff @(posedge clk_100M or negedge locked) begin
    if (~locked) reset_of_clk100M <= 1'b1;
    else reset_of_clk100M <= 1'b0;
  end

  logic reset_of_clk200M;
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk200M
  always_ff @(posedge clk_200M or negedge locked) begin
    if (~locked) reset_of_clk200M <= 1'b1;
    else reset_of_clk200M <= 1'b0;
  end

  logic reset_of_clk50M;
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk50M
  always_ff @(posedge clk_50M or negedge locked) begin
    if (~locked) reset_of_clk50M <= 1'b1;
    else reset_of_clk50M <= 1'b0;
  end

  logic reset_of_clk75M;
  // 异步复位，同步释放，将 locked 信号转为后级电路的复位 reset_of_clk50M
  always_ff @(posedge clk_50M or negedge locked) begin
    if (~locked) reset_of_clk50M <= 1'b1;
    else reset_of_clk50M <= 1'b0;
  end

  logic sys_clk;
  logic sys_rst;

  assign sys_clk = clk_75M;
  assign sys_rst = reset_of_clk75M;

  // push_btn
  logic trigger;

  button_in u_button_in (
    .clk(sys_clk),
    .reset(sys_rst),
    .push_btn(push_btn),
    .trigger(trigger)
  );

  // 不使用 CPLD 串口，禁用防止总线冲突
  assign uart_rdn = 1'b1;
  assign uart_wrn = 1'b1;

  /* =========== CPU begin =========== */
  logic        wbm0_cyc_o;
  logic        wbm0_stb_o;
  logic        wbm0_ack_i;
  logic [`ADDR_BUS] wbm0_adr_o;
  logic [`DATA_BUS] wbm0_dat_o;
  logic [`DATA_BUS] wbm0_dat_i;
  logic [`SEL] wbm0_sel_o;
  logic        wbm0_we_o;
  logic        wbm0_err_i;
  logic        wbm0_rty_i;

  logic        wbm1_cyc_o;
  logic        wbm1_stb_o;
  logic        wbm1_ack_i;
  logic [`ADDR_BUS] wbm1_adr_o;
  logic [`DATA_BUS] wbm1_dat_o;
  logic [`DATA_BUS] wbm1_dat_i;
  logic [`SEL] wbm1_sel_o;
  logic        wbm1_we_o;
  logic        wbm1_err_i;
  logic        wbm1_rty_i;

  cpu u_cpu (
      .clk_i(sys_clk),
      .rst_i(sys_rst),      

      // wishbone master
      .wbm0_cyc_o(wbm0_cyc_o),
      .wbm0_stb_o(wbm0_stb_o),
      .wbm0_ack_i(wbm0_ack_i),
      .wbm0_adr_o(wbm0_adr_o),
      .wbm0_dat_o(wbm0_dat_o),
      .wbm0_dat_i(wbm0_dat_i),
      .wbm0_sel_o(wbm0_sel_o),
      .wbm0_we_o (wbm0_we_o),
      .wbm0_err_i(wbm0_err_i),
      .wbm0_rty_i(wbm0_rty_i),

      .wbm1_cyc_o(wbm1_cyc_o),
      .wbm1_stb_o(wbm1_stb_o),
      .wbm1_ack_i(wbm1_ack_i),
      .wbm1_adr_o(wbm1_adr_o),
      .wbm1_dat_o(wbm1_dat_o),
      .wbm1_dat_i(wbm1_dat_i),
      .wbm1_sel_o(wbm1_sel_o),
      .wbm1_we_o (wbm1_we_o),
      .wbm1_err_i(wbm1_err_i),
      .wbm1_rty_i(wbm1_rty_i)

      // .wb_pc_o(wb_pc),
      // .wb_inst_o(wb_inst)
  );
  /* =========== CPU end =========== */

  /* =========== Wishbone Arbiter begin =========== */
  logic        wbs_cyc_o;
  logic        wbs_stb_o;
  logic        wbs_ack_i;
  logic [`ADDR_BUS] wbs_adr_o;
  logic [`DATA_BUS] wbs_dat_o;
  logic [`DATA_BUS] wbs_dat_i;
  logic [`SEL] wbs_sel_o;
  logic        wbs_we_o;
  logic        wbs_err_i;
  logic        wbs_rty_i;  

  wb_arbiter_2 #(
      .ARB_LSB_HIGH_PRIORITY(0)
  ) u_wb_arbiter_2(
    .clk(sys_clk),
    .rst(sys_rst),

    /*
     * Wishbone master 0 input
     */
    .wbm0_cyc_i(wbm0_cyc_o),
    .wbm0_stb_i(wbm0_stb_o),
    .wbm0_ack_o(wbm0_ack_i),
    .wbm0_adr_i(wbm0_adr_o),
    .wbm0_dat_i(wbm0_dat_o),
    .wbm0_dat_o(wbm0_dat_i),
    .wbm0_sel_i(wbm0_sel_o),
    .wbm0_we_i (wbm0_we_o), 
    .wbm0_err_o(wbm0_err_i),
    .wbm0_rty_o(wbm0_rty_i),

    /*
     * Wishbone master 1 input
     */
    .wbm1_cyc_i(wbm1_cyc_o),
    .wbm1_stb_i(wbm1_stb_o),
    .wbm1_ack_o(wbm1_ack_i),
    .wbm1_adr_i(wbm1_adr_o),
    .wbm1_dat_i(wbm1_dat_o),
    .wbm1_dat_o(wbm1_dat_i),
    .wbm1_sel_i(wbm1_sel_o),
    .wbm1_we_i (wbm1_we_o), 
    .wbm1_err_o(wbm1_err_i),
    .wbm1_rty_o(wbm1_rty_i),

    /*
     * Wishbone slave output
     */
    .wbs_cyc_o(wbs_cyc_o),
    .wbs_stb_o(wbs_stb_o),
    .wbs_ack_i(wbs_ack_i),
    .wbs_adr_o(wbs_adr_o),
    .wbs_dat_o(wbs_dat_o),
    .wbs_dat_i(wbs_dat_i),
    .wbs_sel_o(wbs_sel_o),
    .wbs_we_o (wbs_we_o),
    .wbs_err_i(wbs_err_i),
    .wbs_rty_i(wbs_rty_i)
  );

  /* =========== Wishbone Arbiter end =========== */

  /* =========== Wishbone MUX begin =========== */
  // Wishbone MUX (Masters) => bus slaves
  logic wbs0_cyc_o;
  logic wbs0_stb_o;
  logic wbs0_ack_i;
  logic [31:0] wbs0_adr_o;
  logic [31:0] wbs0_dat_o;
  logic [31:0] wbs0_dat_i;
  logic [3:0] wbs0_sel_o;
  logic wbs0_we_o;

  logic wbs1_cyc_o;
  logic wbs1_stb_o;
  logic wbs1_ack_i;
  logic [31:0] wbs1_adr_o;
  logic [31:0] wbs1_dat_o;
  logic [31:0] wbs1_dat_i;
  logic [3:0] wbs1_sel_o;
  logic wbs1_we_o;

  logic wbs2_cyc_o;
  logic wbs2_stb_o;
  logic wbs2_ack_i;
  logic [31:0] wbs2_adr_o;
  logic [31:0] wbs2_dat_o;
  logic [31:0] wbs2_dat_i;
  logic [3:0] wbs2_sel_o;
  logic wbs2_we_o;

  wb_mux_3 wb_mux (
      .clk(sys_clk),
      .rst(sys_rst),

      // Master interface (to Lab5 master)
      .wbm_adr_i(wbs_adr_o),
      .wbm_dat_i(wbs_dat_o),
      .wbm_dat_o(wbs_dat_i),
      .wbm_we_i (wbs_we_o),
      .wbm_sel_i(wbs_sel_o),
      .wbm_stb_i(wbs_stb_o),
      .wbm_ack_o(wbs_ack_i),
      .wbm_err_o(wbs_err_i),
      .wbm_rty_o(wbs_rty_i),
      .wbm_cyc_i(wbs_cyc_o),

      // Slave interface 0 (to BaseRAM controller)
      // Address range: 0x8000_0000 ~ 0x803F_FFFF
      .wbs0_addr    (32'h8000_0000),
      .wbs0_addr_msk(32'hFFC0_0000),

      .wbs0_adr_o(wbs0_adr_o),
      .wbs0_dat_i(wbs0_dat_i),
      .wbs0_dat_o(wbs0_dat_o),
      .wbs0_we_o (wbs0_we_o),
      .wbs0_sel_o(wbs0_sel_o),
      .wbs0_stb_o(wbs0_stb_o),
      .wbs0_ack_i(wbs0_ack_i),
      .wbs0_err_i('0),
      .wbs0_rty_i('0),
      .wbs0_cyc_o(wbs0_cyc_o),

      // Slave interface 1 (to ExtRAM controller)
      // Address range: 0x8040_0000 ~ 0x807F_FFFF
      .wbs1_addr    (32'h8040_0000),
      .wbs1_addr_msk(32'hFFC0_0000),

      .wbs1_adr_o(wbs1_adr_o),
      .wbs1_dat_i(wbs1_dat_i),
      .wbs1_dat_o(wbs1_dat_o),
      .wbs1_we_o (wbs1_we_o),
      .wbs1_sel_o(wbs1_sel_o),
      .wbs1_stb_o(wbs1_stb_o),
      .wbs1_ack_i(wbs1_ack_i),
      .wbs1_err_i('0),
      .wbs1_rty_i('0),
      .wbs1_cyc_o(wbs1_cyc_o),

      // Slave interface 2 (to UART controller)
      // Address range: 0x1000_0000 ~ 0x1000_FFFF
      .wbs2_addr    (32'h1000_0000),
      .wbs2_addr_msk(32'hFFFF_0000),

      .wbs2_adr_o(wbs2_adr_o),
      .wbs2_dat_i(wbs2_dat_i),
      .wbs2_dat_o(wbs2_dat_o),
      .wbs2_we_o (wbs2_we_o),
      .wbs2_sel_o(wbs2_sel_o),
      .wbs2_stb_o(wbs2_stb_o),
      .wbs2_ack_i(wbs2_ack_i),
      .wbs2_err_i('0),
      .wbs2_rty_i('0),
      .wbs2_cyc_o(wbs2_cyc_o)
  );
  /* =========== Wishbone MUX end =========== */

  /* =========== Wishbone Slaves begin =========== */
  sram_controller sram_controller_base (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs0_cyc_o),
      .wb_stb_i(wbs0_stb_o),
      .wb_ack_o(wbs0_ack_i),
      .wb_adr_i(wbs0_adr_o),
      .wb_dat_i(wbs0_dat_o),
      .wb_dat_o(wbs0_dat_i),
      .wb_sel_i(wbs0_sel_o),
      .wb_we_i (wbs0_we_o),

      // To SRAM chip
      .sram_addr(base_ram_addr),
      .sram_data(base_ram_data),
      .sram_ce_n(base_ram_ce_n),
      .sram_oe_n(base_ram_oe_n),
      .sram_we_n(base_ram_we_n),
      .sram_be_n(base_ram_be_n)
  );

  sram_controller sram_controller_ext (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      // Wishbone slave (to MUX)
      .wb_cyc_i(wbs1_cyc_o),
      .wb_stb_i(wbs1_stb_o),
      .wb_ack_o(wbs1_ack_i),
      .wb_adr_i(wbs1_adr_o),
      .wb_dat_i(wbs1_dat_o),
      .wb_dat_o(wbs1_dat_i),
      .wb_sel_i(wbs1_sel_o),
      .wb_we_i (wbs1_we_o),

      // To SRAM chip
      .sram_addr(ext_ram_addr),
      .sram_data(ext_ram_data),
      .sram_ce_n(ext_ram_ce_n),
      .sram_oe_n(ext_ram_oe_n),
      .sram_we_n(ext_ram_we_n),
      .sram_be_n(ext_ram_be_n)
  );

  // 串口控制器模块
  // NOTE: 如果修改系统时钟频率，也需要修改此处的时钟频率参数
  uart_controller #(
      .CLK_FREQ(75_000_000),
      .BAUD    (115200)
  ) uart_controller (
      .clk_i(sys_clk),
      .rst_i(sys_rst),

      .wb_cyc_i(wbs2_cyc_o),
      .wb_stb_i(wbs2_stb_o),
      .wb_ack_o(wbs2_ack_i),
      .wb_adr_i(wbs2_adr_o),
      .wb_dat_i(wbs2_dat_o),
      .wb_dat_o(wbs2_dat_i),
      .wb_sel_i(wbs2_sel_o),
      .wb_we_i (wbs2_we_o),

      // to UART pins
      .uart_txd_o(txd),
      .uart_rxd_i(rxd)
  );
  /* =========== Wishbone Slaves end =========== */

  /* =========== Demo code begin =========== */

  // always_ff @(posedge clk_10M or posedge reset_of_clk10M) begin
  //   if (reset_of_clk10M) begin
  //     // Your Code
  //   end else begin
  //     // Your Code
  //   end
  // end

  // // 不使用内存、串口时，禁用其使能信号
  // assign base_ram_ce_n = 1'b1;
  // assign base_ram_oe_n = 1'b1;
  // assign base_ram_we_n = 1'b1;

  // assign ext_ram_ce_n = 1'b1;
  // assign ext_ram_oe_n = 1'b1;
  // assign ext_ram_we_n = 1'b1;

  // assign uart_rdn = 1'b1;
  // assign uart_wrn = 1'b1;

  // // 数码管连接关系示意图，dpy1 同理
  // // p=dpy0[0] // ---a---
  // // c=dpy0[1] // |     |
  // // d=dpy0[2] // f     b
  // // e=dpy0[3] // |     |
  // // b=dpy0[4] // ---g---
  // // a=dpy0[5] // |     |
  // // f=dpy0[6] // e     c
  // // g=dpy0[7] // |     |
  // //           // ---d---  p

  // // 7 段数码管译码器演示，将 number 用 16 进制显示在数码管上面
  // logic [7:0] number;
  // SEG7_LUT segL (
  //     .oSEG1(dpy0),
  //     .iDIG (number[3:0])
  // );  // dpy0 是低位数码管
  // SEG7_LUT segH (
  //     .oSEG1(dpy1),
  //     .iDIG (number[7:4])
  // );  // dpy1 是高位数码管

  // logic [15:0] led_bits;
  // assign leds = led_bits;

  // always_ff @(posedge push_btn or posedge reset_btn) begin
  //   if (reset_btn) begin  // 复位按下，设置 LED 为初始值
  //     led_bits <= 16'h1;
  //   end else begin  // 每次按下按钮开关，LED 循环左移
  //     led_bits <= {led_bits[14:0], led_bits[15]};
  //   end
  // end

  // // 直连串口接收发送演示，从直连串口收到的数据再发送出去
  // logic [7:0] ext_uart_rx;
  // logic [7:0] ext_uart_buffer, ext_uart_tx;
  // logic ext_uart_ready, ext_uart_clear, ext_uart_busy;
  // logic ext_uart_start, ext_uart_avai;

  // assign number = ext_uart_buffer;

  // // 接收模块，9600 无检验位
  // async_receiver #(
  //     .ClkFrequency(50000000),
  //     .Baud(9600)
  // ) ext_uart_r (
  //     .clk           (clk_50M),         // 外部时钟信号
  //     .RxD           (rxd),             // 外部串行信号输入
  //     .RxD_data_ready(ext_uart_ready),  // 数据接收到标志
  //     .RxD_clear     (ext_uart_clear),  // 清除接收标志
  //     .RxD_data      (ext_uart_rx)      // 接收到的一字节数据
  // );

  // assign ext_uart_clear = ext_uart_ready; // 收到数据的同时，清除标志，因为数据已取到 ext_uart_buffer 中
  // always_ff @(posedge clk_50M) begin  // 接收到缓冲区 ext_uart_buffer
  //   if (ext_uart_ready) begin
  //     ext_uart_buffer <= ext_uart_rx;
  //     ext_uart_avai   <= 1;
  //   end else if (!ext_uart_busy && ext_uart_avai) begin
  //     ext_uart_avai <= 0;
  //   end
  // end
  // always_ff @(posedge clk_50M) begin  // 将缓冲区 ext_uart_buffer 发送出去
  //   if (!ext_uart_busy && ext_uart_avai) begin
  //     ext_uart_tx <= ext_uart_buffer;
  //     ext_uart_start <= 1;
  //   end else begin
  //     ext_uart_start <= 0;
  //   end
  // end

  // // 发送模块，9600 无检验位
  // async_transmitter #(
  //     .ClkFrequency(50000000),
  //     .Baud(9600)
  // ) ext_uart_t (
  //     .clk      (clk_50M),         // 外部时钟信号
  //     .TxD      (txd),             // 串行信号输出
  //     .TxD_busy (ext_uart_busy),   // 发送器忙状态指示
  //     .TxD_start(ext_uart_start),  // 开始发送信号
  //     .TxD_data (ext_uart_tx)      // 待发送的数据
  // );

  // // 图像输出演示，分辨率 800x600@75Hz，像素时钟为 50MHz
  // logic [11:0] hdata;
  // assign video_red   = hdata < 266 ? 3'b111 : 0;  // 红色竖条
  // assign video_green = hdata < 532 && hdata >= 266 ? 3'b111 : 0;  // 绿色竖条
  // assign video_blue  = hdata >= 532 ? 2'b11 : 0;  // 蓝色竖条
  // assign video_clk   = clk_50M;
  // vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at75 (
  //     .clk        (clk_50M),
  //     .hdata      (hdata),        // 横坐标
  //     .vdata      (),             // 纵坐标
  //     .hsync      (video_hsync),
  //     .vsync      (video_vsync),
  //     .data_enable(video_de)
  // );

  /* =========== Demo code end =========== */

endmodule
