//------------------------------------------------------------------------------
// Module   : rt_top_fpga_wrapper_VCU118.sv
//
// Project  : RT-SS
// Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
// Created  : 16-feb-2024
//
// Description: Top-level wrapper to be used in FPGA Prototype of RT-SS on the
//              VCU118 board.
//
// Parameters:
//  - AXI_ADDR_WIDTH: Bit width of AXI address
//  - AXI_DATA_WIDTH: Bit width of AXI data
//
// Inputs:
//   - clk_p_i: Clock in (positive)
//   - clk_n_i: Clock in (negative)
//   - rst_i: Active-high reset
//   - gpio_input_i: GPIO inputs
//   - jtag_tck_i: JTAG test clock
//   - jtag_tms_i: JTAG test mode select
//   - jtag_trst_ni: JTAG active-low reset
//   - jtag_td_i: JTAG test data input
//
// Outputs:
//  - gpio_output_o: GPIO outputs
//  - jtag_td_o: JTAG test data out
//
// Revision History:
//  - Version 1.0: Initial release
//
//------------------------------------------------------------------------------

module rt_top_fpga_wrapper_VCU118 #(
  parameter int unsigned AXI_ADDR_WIDTH = 32,
  parameter int unsigned AXI_DATA_WIDTH = 32
)(
  input  logic        clk_p_i,
  input  logic        clk_n_i,
  input  logic        rst_i,
  input  logic [3:0]  gpio_input_i,
  input  logic        jtag_tck_i,
  input  logic        jtag_tms_i,
  input  logic        jtag_trst_i,
  input  logic        jtag_td_i,
  input  logic        uart_rx_i,

  output logic        uart_tx_o,
  output logic [3:0]  gpio_output_o,
  output logic        jtag_td_o
);

  logic locked, top_clk;
  logic jtag_trst_n;
  wire  rt_ss_rstn;

  // use locked to provide active-low synchronous reset
  assign rt_ss_rstn = locked;
  // invert JTAG reset as switches on VCU118 are active-high
  assign jtag_trst_n = ~jtag_trst_i;

  // top clock instance
  top_clock i_top_clock (
    .reset     ( rst_i    ), // input reset
    .locked    ( locked   ), // output locked
    .clk_in1_p ( clk_p_i  ), // input clk_in1_p
    .clk_in1_n ( clk_n_i  ), // input clk_in1_n
    .clk_out1  ( top_clk  )  // output clk_out1
  );

  // RT-SS instance
  rt_top #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH )
  ) i_rt_top (
    .clk_i          ( top_clk       ),
    .rst_ni         ( rt_ss_rstn    ),
    .jtag_tck_i     ( jtag_tck_i    ),
    .jtag_tms_i     ( jtag_tms_i    ),
    .jtag_trst_ni   ( jtag_trst_n   ),
    .jtag_td_i      ( jtag_td_i     ),
    .jtag_td_o      ( jtag_td_o     ),
    .uart_rx_i      ( uart_rx_i     ),
    .uart_tx_o      ( uart_tx_o     ),
    .gpio_input_i   ( gpio_input_i  ),
    .gpio_output_o  ( gpio_output_o )
  );

endmodule
