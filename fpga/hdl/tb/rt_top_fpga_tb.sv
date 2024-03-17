//------------------------------------------------------------------------------
// Module   : rt_top_fpga_tb.sv
//
// Project  : RT-SS
// Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
// Created  : 04-dec-2023
//
// Description: Testbench for FPGA Prototype of RT-SS
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
//  - Version 1.1: Updated to include VCU118 [16-feb-2024 TS]
//
//------------------------------------------------------------------------------

module rt_top_fpga_tb;

  timeunit 1ns/1ps;

  localparam time ClockPeriodNs = 8ns;
  localparam time TestRunPeriodus = 10us;

  localparam integer AXIAddrWidth = 32;
  localparam integer AXIDataWidth = 32;
  localparam integer GPIOWidth    = 4;

  // DUT signals
  logic dut_clk_i;
  logic dut_rst_i;
  logic dut_jtag_tck_i;
  logic dut_jtag_tms_i;
  logic dut_jtag_trst_ni;
  logic dut_jtag_td_i;
  logic dut_jtag_td_o;

  logic [GPIOWidth-1:0] dut_gpio_output_o;
  logic [GPIOWidth-1:0] dut_gpio_input_i;

  // generate clock
  initial dut_clk_i = 1'b0;
  always #(ClockPeriodNs/2) dut_clk_i = ~dut_clk_i;

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

  // main loop
  initial begin
    // start in reset
    dut_rst_i        = 1'b1;
    dut_jtag_tck_i   = 1'b0;
    dut_jtag_tms_i   = 1'b0;
    dut_jtag_trst_ni = 1'b0;
    dut_jtag_td_i    = 1'b0;
    dut_gpio_input_i = '0;

    while ($time < 100ns) begin
      @(posedge dut_clk_i);
    end

    // release reset
    @(negedge dut_clk_i);
    dut_rst_i = 1'b0;
    dut_jtag_trst_ni = 1'b0;

    // finish test
    #(TestRunPeriodus);
    $display("Test Complete!");
    $finish;
  end

endmodule
