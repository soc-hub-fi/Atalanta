`include "register_interface/typedef.svh"

module rt_peripherals #(
  parameter int unsigned AddrWidth = 32,
  parameter int unsigned DataWidth = 32,
  parameter int unsigned NSource   = 64,
  localparam int         SrcW      = $clog2(NSource),
  localparam int         StrbWidth = (DataWidth / 8),
  localparam int         GpioPadNum= 4
)(
  input  logic                       clk_i,
  input  logic                       rst_ni,
  APB.Slave                          apb_i,
  output logic      [GpioPadNum-1:0] gpio_o,
  input  logic      [GpioPadNum-1:0] gpio_i,
  input  logic   [NSource-1:0]       irq_src_i,
  output logic                       irq_valid_o,
  input  logic                       irq_ready_i,
  output logic      [SrcW-1:0]       irq_id_o,
  output logic           [7:0]       irq_level_o,
  output logic                       irq_shv_o,
  output logic           [1:0]       irq_priv_o,
  output logic                       irq_kill_req_o,
  input  logic                       irq_kill_ack_i,
  output logic                       uart_tx_o,
  input  logic                       uart_rx_i,
  input  logic [rt_pkg::NumDMAs-1:0] dma_irqs_i
);

localparam int unsigned NrApbPerip = 5;
localparam int unsigned SelWidth   = $clog2(NrApbPerip);
localparam int unsigned ClkDiv     = 2;

logic                   irq_ready_slow;
logic [rt_pkg::NumDMAs-1:0] dma_irqs_q;
logic                   uart_irq;

logic [SelWidth-1:0] demux_sel;
logic  [NSource-1:0] intr_src;
logic                mtimer_irq;

logic                   periph_clk;

APB #(
  .ADDR_WIDTH (AddrWidth),
  .DATA_WIDTH (DataWidth)
) apb_out [NrApbPerip-1:0] (), apb_div ();

always_comb
  begin : irq_assign
    intr_src     = irq_src_i;
    intr_src[17] = uart_irq;   // supervisor software irq
    intr_src[7]  = mtimer_irq;
    // supervisor external irq 9
    // machine external irq 11
    // platform defined 16-19
    intr_src[32 +: rt_pkg::NumDMAs] = dma_irqs_q; // serve irqs 32-48 for DMAs
    // nmi 31
  end

apb_cdc_intf #(
  .APB_ADDR_WIDTH (AddrWidth),
  .APB_DATA_WIDTH (DataWidth)
) i_apb_cdc (
  .src_pclk_i     (clk_i),
  .src_preset_ni  (rst_ni),
  .src            (apb_i),
  .dst_pclk_i     (periph_clk),
  .dst_preset_ni  (rst_ni),
  .dst            (apb_div)
);

`ifndef FPGA

  clk_int_div_static #(
    .DIV_VALUE (ClkDiv),
    .ENABLE_CLOCK_IN_RESET (1'b0)
  ) i_clk_div (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .en_i           (1'b1),
    .test_mode_en_i (1'b0),
    .clk_o          (periph_clk)
  );

`else

  configurable_clock_divider_fpga i_clk_div (
    .clk_in       (clk_i),
    .rst_n        (rst_ni),
    .divider_conf (ClkDiv),
    .clk_out      (periph_clk)
  );

`endif


apb_demux_intf #(
  .APB_ADDR_WIDTH (AddrWidth),
  .APB_DATA_WIDTH (DataWidth),
  .NoMstPorts     (NrApbPerip)
) i_apb_demux (
  .slv      (apb_div),
  .mst      (apb_out),
  .select_i (demux_sel)
);

irq_pulse_cdc #(
  .Divisor (ClkDiv)
) i_irq_ready_sync (
  .rst_ni,
  .clk_a_i (clk_i),
  .clk_b_i (periph_clk),
  .pulse_i (irq_ready_i),
  .pulse_o (irq_ready_slow)
);

for (genvar ii=0; ii<rt_pkg::NumDMAs; ii++)
  begin : g_dma_sync
    irq_pulse_cdc #(
      .Divisor (ClkDiv)
    ) i_dma_sync (
      .rst_ni,
      .clk_a_i (clk_i),
      .clk_b_i (periph_clk),
      .pulse_i (dma_irqs_i[ii]),
      .pulse_o (dma_irqs_q[ii])
    );
  end : g_dma_sync

always_comb
  begin : decode // TODO: Make enum for values
    unique case (apb_div.paddr) inside
      [rt_pkg::GpioStartAddr:rt_pkg::GpioEndAddr]: begin
        demux_sel = SelWidth'('h0);
      end
      [rt_pkg::UartStartAddr:rt_pkg::UartEndAddr]: begin
        demux_sel = SelWidth'('h1);
      end
      [rt_pkg::MTimerStartAddr:rt_pkg::MTimerEndAddr]: begin
        demux_sel = SelWidth'('h2);
      end
      [rt_pkg::ClicStartAddr:rt_pkg::ClicEndAddr]: begin
        demux_sel = SelWidth'('h3);
      end
      [rt_pkg::SpiStartAddr:rt_pkg::SpiEndAddr]: begin
        demux_sel = SelWidth'('h4);
      end
      default: begin
        demux_sel = SelWidth'('h0);
      end
    endcase
  end

clic_apb #(
  .N_SOURCE     (NSource),
  .INTCTLBITS   (8)
) i_clic (
  .clk_i          (periph_clk),
  .rst_ni         (rst_ni),
  .penable_i      (apb_out[3].penable),
  .pwrite_i       (apb_out[3].pwrite),
  .paddr_i        (apb_out[3].paddr),
  .psel_i         (apb_out[3].psel),
  .pwdata_i       (apb_out[3].pwdata),
  .prdata_o       (apb_out[3].prdata),
  .pready_o       (apb_out[3].pready),
  .pslverr_o      (apb_out[3].pslverr),
  .intr_src_i     (intr_src), // 0-31 -> CLINT IRQS
  .irq_valid_o    (irq_valid_o),
  .irq_ready_i    (irq_ready_slow),
  .irq_id_o       (irq_id_o),
  .irq_level_o    (irq_level_o),
  .irq_shv_o      (irq_shv_o),
  .irq_priv_o     (irq_priv_o),
  .irq_kill_req_o (irq_kill_req_o),
  .irq_kill_ack_i (1'b0 ) //irq_kill_ack_i)
);

apb_gpio #(
  .APB_ADDR_WIDTH (AddrWidth),
  .PAD_NUM        (GpioPadNum)
) i_gpio (
  .HRESETn        (rst_ni),
  .HCLK           (periph_clk),
  .gpio_in        (gpio_i),
  .gpio_out       (gpio_o),
  .PENABLE        (apb_out[0].penable),
  .PWRITE         (apb_out[0].pwrite),
  .PADDR          (apb_out[0].paddr),
  .PSEL           (apb_out[0].psel),
  .PWDATA         (apb_out[0].pwdata),
  .PRDATA         (apb_out[0].prdata),
  .PREADY         (apb_out[0].pready),
  .PSLVERR        (apb_out[0].pslverr),
  .interrupt      ()
);

// APB to REG_BUS boilerplate
`REG_BUS_TYPEDEF_ALL(regbus, logic [31:0], logic [31:0], logic [3:0])

regbus_req_t spi_req;
regbus_rsp_t spi_rsp;

assign spi_req.addr  = apb_out[4].paddr;
assign spi_req.wdata = apb_out[4].pwdata;
assign spi_req.wstrb = '1;
assign spi_req.write = apb_out[4].pwrite;
assign spi_req.valid = apb_out[4].psel & apb_out[4].penable;

assign apb_out[4].prdata  = spi_rsp.rdata;
assign apb_out[4].pslverr = spi_rsp.error;
assign apb_out[4].pready  = spi_rsp.ready;
//

/*
spi_host #(
  .reg_req_t (regbus_req_t),
  .reg_rsp_t (regbus_rsp_t)
) i_spih (
  .clk_i,
  .rst_ni,
  .reg_req_i        (spi_req),
  .reg_rsp_o        (spi_rsp),
  .cio_sck_o        (),
  .cio_sck_en_o     (),
  .cio_csb_o        (),
  .cio_csb_en_o     (),
  .cio_sd_o         (),
  .cio_sd_en_o      (),
  .cio_sd_i         ('0),
  .intr_error_o     (),
  .intr_spi_event_o ()
);*/

`ifndef VERILATOR
apb_uart i_apb_uart (
  .CLK      (periph_clk),
  .RSTN     (rst_ni),
  .PSEL     (apb_out[1].psel),
  .PENABLE  (apb_out[1].penable),
  .PWRITE   (apb_out[1].pwrite),
  .PADDR    (apb_out[1].paddr[4:2]),
  .PWDATA   (apb_out[1].pwdata),
  .PRDATA   (apb_out[1].prdata),
  .PREADY   (apb_out[1].pready),
  .PSLVERR  (apb_out[1].pslverr),
  .INT      (uart_irq),
  .CTSN     (1'b0),
  .DSRN     (1'b0),
  .DCDN     (1'b0),
  .RIN      (1'b0),
  .RTSN     (),
  .OUT1N    (),
  .OUT2N    (),
  .DTRN     (),
  .SIN      (uart_rx_i),
  .SOUT     (uart_tx_o)
);
`else
mock_uart i_apb_uart (
  .clk_i     (periph_clk),
  .rst_ni    (rst_ni),
  .penable_i (apb_out[1].penable),
  .pwrite_i  (apb_out[1].pwrite),
  .paddr_i   (apb_out[1].paddr),
  .psel_i    (apb_out[1].psel),
  .pwdata_i  (apb_out[1].pwdata),
  .prdata_o  (apb_out[1].prdata),
  .pready_o  (apb_out[1].pready),
  .pslverr_o (apb_out[1].pslverr)
);

assign uart_irq  = 1'b0;   // to avoid X's cascading through CLIC
assign uart_tx_o = 0;
`endif

// TODO: add generic apb timer peripheral

apb_mtimer #() i_mtimer (
  .clk_i       (periph_clk),
  .rst_ni      (rst_ni),
  .timer_irq_o (mtimer_irq),
  .penable_i   (apb_out[2].penable),
  .pwrite_i    (apb_out[2].pwrite),
  .paddr_i     (apb_out[2].paddr),
  .psel_i      (apb_out[2].psel),
  .pwdata_i    (apb_out[2].pwdata),
  .prdata_o    (apb_out[2].prdata),
  .pready_o    (apb_out[2].pready),
  .pslverr_o   (apb_out[2].pslverr)
);


endmodule : rt_peripherals
