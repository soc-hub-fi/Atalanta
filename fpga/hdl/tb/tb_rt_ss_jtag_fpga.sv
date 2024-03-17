//------------------------------------------------------------------------------
// Module   : tb_rt_ss.sv
//
// Project  : RT-SS
// Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
// Created  : 16-feb-2024
//
// Description: Testbench for FPGA Prototype of RT-SS, including JTAG tests
//
// Parameters:
//  None
//
// Inputs:
//   None
//
// Outputs:
//  None
//
// Revision History:
//  - Version 1.0: Initial release
//
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_rt_ss;

parameter bit JTAG_SANITY = 1;
parameter bit JTAG_HALT   = 1;
parameter bit BLINK_TEST  = 0;
parameter bit JTAG_LOAD   = 0;
// default stim, to be overwriten based on testcase
parameter string STIM_PATH = "../../../../../../../stims/nop_loop.hex";
localparam EXTRA_RUNTIME = 10us;
localparam TIMEOUT       = 1ms;

localparam bit LOAD_MEM = JTAG_LOAD | BLINK_TEST;

localparam AXI_AW   = 32;
localparam AXI_DW   = 32;
localparam PROG_LEN = 150;

localparam logic [31:0] RT_BASE_ADDR = 32'h0000_1000;
localparam logic [31:0] RT_BOOT_ADDR = RT_BASE_ADDR  + 'h80;

bit any_test = 0;
bit done     = 0;
bit dbg_flag = 0;

logic [31:0] test_program [ PROG_LEN-1:0];

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

// Debug package instantiation
//rt_jtag_pkg::test_mode_if_t  rt_test_mode_if  = new;
rt_jtag_pkg::debug_mode_if_t #(.PROG_LEN(PROG_LEN)) rt_debug_mode_if = new;


initial begin : tb_process

  dm::dmstatus_t dmstatus;

  $readmemh(STIM_PATH, test_program);

  clk   = 0;
  rst_n = 0;

  jtag_tck = 0;
  jtag_tms = 0;
  jtag_trstn = 0;
  jtag_tdi = 0;

  #123; 
  rst_n  =  1;

  @(posedge i_dut.i_top_clock.locked);
  
  #10us;

  if (JTAG_SANITY) begin
    any_test = 1;
    rt_jtag_pkg::run_jtag_conn_test(jtag_tck, jtag_trstn, jtag_tms, jtag_tdi, jtag_tdo);
  end

  if (JTAG_HALT | LOAD_MEM ) begin
    any_test = 1;
    //initialise JTAG TAP for DMI Access
    $display("[RT_JTAG_TB] %0tps - initialise JTAG TAP for DMI Access.", $time);
    rt_debug_mode_if.init_dmi_access(jtag_tck, jtag_tms, jtag_trstn, jtag_tdi);

    // set DM to active
    $display("[RT_JTAG_TB] %0tps - set DM to active.", $time);
    rt_debug_mode_if.set_dmactive(1'b1, jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo);

    // select the hart to be halted
    $display("[RT_JTAG_TB] %0tps - select the hart to be halted.", $time);
    rt_debug_mode_if.set_hartsel(9'b0, jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo);

    // attempting to halt the HART
    $display("[RT_JTAG_TB] %0tps - attempting to halt the HART.", $time);
    rt_debug_mode_if.halt_harts(jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo);

    // check that hart is halted
    $display("[RT_JTAG_TB] %0tps - check that hart is halted.", $time);
    rt_debug_mode_if.read_debug_reg(dm::DMStatus, dmstatus, jtag_tck, jtag_tms, jtag_trstn,
      jtag_tdi, jtag_tdo);

    if (dmstatus.allhalted != 1'b1) begin
      $error("[RT_JTAG_TB] %0tps - [FAILED] to halt core.", $time);
    end else begin
      $display("[RT_JTAG_TB] %0tps - Core sucessfully halted.", $time);
    end

  end

  if (LOAD_MEM ) begin

    // set boot address and start loading code into DLA IMEM
    $display("[RT_JTAG_TB] %0tps - Loading L2", $realtime); 
    rt_debug_mode_if.write_reg_abstract_cmd( riscv::CSR_DPC, RT_BOOT_ADDR, jtag_tck, jtag_tms,
      jtag_trstn, jtag_tdi, jtag_tdo);
    rt_debug_mode_if.load_L2(RT_BASE_ADDR, test_program, jtag_tck, jtag_tms, jtag_trstn, jtag_tdi,
      jtag_tdo);

    // initialise JTAG TAP for DMI Access
    rt_debug_mode_if.init_dmi_access(jtag_tck, jtag_tms, jtag_trstn, jtag_tdi);
    $display("[RT_JTAG_TB] Time %0tps - Set CPU_INIT register", $time);
    rt_debug_mode_if.writeMem(32'h0003_0000, 32'h0001_0001, jtag_tck, jtag_tms, jtag_trstn,
      jtag_tdi, jtag_tdo);

    // we have set dpc and loaded the binary, we can go now 
    $display("[RT_JTAG_TB] Time %0tps - Resuming the CORE", $time);
    rt_debug_mode_if.resume_harts(jtag_tck, jtag_tms, jtag_trstn, jtag_tdi, jtag_tdo);

  end

  if (BLINK_TEST) begin
    fork
      begin
        wait (gpio_output[0] == 1'b1);
        #1;
        $display("Blink [PASSED]!");
      end

      begin
        #TIMEOUT;
        $display("TIMEOUT reached, test [FAILED]!");
      end
    join_any

  end

  #EXTRA_RUNTIME;
  done = 1;
  if (any_test) begin
    $display("All tests execution [PASSED]! Check log for any failures.");
  end else begin
    $display("No tests run!");
  end
  $finish();

end : tb_process

always begin
  if(~done)
    #4ns clk = ~clk;
end

`ifdef VCU118

  // DUT instance - VCU118
  rt_top_fpga_wrapper_VCU118 #(
    .AXI_ADDR_WIDTH ( AXI_AW ),
    .AXI_DATA_WIDTH ( AXI_DW )
  ) i_dut (
    .clk_p_i       ( clk         ),
    .clk_n_i       ( ~clk        ),
    .rst_i         ( ~rst_n      ), /* Active high CPU reset on board */
    .jtag_tck_i    ( jtag_tck    ),
    .jtag_tms_i    ( jtag_tms    ),
    .jtag_trst_ni  ( ~jtag_trstn ), /* Active high JTAG reset on board */
    .jtag_td_i     ( jtag_tdi    ),
    .gpio_input_i  ( gpio_input  ),
    .gpio_output_o ( gpio_output ),
    .jtag_td_o     ( jtag_tdo    )
  );

`else

  // DUT instance - PYNQZ1
  rt_top_fpga_wrapper_PYNQZ1 #(
    .AXI_ADDR_WIDTH ( AXI_AW ),
    .AXI_DATA_WIDTH ( AXI_DW )
  ) i_dut (
    .clk_i         ( clk         ),
    .rst_i         ( ~rst_n      ), /* Active high reset switch on board */
    .jtag_tck_i    ( jtag_tck    ),
    .jtag_tms_i    ( jtag_tms    ),
    .jtag_trst_ni  ( jtag_trstn  ),
    .jtag_td_i     ( jtag_tdi    ),
    .gpio_input_i  ( gpio_input  ),
    .gpio_output_o ( gpio_output ),
    .jtag_td_o     ( jtag_tdo    )
  );

`endif



endmodule
