`include "register_interface/typedef.svh"

module rt_peripherals #(
  parameter int unsigned  AddrWidth      = 32,
  parameter int unsigned  DataWidth      = 32,
  parameter int unsigned  NSource        = 64,
  localparam int unsigned SrcW           = $clog2(NSource),
  localparam int unsigned StrbWidth      = (DataWidth / 8),
  localparam int unsigned GpioPadNum     = 4,
  localparam int unsigned TimerGroupSize = 4
)(
  input  logic                 clk_i,
  input  logic                 rst_ni,
  APB.Slave                    apb_i,
  input  logic   [NSource-1:0] irq_src_i,
  output logic                 irq_valid_o,
  input  logic                 irq_ready_i,
  output logic      [SrcW-1:0] irq_id_o,
  output logic           [7:0] irq_level_o,
  output logic                 irq_shv_o,
  output logic           [1:0] irq_priv_o,
  output logic                 irq_is_pcs_o,
  output logic                 irq_kill_req_o,
  input  logic                 irq_kill_ack_i,

  output logic  [GpioPadNum-1:0] gpio_o,
  input  logic  [GpioPadNum-1:0] gpio_i,

  output logic                 uart_tx_o,
  input  logic                 uart_rx_i,

  input  logic           [3:0] spi_sdi_i,
  output logic           [3:0] spi_sdo_o,
  output logic           [3:0] spi_csn_o,
  output logic                 spi_clk_o,

  input  logic [rt_pkg::NumDMAs-1:0] dma_irqs_i
);

/////////////////////
// CLIC IRQS Enums //
/////////////////////

typedef enum integer {
  MtimerIrqId = 7,
  UartIrqId   = 17,
  GpioIrqId   = 18,
  SpiRxTxIrqId= 19,
  SpiEotIrqId = 20,
  TGIrqIdBase = 21  // apb_timer interrupt can have multiple irq lines (2 per timer group)
} clic_int_ids_e;

// INCLUSIVE END ADDR
localparam int unsigned GpioStartAddr     = 32'h0003_0000;
localparam int unsigned GpioEndAddr       = 32'h0003_00FF;
localparam int unsigned UartStartAddr     = 32'h0003_0100;
localparam int unsigned UartEndAddr       = 32'h0003_01FF;
localparam int unsigned MTimerStartAddr   = 32'h0003_0200;
localparam int unsigned MTimerEndAddr     = 32'h0003_0210;
localparam int unsigned ApbTimerStartAddr = 32'h0003_0300;
localparam int unsigned ApbTimerEndAddr   = 32'h0003_03FF;
localparam int unsigned ApbSpiMasterStartAddr = 32'h0003_0400;
localparam int unsigned ApbSpiMasterEndAddr   = 32'h0003_04FF;
localparam int unsigned ClicStartAddr     = 32'h0005_0000;
localparam int unsigned ClicEndAddr       = 32'h0005_FFFF;

localparam int unsigned NrApbPerip    = 6;
localparam int unsigned SelWidth      = $clog2(NrApbPerip);
localparam int unsigned ClkDivDef     = 2;
localparam int unsigned DivValueWidth = 4;

logic                   irq_ready_slow;
logic [rt_pkg::NumDMAs-1:0] dma_irqs_q;

logic [SelWidth-1:0]    demux_sel;
logic                   irq_ready_delay, irq_ready_delay_q, irq_ready_q;
logic                   uart_irq;

logic [NSource-1:0]         intr_src;
logic                       mtimer_irq;
logic                       gpio_irq;
logic [2*TimerGroupSize-1:0]apb_timer_irq;
logic [1:0]                 spi_irqs;

logic [DivValueWidth-1:0]   periph_div;
logic                       periph_clk;

// TODO: make SW-configurable
assign periph_div = ClkDivDef;

APB #(
  .ADDR_WIDTH (AddrWidth),
  .DATA_WIDTH (DataWidth)
) apb_out [NrApbPerip-1:0] (), apb_div ();

always_comb
  begin : irq_assign
    intr_src = irq_src_i;
    intr_src[UartIrqId]    = uart_irq; // supervisor software irq
    intr_src[GpioIrqId]    = gpio_irq;
    intr_src[MtimerIrqId]  = mtimer_irq;
    intr_src[SpiRxTxIrqId] = spi_irqs[0];
    intr_src[SpiEotIrqId]  = spi_irqs[1];
    intr_src[TGIrqIdBase+2*TimerGroupSize-1:TGIrqIdBase] = apb_timer_irq;
    intr_src[32 +: rt_pkg::NumDMAs] = dma_irqs_q; // reserve irqs 32-48 for DMAs
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

  clk_int_div #(
    .DIV_VALUE_WIDTH       (DivValueWidth),
    .DEFAULT_DIV_VALUE     (ClkDivDef),
    .ENABLE_CLOCK_IN_RESET (1'b1)
  ) i_clk_int_div (
    .clk_i,
    .rst_ni,
    .en_i           (1'b1),
    .test_mode_en_i (1'b0),
    .div_i          (periph_div),
    .div_valid_i    (1'b1),
    .div_ready_o    (),
    .clk_o          (periph_clk),
    .cycl_count_o   ()
  );

`else

  configurable_clock_divider_fpga i_clk_div (
    .clk_in       (clk_i),
    .rst_n        (rst_ni),
    .divider_conf (periph_div),
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
  .DivMax (DivValueWidth)
) i_irq_ready_sync (
  .rst_ni,
  .divisor_i (periph_div),
  .clk_a_i   (clk_i),
  .clk_b_i   (periph_clk),
  .pulse_i   (irq_ready_i),
  .pulse_o   (irq_ready_slow)
);

for (genvar ii=0; ii<rt_pkg::NumDMAs; ii++)
  begin : g_dma_sync
    irq_pulse_cdc #(
      .DivMax (DivValueWidth)
    ) i_dma_sync (
      .rst_ni,
      .divisor_i (periph_div),
      .clk_a_i   (clk_i),
      .clk_b_i   (periph_clk),
      .pulse_i   (dma_irqs_i[ii]),
      .pulse_o   (dma_irqs_q[ii])
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
      [ApbTimerStartAddr:ApbTimerEndAddr]: begin
        demux_sel = SelWidth'('h5);
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
  .irq_is_pcs_o   (irq_is_pcs_o),
  .irq_kill_req_o (irq_kill_req_o),
  .irq_kill_ack_i (irq_kill_ack_i)
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
  .interrupt      (gpio_irq)
);

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

apb_timer #(
  .APB_ADDR_WIDTH(AddrWidth),
  .TIMER_CNT(TimerGroupSize)
) i_apb_timer (
  .HCLK           (periph_clk),
  .HRESETn        (rst_ni),
  .PENABLE        (apb_out[5].penable),
  .PWRITE         (apb_out[5].pwrite),
  .PADDR          (apb_out[5].paddr),
  .PSEL           (apb_out[5].psel),
  .PWDATA         (apb_out[5].pwdata),
  .PRDATA         (apb_out[5].prdata),
  .PREADY         (apb_out[5].pready),
  .PSLVERR        (apb_out[5].pslverr),
  .irq_o          (apb_timer_irq)
);


apb_spi_master #(
  .APB_ADDR_WIDTH      (AddrWidth),
  .BUFFER_DEPTH        (10)
) i_apb_spi_master1(
  .HCLK           (periph_clk),
  .HRESETn        (rst_ni),
  .PENABLE        (apb_out[4].penable),
  .PWRITE         (apb_out[4].pwrite),
  .PADDR          (apb_out[4].paddr),
  .PSEL           (apb_out[4].psel),
  .PWDATA         (apb_out[4].pwdata),
  .PRDATA         (apb_out[4].prdata),
  .PREADY         (apb_out[4].pready),
  .PSLVERR        (apb_out[4].pslverr),
  .events_o       (spi_irqs),

  // Interface: spi_master
  .spi_sdi0       (spi_sdi_i[0]),
  .spi_sdi1       (spi_sdi_i[1]),
  .spi_sdi2       (spi_sdi_i[2]),
  .spi_sdi3       (spi_sdi_i[3]),
  .spi_clk        (spi_clk_o),
  .spi_csn0       (spi_csn_o[0]),
  .spi_csn1       (spi_csn_o[1]),
  .spi_csn2       (spi_csn_o[2]),
  .spi_csn3       (spi_csn_o[3]),
  .spi_mode       (),
  .spi_sdo0       (spi_sdo_o[0]),
  .spi_sdo1       (spi_sdo_o[1]),
  .spi_sdo2       (spi_sdo_o[2]),
  .spi_sdo3       (spi_sdo_o[3])
  );

endmodule : rt_peripherals
