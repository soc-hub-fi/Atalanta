module tb_rt_ss
#(
  parameter string TestName     = "",
  parameter string ElfPath      = "",
  parameter string Load         = "",
  parameter bit    IbexRve      = 1
)();

localparam int unsigned IrqNr = 64;
localparam int unsigned AxiAw = 32;
localparam int unsigned AxiDw = 32;
localparam int unsigned AxiIw = 9;
localparam int unsigned AxiUw = 4;

localparam time             RunTime       = 1ms;
localparam time             ClockPerSys   = 10ns;
localparam time             ClockPerJtag  = 30ns;
localparam longint unsigned RstClkCycles  = 347;
localparam longint unsigned TimeoutCycles = 32000;


logic clk, rst_n;
logic jtag_tck, jtag_tms, jtag_trst_n, jtag_tdi,jtag_tdo;
logic [IrqNr-1:0] irqs;


initial begin : tb_process

  $display("[TB]: Starting testbench");

  if (TestName == "") begin
    $display("[TB]: No tests specified, terminating simulation");
    $finish();
  end

  $display("[TB]: Test: %s", TestName);
  $display("[TB]: Load: %s", Load);

  vip.wait_for_reset();
  vip.jtag_init();

  if (TestName == "jtag_access") begin
    vip.run_dbg_mem_test();
  end else begin
    // sw test
    vip.jtag_elf_run(ElfPath);
    vip.jtag_wait_for_eoc();
  end


  $display("[TB]: ending simulation");
  $finish();

end : tb_process

AXI_BUS #(
  .AXI_ID_WIDTH   ( AxiIw ),
  .AXI_USER_WIDTH ( AxiUw ),
  .AXI_ADDR_WIDTH ( AxiAw ),
  .AXI_DATA_WIDTH ( AxiDw )
) dut_mst (), dut_slv ();

assign irqs = '0;
assign uart_rx = '0;
assign uart_tx = '0;

vip_rt_top #(
  .ClkPerSys     (ClockPerSys),
  .ClkPerJtag    (ClockPerJtag),
  .RstClkCycles  (RstClkCycles),
  .TimeoutCycles (TimeoutCycles),
  .AxiAw         (AxiAw),
  .AxiDw         (AxiDw),
  .AxiIw         (AxiIw),
  .AxiUw         (AxiUw)
) vip (
  .clk_o        (clk),
  .rst_no       (rst_n),
  .axi_mst      (dut_slv),
  .axi_slv      (dut_mst),
  .jtag_tck_o   (jtag_tck),
  .jtag_tms_o   (jtag_tms),
  .jtag_trst_no (jtag_trst_n),
  .jtag_tdi_o   (jtag_tdi),
  .jtag_tdo_i   (jtag_tdo)
);

`ifdef SYNTH_WRAPPER
  rt_top_tb_wrapper #(
`else
  rt_top #(
`endif
  .ClicIrqSrcs  (IrqNr),
  .IbexRve      (IbexRve)
) i_dut (
  .clk_i         (clk),
  .rst_ni        (rst_n),
  .soc_slv       (dut_slv),
  .soc_mst       (dut_mst),
  .jtag_tck_i    (jtag_tck),
  .jtag_tms_i    (jtag_tms),
  .jtag_trst_ni  (jtag_trst_n),
  .jtag_td_i     (jtag_tdi),
  .jtag_td_o     (jtag_tdo),
  .gpio_input_i  (gpio_input),
  .gpio_output_o (gpio_output),
  .uart_rx_i     (uart_rx),
  .uart_tx_o     (uart_tx),
  .intr_src_i    (irqs)
);

endmodule
