`timescale 1ns/1ps

module tb_rt_ss
  //import axi_test::*;
  // TODO: use this pkg on need basis
();

parameter bit JtagTest     = 0;
parameter bit SoftwareTest = 0;
parameter bit IbexRve      = 1;

`ifdef VERILATOR
parameter string TestName = "VerilatorTest";
parameter string Load     = "READMEM";
parameter string ImemStim = "../memory_init/test_imem_init.mem";
parameter string DmemStim = "../memory_init/test_dmem_init.mem";
`else
parameter string TestName = "";
parameter string Load     = "";
// default stim, to be overwriten based on testcase
parameter string ImemStim = "../stims/nop_loop.hex";
parameter string DmemStim = "../stims/nop_loop.hex";
`endif

localparam string RfInit = "../stims/rf_init.hex";
localparam string MemInit = "../stims/mem_init.hex";
localparam time TimeOut    = 3.5ms;

localparam int unsigned AxiAw    = 32;
localparam int unsigned AxiDW    = 32;
localparam int unsigned ProgLen  = 32'h4000;
localparam int unsigned IrqWidth = 64;

localparam logic [31:0] RtImemAddr = 32'h0000_1000;
localparam logic [31:0] RtDmemAddr = 32'h0000_5000;
localparam logic [31:0] RtBootAddr = RtImemAddr + 'h80;

bit any_test     = 0;
bit clk_en       = 0;

logic [31:0] imem_data [ ProgLen ];
logic [31:0] dmem_data [ ProgLen ];

// DUT SIGNALS
logic clk;
logic rst_n;
logic jtag_tck;
logic jtag_tms;
logic jtag_trstn;
logic jtag_tdi;
logic jtag_tdo;
logic [3:0] gpio_input;
logic [3:0] gpio_output;
logic uart_rx;
logic uart_tx;
logic [IrqWidth-1:0] intr_src;

`ifndef STANDALONE
//
//  AXI_LITE_DV #(
//    .AXI_ADDR_WIDTH ( AxiAw ),
//    .AXI_DATA_WIDTH ( AxiDW )
//  ) axi_mst_dv ( clk );
//  AXI_LITE_DV #(
//    .AXI_ADDR_WIDTH ( AxiAw ),
//    .AXI_DATA_WIDTH ( AxiDW )
//  ) axi_slv_dv ( clk );
//
`ifdef SYNTH_WRAPPER
AXI_BUS #(
  .AXI_ID_WIDTH   ( 9 ),
  .AXI_USER_WIDTH ( 4 ),
`else
AXI_LITE #(
`endif
  .AXI_ADDR_WIDTH ( AxiAw ),
  .AXI_DATA_WIDTH ( AxiDW )
) soc_mst (), soc_slv ();

//
//  `AXI_LITE_ASSIGN( soc_slv, axi_slv_dv )
//  `AXI_LITE_ASSIGN( axi_mst_dv, soc_mst )
//
//  axi_test::axi_lite_driver #(.AW( AxiAw ), .DW( AxiDW )) axi_mst_drv = new(axi_mst_dv);
//  axi_test::axi_lite_driver #(.AW( AxiAw ), .DW( AxiDW )) axi_slv_drv = new(axi_slv_dv);
//
`endif

rt_jtag_pkg::debug_mode_if_t #(.PROG_LEN(ProgLen)) rt_debug_mode_if = new;

initial begin : tb_process

`ifdef SYNTH_WRAPPER
  `ifdef STANDALONE
    $fatal("ERROR: cannot use synth wrapper in STANDALONE mode");
  `endif
`endif

  automatic integer fd;
  automatic integer errno;
  automatic string error_str;

`ifdef VERILATOR
  $dumpfile("waveform.fst");
  $dumpvars;
`else
  dm::dmstatus_t dmstatus;
`endif


if (Load == "READMEM") begin
  #0; // mitigate SRAM initial begin
  $display("[RT_TB] Preloading IMEM & DMEM with $readmemh");
  $display("[RT_TB] THIS IS NOT APPLICABLE TO SYNTHESIZED DESIGNS, NEVER RELY ONLY ON THIS MODE!");
`ifndef FPGA_MEM
  `ifndef SYNTH_WRAPPER
    $readmemh(ImemStim, i_dut.i_core_subsystem.i_imem.i_mem.ram);
    $readmemh(DmemStim, i_dut.i_core_subsystem.i_dmem.i_mem.ram);
  `else
    $readmemh(ImemStim, i_dut.i_synth_wrapper.rt_top_unwrap.i_rt_top.i_core_subsystem.i_imem.i_mem.ram);
    $readmemh(DmemStim, i_dut.i_synth_wrapper.rt_top_unwrap.i_rt_top.i_core_subsystem.i_dmem.i_mem.ram);
  `endif
`endif
end else if (Load == "JTAG") begin
  $readmemh(ImemStim, imem_data);
  $readmemh(DmemStim, dmem_data);
end else begin
  $display("[RT_TB] Error: unsupported LOAD parameter given, simulation terminating");
  $fatal;
end

  // Check user-supplied stimulus path exists
  fd = $fopen(ImemStim, "r");
  if (fd == 0) begin
`ifdef VERILATOR
    $error("can't open stimulus file, terminating");
    $fatal;
`else
    errno = $ferror(fd, error_str);
    $error(error_str);
    $fatal;
`endif
  end

  $display("[RT_TB] TestName: %s", TestName);
  $display("[RT_TB] ImemStim %s", ImemStim);
  $display("[RT_TB] Load mode: %s", Load);
  if (TestName == "nop_loop") begin
    $display("[RT_TB] No test specified, simulation terminating");
    $finish;
  end

  clk        =  0;
  rst_n      =  0;
  jtag_tck   =  0;
  jtag_tms   =  0;
  jtag_trstn =  0;
  jtag_tdi   =  0;
  intr_src   = '0;
  gpio_input = '0;

  #123;
  rst_n  =  1;
  #456;

`ifndef VERILATOR // JTAG functionality currently not supported in Verilator

  if (JtagTest) begin
    any_test = 1;
    rt_jtag_pkg::run_jtag_conn_test(jtag_tck, jtag_trstn, jtag_tms, jtag_tdi, jtag_tdo);
  end

  if (/*JtagTest | (SoftwareTest  & Load == "JTAG") */ 1 ) begin
    //initialise JTAG TAP for DMI Access
    rt_debug_mode_if.init_dmi_access(jtag_tck, jtag_tms, jtag_trstn, jtag_tdi);
    // set DM to active
    rt_debug_mode_if.set_dmactive(1'b1, jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo);
    // select the hart to be halted
    rt_debug_mode_if.set_hartsel(9'b0, jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo);
    // attempting to halt the HART
    rt_debug_mode_if.halt_harts(jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo);
    // check that hart is halted
    rt_debug_mode_if.read_debug_reg(dm::DMStatus, dmstatus,
                            jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo);
    if (dmstatus.allhalted != 1'b1) begin
      $error("[RT_JTAG_TB] %0tns - [FAILED] to halt core.", $time);
    end else begin
      $display("[RT_JTAG_TB] %0tns - Core sucessfully halted.", $time);
    end
  end

  // Set boot address regardless of Load setting
  rt_debug_mode_if.write_reg_abstract_cmd( riscv::CSR_DPC, RtBootAddr,
    jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo );

  if ( SoftwareTest  & (Load == "JTAG")) begin
    // set boot address and start loading code into DLA IMEM
    $display("[RT_JTAG_TB] %0tns - Loading L2", $realtime);
    rt_debug_mode_if.load_L2(RtImemAddr, imem_data,
                            jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo );
    rt_debug_mode_if.load_L2(RtDmemAddr, dmem_data,
                            jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo );
  end

  // initialise JTAG TAP for DMI Access
  rt_debug_mode_if.init_dmi_access(jtag_tck, jtag_tms, jtag_trstn, jtag_tdi);
  // we have set dpc and loaded the binary, we can go now
  $display("[RT_JTAG_TB] Time %0tns - Resuming the CORE", $time);
  rt_debug_mode_if.resume_harts(jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo);

`endif

  if (SoftwareTest) begin
    $display("[RT_TB] Starting software test");
    #TimeOut;
  end

  $display("[RT_TB] Simulation complete");
  $finish();

end : tb_process

always begin
  if(~clk_en)
    #5 clk = ~clk;
end

`ifdef SYNTH_WRAPPER
  rt_top_tb_wrapper #(
`else
  rt_top #(
`endif
  .AxiAddrWidth (AxiAw),
  .AxiDataWidth (AxiDW),
  .ClicIrqSrcs  (IrqWidth),
  .IbexRve      (IbexRve)
) i_dut (
  .clk_i        (clk),
  .rst_ni       (rst_n),
  // TODO: implement AXI driver in tb
`ifndef STANDALONE
  .soc_slv (soc_slv),
  .soc_mst (soc_mst),
`endif
  .jtag_tck_i    (jtag_tck),
  .jtag_tms_i    (jtag_tms),
  .jtag_trst_ni  (jtag_trstn),
  .jtag_td_i     (jtag_tdi),
  .jtag_td_o     (jtag_tdo),
  .gpio_input_i  (gpio_input),
  .gpio_output_o (gpio_output),
  .uart_rx_i     (uart_rx),
  .uart_tx_o     (uart_tx),
  .intr_src_i    ('0)
);

uart_bus #(
  .BAUD_RATE( 3000000 ),
  .PARITY_EN(    0 )
) i_uart (
  // Note invertion of signals from dut->uart
  .rx    ( uart_tx ),
  .tx    ( uart_rx ),
  .rx_en ( 1'b1    )
);


// Tie-off
`ifndef STANDALONE
  assign soc_slv.aw_addr  = '0;
  assign soc_slv.aw_prot  = '0;
  assign soc_slv.aw_valid = '0;
  assign soc_slv.w_data   = '0;
  assign soc_slv.w_strb   = '0;
  assign soc_slv.b_ready  = '0;
  assign soc_slv.w_valid  = '0;
  assign soc_slv.ar_addr  = '0;
  assign soc_slv.ar_prot  = '0;
  assign soc_slv.ar_valid = '0;
  assign soc_slv.r_ready  = '0;
`ifdef SYNTH_WRAPPER
  assign soc_slv.aw_id    = '0;
  assign soc_slv.aw_len   = '0;
  assign soc_slv.aw_size  = '0;
  assign soc_slv.aw_burst = '0;
  assign soc_slv.aw_lock  = '0;
  assign soc_slv.aw_cache = '0;
  assign soc_slv.aw_qos   = '0;
  assign soc_slv.aw_region= '0;
  assign soc_slv.aw_atop  = '0;
  assign soc_slv.aw_user  = '0;
  assign soc_slv.w_last   = '0;
  assign soc_slv.w_user   = '0;
  assign soc_slv.b_id     = '0;
  assign soc_slv.ar_id    = '0;
  assign soc_slv.ar_len   = '0;
  assign soc_slv.ar_size  = '0;
  assign soc_slv.ar_burst = '0;
  assign soc_slv.ar_lock  = '0;
  assign soc_slv.ar_cache = '0;
  assign soc_slv.ar_qos   = '0;
  assign soc_slv.ar_region= '0;
  assign soc_slv.ar_user  = '0;
  assign soc_slv.r_id     = '0;

  assign soc_mst.aw_id    = '0;
  assign soc_mst.b_id     = '0;
  assign soc_mst.b_user   = '0;
  assign soc_mst.ar_id    = '0;
  assign soc_mst.r_id     = '0;
  assign soc_mst.r_last   = '0;
  assign soc_mst.r_user   = '0;
`endif
  assign soc_mst.aw_ready  = '0;
  assign soc_mst.w_ready   = '0;
  assign soc_mst.b_resp    = '0;
  assign soc_mst.b_valid   = '0;
  assign soc_mst.ar_ready  = '0;
  assign soc_mst.r_data    = '0;
  assign soc_mst.r_valid   = '0;
  assign soc_mst.r_resp    = '0;
`endif

endmodule
