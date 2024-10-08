//`define FULL_UART 1

`ifdef SYNTHESIS
  `define NOT_MOCK
`elsif FPGA
  `define NOT_MOCK
`elsif FULL_UART
  `define NOT_MOCK
`endif

module rt_peripherals #(
  parameter int unsigned AddrWidth = 32,
  parameter int unsigned DataWidth = 32,
  parameter int unsigned NSource   = 64,
  //parameter type         rule_t    = logic,
  localparam int         SrcW      = $clog2(NSource),
  localparam int         StrbWidth = (DataWidth / 8),
  localparam int         GpioPadNum= 4
)(
  input  logic                 clk_i,
  input  logic                 rst_ni,
  APB.Slave                    apb_i,
  output logic           [GpioPadNum-1:0] gpio_o,
  input  logic           [GpioPadNum-1:0] gpio_i,
  input  logic   [NSource-1:0] irq_src_i,
  output logic                 irq_valid_o,
  input  logic                 irq_ready_i,
  output logic      [SrcW-1:0] irq_id_o,
  output logic           [7:0] irq_level_o,
  output logic                 irq_shv_o,
  output logic           [1:0] irq_priv_o,
  output logic                 irq_kill_req_o,
  input  logic                 irq_kill_ack_i,
  output logic                 uart_tx_o,
  input  logic                 uart_rx_i
);

assign irq_valid_o = 0;
assign irq_id_o = 0;
assign irq_shv_o = 0;
assign irq_level_o = 0;
assign irq_priv_o = 0;



// INCLUSIVE END ADDR
localparam int unsigned GpioStartAddr   = 32'h0003_0000;
localparam int unsigned GpioEndAddr     = 32'h0003_00FF;
localparam int unsigned UartStartAddr   = 32'h0003_0100;
localparam int unsigned UartEndAddr     = 32'h0003_01FF;
localparam int unsigned MTimerStartAddr = 32'h0003_0200;
localparam int unsigned MTimerEndAddr   = 32'h0003_0210;
localparam int unsigned ClicStartAddr   = 32'h0005_0000;
localparam int unsigned ClicEndAddr     = 32'h0005_FFFF;

localparam int unsigned NrApbPerip = 4;


//logic                   irq_ready_delay, irq_ready_delay_q, irq_ready_q;
logic                   uart_irq;

logic             [1:0] demux_sel;
logic     [NSource-1:0] intr_src;
logic                   mtimer_irq;

logic                   periph_clk;

APB #(
  .ADDR_WIDTH (AddrWidth),
  .DATA_WIDTH (DataWidth)
) apb_out [NrApbPerip-1:0] (), apb_div ();
/*

always_comb
  begin : irq_assign
    intr_src = intr_src_i;
    intr_src[17] = uart_irq; // supervisor software irq
    intr_src[7] = mtimer_irq;
    // supervisor external irq 9
    // machine external irq 11
    // platform defined 16-19
    // nmi 31
  end
*/
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
    .DIV_VALUE (2),
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
    .divider_conf (2),
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
/*
// 2x delay logic for irq_ready
// TODO: make generic
always_ff @(posedge(clk_i) or negedge(rst_ni))
  begin : ready_delay
    if (~rst_ni) begin
      irq_ready_q       <= 0;
      irq_ready_delay_q <= 0;
    end else begin
      irq_ready_q       <= irq_ready_i;
      irq_ready_delay_q <= irq_ready_delay;
    end
  end

assign irq_ready_delay = irq_ready_i | irq_ready_q;
// end 2x delay

*/
always_comb
  begin : decode // TODO: Make enum for values
    unique case (apb_div.paddr) inside
      [GpioStartAddr:GpioEndAddr]: begin
        demux_sel = 2'b00;
      end
      [UartStartAddr:UartEndAddr]: begin
        demux_sel = 2'b01;
      end
      [MTimerStartAddr:MTimerEndAddr]: begin
        demux_sel = 2'b10;
      end
      [ClicStartAddr:ClicEndAddr]: begin
        demux_sel = 2'b11;
      end
      default: begin
        demux_sel = 2'b00;
      end
    endcase
  end
/*
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
  .irq_ready_i    (irq_ready_delay_q),
  .irq_id_o       (irq_id_o),
  .irq_level_o    (irq_level_o),
  .irq_shv_o      (irq_shv_o),
  .irq_priv_o     (irq_priv_o),
  .irq_kill_req_o (irq_kill_req_o),
  .irq_kill_ack_i (1'b0 ) //irq_kill_ack_i)
);


*/

apb_gpio #(
  .APB_ADDR_WIDTH (AddrWidth),
  .PAD_NUM        (GpioPadNum),
  .NBIT_PADCFG    (4)
) i_gpio (
  .HRESETn        (rst_ni),
  .HCLK           (periph_clk),
  .gpio_in        (gpio_input_i),
  .gpio_out       (gpio_output_o),
  .PENABLE        (apb_out[0].penable),
  .PWRITE         (apb_out[0].pwrite),
  .PADDR          (apb_out[0].paddr),
  .PSEL           (apb_out[0].psel),
  .pwdata_i       (apb_out[0].pwdata),
  .PRDATA         (apb_out[0].prdata),
  .PREADY         (apb_out[0].pready),
  .PSLVERR        (apb_out[0].pslverr),
  .interrupt      ()
);



`ifdef NOT_MOCK
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


/*
rt_timer #() i_timer (
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
*/


endmodule : rt_peripherals
