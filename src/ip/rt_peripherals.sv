`ifdef SYNTHESIS
  `define NOT_MOCK
`elsif FPGA
  `define NOT_MOCK
`elsif FULL_UART
  `define NOT_MOCK
`endif

module rt_peripherals #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned ADDR_WIDTH = 32
)(
  input  logic        clk_i,
  input  logic        rst_ni,
  output logic [ 3:0] gpio_output_o,
  input  logic [ 3:0] gpio_input_i,
  output logic        mtimer_irq_o,
  output logic        fetch_enable_o,
  output logic        cpu_rst_o,
  output logic [23:0] cpu_boot_addr_o,
  output logic        uart_tx_o,
  input  logic        uart_rx_i,
  output logic        uart_intr_o,
  AXI_LITE.Slave      axi_lite_slv
);

// INCLUSIVE END ADDR
localparam int unsigned GpioStartAddr   = 32'h0003_0000;
localparam int unsigned GpioEndAddr     = 32'h0003_00FF;
localparam int unsigned UartStartAddr   = 32'h0003_0100;
localparam int unsigned UartEndAddr     = 32'h0003_01FF;
localparam int unsigned MTimerStartAddr = 32'h0003_0200;
localparam int unsigned MTimerEndAddr   = 32'h0003_0210;

AXI_LITE #(
  .AXI_ADDR_WIDTH ( ADDR_WIDTH ),
  .AXI_DATA_WIDTH ( DATA_WIDTH )
) in_lite_bus [2:0] ();

AXI_LITE #(
  .AXI_ADDR_WIDTH ( ADDR_WIDTH ),
  .AXI_DATA_WIDTH ( DATA_WIDTH )
) out_lite_bus [2:0] ();


typedef logic [ADDR_WIDTH-1:0] addr_t;
typedef logic [DATA_WIDTH-1:0] data_t;
typedef logic [DATA_WIDTH/8-1:0] strb_t;

addr_t       paddr;
logic  [2:0] pprot;
logic        psel;
logic        penable;
logic        pwrite;
data_t       pwdata;
strb_t       pstrb;
logic        pready;
data_t       prdata;
logic        pslverr;

logic [1:0] demux_ar_select;
logic [1:0] demux_aw_select;

//TODO: move common x2y boilerplate to rt_pkg.sv
typedef struct packed {
  int unsigned idx;
  addr_t       start_addr;
  addr_t       end_addr;
} apb_rule_t;

apb_rule_t addr_map = { /*idx:*/ 32'h0,
                      /*start_addr:*/ UartStartAddr,
                      /*end_addr:*/   UartEndAddr+4
                      };


always_comb
begin : decode // TODO: Make enum for values
  unique case (axi_lite_slv.aw_addr) inside
    [GpioStartAddr:GpioEndAddr]: begin
      demux_aw_select = 2'b00;
    end
    [UartStartAddr:UartEndAddr]: begin
      demux_aw_select = 2'b01;
    end
    [MTimerStartAddr:MTimerEndAddr]: begin
      demux_aw_select = 2'b10;
    end
    default: begin
      // nothing
    end
  endcase
  unique case (axi_lite_slv.ar_addr) inside
    [GpioStartAddr:GpioEndAddr]: begin
      demux_ar_select = 2'b00;
    end
    [UartStartAddr:UartEndAddr]: begin
      demux_ar_select = 2'b01;
    end
    [MTimerStartAddr:MTimerEndAddr]: begin
      demux_ar_select = 2'b10;
    end
    default: begin
      // nothing
    end
endcase
end

axi_lite_demux_intf #(
  .AxiAddrWidth ( ADDR_WIDTH ),
  .AxiDataWidth ( DATA_WIDTH ),
  .NoMstPorts   ( 3          ),
  .MaxTrans     ( 1          )
) i_axi_demux (
  .clk_i           ( clk_i           ),
  .rst_ni          ( rst_ni          ),
  .test_i          ( 1'b0            ),
  .slv             ( axi_lite_slv    ),
  .slv_aw_select_i ( demux_aw_select ),
  .slv_ar_select_i ( demux_ar_select ),
  .mst             ( in_lite_bus     )
);

axi_lite_join_intf#() i_axi_join_gpio (
  .in (  in_lite_bus[0] ),
  .out( out_lite_bus[0] )
);

axi_lite_join_intf#() i_axi_join_uart (
  .in (  in_lite_bus[1] ),
  .out( out_lite_bus[1] )
);

axi_lite_join_intf#() i_axi_join_timer (
  .in (  in_lite_bus[2] ),
  .out( out_lite_bus[2] )
);


axi_lite_to_apb_intf #(
  .AddrWidth   (ADDR_WIDTH),
  .DataWidth   (DATA_WIDTH),
  .NoRules     (1         ),
  .NoApbSlaves (1         ),
  .rule_t      (apb_rule_t)
) i_lite_to_apb (
  .clk_i     ( clk_i           ),
  .rst_ni    ( rst_ni          ),
  .slv       ( out_lite_bus[1] ),
  .paddr_o   ( paddr           ),
  .pprot_o   ( pprot           ),
  .pselx_o   ( psel            ),
  .penable_o ( penable         ),
  .pwrite_o  ( pwrite          ),
  .pwdata_o  ( pwdata          ),
  .pstrb_o   ( pstrb           ),
  .pready_i  ( pready          ),
  .prdata_i  ( prdata          ),
  .pslverr_i ( pslverr         ),
  .addr_map_i( addr_map        )
);

rt_gpio #() i_gpio (
  .rst_ni         ( rst_ni         ),
  .clk_i          ( clk_i          ),
  .fetch_enable_o ( fetch_enable_o ),
  .gpio_input_i   ( gpio_input_i   ),
  .gpio_output_o  ( gpio_output_o  ),
  .cpu_rst_o      ( cpu_rst_o      ),
  .cpu_boot_addr_o( cpu_boot_addr_o),
  .axi_lite_s     ( out_lite_bus[0])
);

`ifdef NOT_MOCK
apb_uart i_apb_uart (
  .CLK      ( clk_i   ),
  .RSTN     ( rst_ni  ),
  .PSEL     ( psel        ),
  .PENABLE  ( penable     ),
  .PWRITE   ( pwrite      ),
  .PADDR    ( paddr[4:2]  ),
  .PWDATA   ( pwdata      ),
  .PRDATA   ( prdata      ),
  .PREADY   ( pready      ),
  .PSLVERR  ( pslverr     ),
  .INT      ( uart_intr_o ),
  .CTSN     ( 1'b0  ),
  .DSRN     ( 1'b0  ),
  .DCDN     ( 1'b0  ),
  .RIN      ( 1'b0  ),
  .RTSN     ( ),
  .OUT1N    ( ),
  .OUT2N    ( ),
  .DTRN     ( ),
  .SIN      ( uart_rx_i  ),
  .SOUT     ( uart_tx_o  )
);
`else
mock_uart i_apb_uart (
  .clk_i      ( clk_i     ),
  .rst_ni     ( rst_ni    ),
  .penable_i  ( penable   ),
  .pwrite_i   ( pwrite    ),
  .paddr_i    ( paddr     ),
  .psel_i     ( psel      ),
  .pwdata_i   ( pwdata    ),
  .prdata_o   ( prdata    ),
  .pready_o   ( pready    ),
  .pslverr_o  ( pslverr   )
);

assign uart_tx_o = 0;
`endif

rt_timer #() i_timer (
  .clk_i       (clk_i),
  .rst_ni      (rst_ni),
  .timer_irq_o (mtimer_irq_o),
  .axi_lite_s  (out_lite_bus[2])
);

endmodule : rt_peripherals
