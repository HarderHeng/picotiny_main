`timescale 1ns/1ps

module soc (
  input clk,
  input resetn,

  output  flash_clk,
  output  flash_csb,
  inout   flash_mosi,
  inout   flash_miso,

  input  ser_rx,
  output ser_tx,
  inout [6:0] gpio
);
 wire sys_resetn;

 wire cpu_mem_valid;
 wire cpu_mem_ready;
 wire [31:0] cpu_mem_addr;
 wire [31:0] cpu_mem_wdata;
 wire [3:0] cpu_mem_wstrb;
 wire [31:0] cpu_mem_rdata;

 wire wbp_valid;
 wire wbp_ready;
 wire [31:0] wbp_addr;
 wire [31:0] wbp_wdata;
 wire [3:0] wbp_wstrb;
 wire [31:0] wbp_rdata;

 wire spimem_valid;
 wire spimem_ready;
 wire [31:0] spimem_addr;
 wire [31:0] spimem_wdata;
 wire [3:0] spimem_wstrb;
 wire [31:0] spimem_rdata;

 wire spicfg_valid;
 wire spicfg_ready;
 wire [31:0] spicfg_addr;
 wire [31:0] spicfg_wdata;
 wire [3:0] spicfg_wstrb;
 wire [31:0] spicfg_rdata;

 wire sram_valid;
 wire sram_ready;
 wire [31:0] sram_addr;
 wire [31:0] sram_wdata;
 wire [3:0] sram_wstrb;
 wire [31:0] sram_rdata;

 wire brom_valid;
 wire brom_ready;
 wire [31:0] brom_addr;
 wire [31:0] brom_wdata;
 wire [3:0] brom_wstrb;
 wire [31:0] brom_rdata;

 wire periph_valid;
 wire periph_ready;
 wire [31:0] periph_addr;
 wire [31:0] periph_wdata;
 wire [3:0] periph_wstrb;
 wire [31:0] periph_rdata;

 wire gpio_valid;
 wire gpio_ready;
 wire [31:0] gpio_addr;
 wire [31:0] gpio_wdata;
 wire [3:0] gpio_wstrb;
 wire [31:0] gpio_rdata;

 wire uart_valid;
 wire uart_ready;
 wire [31:0] uart_addr;
 wire [31:0] uart_wdata;
 wire [3:0] uart_wstrb;
 wire [31:0] uart_rdata;

 wire sys_clk;
 wire sys_clk_5x;
 wire pll_lock;

 Gowin_rPLL pll (
   .clkin(clk),
   .clkout(sys_clk_5x),
   .lock(pll_lock)
 );

 Gowin_CLKDIV clkdiv (
     .clkout(sys_clk),
     .hclkin(sys_clk_5x),
     .resetn(pll_lock)
 );

 reset_sync reset_sync (
   .resetn(sys_resetn),
   .ext_reset(resetn & pll_lock),
   .clk(sys_clk)
 );

 picorv32 cpu (
    .clk(sys_clk),
    .resetn(sys_resetn),
    .trap(),
    .mem_valid(cpu_mem_valid),
    .mem_instr(),
    .mem_ready(cpu_mem_ready),
    .mem_addr(cpu_mem_addr),
    .mem_wdata(cpu_mem_wdata),
    .mem_wstrb(cpu_mem_wstrb),
    .mem_rdata(cpu_mem_rdata),
    .irq(32'b0),
    .eoi()
  );

  sram sram (
   .resetn(sys_resetn),
   .clk(sys_clk),
   .mem_s_valid(sram_valid),
   .mem_s_ready(sram_ready),
   .mem_s_addr(sram_addr),
   .mem_s_wdata(sram_wdata),
   .mem_s_wstrb(sram_wstrb),
   .mem_s_rdata(sram_rdata)
  );

  // S0 0x0000_0000 -> SPI Flash XIP
  // S1 0x4000_0000 -> SRAM
  // S2 0x8000_0000 -> Peripheral
  // S3 0xC000_0000 -> Wishbone
  mux mem_mux (
   .picom_valid(cpu_mem_valid),
   .picom_ready(cpu_mem_ready),
   .picom_addr(cpu_mem_addr),
   .picom_wdata(cpu_mem_wdata),
   .picom_wstrb(cpu_mem_wstrb),
   .picom_rdata(cpu_mem_rdata),

   .picos0_valid(spimem_valid),
   .picos0_ready(spimem_ready),
   .picos0_addr(spimem_addr),
   .picos0_wdata(spimem_wdata),
   .picos0_wstrb(spimem_wstrb),
   .picos0_rdata(spimem_rdata),

   .picos1_valid(sram_valid),
   .picos1_ready(sram_ready),
   .picos1_addr(sram_addr),
   .picos1_wdata(sram_wdata),
   .picos1_wstrb(sram_wstrb),
   .picos1_rdata(sram_rdata),

   .picos2_valid(periph_valid),
   .picos2_ready(periph_ready),
   .picos2_addr(periph_addr),
   .picos2_wdata(periph_wdata),
   .picos2_wstrb(periph_wstrb),
   .picos2_rdata(periph_rdata),

   .picos3_valid(wbp_valid),
   .picos3_ready(wbp_ready),
   .picos3_addr(wbp_addr),
   .picos3_wdata(wbp_wdata),
   .picos3_wstrb(wbp_wstrb),
   .picos3_rdata(wbp_rdata)
  );

 // S0 0x8000_0000 -> BOOTROM
 // S1 0x8100_0000 -> SPI Flash Config
 // S2 0x8200_0000 -> GPIO
 // S3 0x8300_0000 -> UART
  mux #(
    .PICOS0_ADDR_BASE(32'h8000_0000),
    .PICOS0_ADDR_MASK(32'h0F00_0000),
    .PICOS1_ADDR_BASE(32'h8100_0000),
    .PICOS1_ADDR_MASK(32'h0F00_0000),
    .PICOS2_ADDR_BASE(32'h8200_0000),
    .PICOS2_ADDR_MASK(32'h0F00_0000),
    .PICOS3_ADDR_BASE(32'h8300_0000),
    .PICOS3_ADDR_MASK(32'h0F00_0000)
  ) periph_mux (
   .picom_valid(periph_valid),
   .picom_ready(periph_ready),
   .picom_addr(periph_addr),
   .picom_wdata(periph_wdata),
   .picom_wstrb(periph_wstrb),
   .picom_rdata(periph_rdata),

   .picos0_valid(brom_valid),
   .picos0_ready(brom_ready),
   .picos0_addr(brom_addr),
   .picos0_wdata(brom_wdata),
   .picos0_wstrb(brom_wstrb),
   .picos0_rdata(brom_rdata),

   .picos1_valid(spicfg_valid),
   .picos1_ready(spicfg_ready),
   .picos1_addr(spicfg_addr),
   .picos1_wdata(spicfg_wdata),
   .picos1_wstrb(spicfg_wstrb),
   .picos1_rdata(spicfg_rdata),

   .picos2_valid(gpio_valid),
   .picos2_ready(gpio_ready),
   .picos2_addr(gpio_addr),
   .picos2_wdata(gpio_wdata),
   .picos2_wstrb(gpio_wstrb),
   .picos2_rdata(gpio_rdata),

   .picos3_valid(uart_valid),
   .picos3_ready(uart_ready),
   .picos3_addr(uart_addr),
   .picos3_wdata(uart_wdata),
   .picos3_wstrb(uart_wstrb),
   .picos3_rdata(uart_rdata)
  );

  spi_flash spi_flash (
   .clk    (sys_clk),
   .resetn (sys_resetn),

   .flash_csb  (flash_csb),
   .flash_clk  (flash_clk),
   .flash_mosi (flash_mosi),
   .flash_miso (flash_miso),

   .flash_mem_valid  (spimem_valid),
   .flash_mem_ready  (spimem_ready),
   .flash_mem_addr   (spimem_addr),
   .flash_mem_wdata  (spimem_wdata),
   .flash_mem_wstrb  (spimem_wstrb),
   .flash_mem_rdata  (spimem_rdata),

   .flash_cfg_valid  (spicfg_valid),
   .flash_cfg_ready  (spicfg_ready),
   .flash_cfg_addr   (spicfg_addr),
   .flash_cfg_wdata  (spicfg_wdata),
   .flash_cfg_wstrb  (spicfg_wstrb),
   .flash_cfg_rdata  (spicfg_rdata)
  );

  bootrom bootrom (
   .resetn(sys_resetn),
   .clk(sys_clk),
   .mem_s_valid(brom_valid),
   .mem_s_ready(brom_ready),
   .mem_s_addr(brom_addr),
   .mem_s_wdata(brom_wdata),
   .mem_s_wstrb(brom_wstrb),
   .mem_s_rdata(brom_rdata)
  );

  gpio gpio_inst (
   .resetn(sys_resetn),
   .io(gpio),
   .clk(sys_clk),
   .busin_valid(gpio_valid),
   .busin_ready(gpio_ready),
   .busin_addr(gpio_addr),
   .busin_wdata(gpio_wdata),
   .busin_wstrb(gpio_wstrb),
   .busin_rdata(gpio_rdata)
  );

  uart uart (
   .resetn(sys_resetn),
   .clk(sys_clk),
   .mem_s_valid(uart_valid),
   .mem_s_ready(uart_ready),
   .mem_s_addr(uart_addr),
   .mem_s_wdata(uart_wdata),
   .mem_s_wstrb(uart_wstrb),
   .mem_s_rdata(uart_rdata),
   .ser_rx(ser_rx),
   .ser_tx(ser_tx)
  );


assign wbp_ready = 1'b1;

endmodule
