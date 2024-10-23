//------------------------------------------------------------------------------
// Module   : rt_top_fpga_wrapper_PYNQZ1.sv
//
// Project  : RT-SS
// Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
// Created  : 04-dec-2023
//
// Description: Top-level wrapper to be used in FPGA Prototype of RT-SS on the
//              PYNQZ1 board.
//
// Parameters:
//  - AXI_ADDR_WIDTH: Bit width of AXI address
//  - AXI_DATA_WIDTH: Bit width of AXI data
//
// Inputs:
//   - clk_i: Clock in
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
//  - Version 1.1: Updated module to be board-specific [16-feb-2024 TS]
//
//------------------------------------------------------------------------------

module rt_top_fpga_wrapper_PYNQZ1 #(
  parameter int unsigned AXI_ADDR_WIDTH = 32,
  parameter int unsigned AXI_DATA_WIDTH = 32,
  parameter bit          IbexRve        = 1
)(
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [3:0]  gpio_input_i,
  input  logic        jtag_tck_i,
  input  logic        jtag_tms_i,
  input  logic        jtag_trst_ni,
  input  logic        jtag_td_i,
  input  logic        uart_rx_i,

  output logic        uart_tx_o,
  output logic [3:0]  gpio_output_o,
  output logic        jtag_td_o
);

  logic locked, top_clk;
  wire  rt_ss_rstn;

  // use locked to provide active-low synchronous reset
  assign rt_ss_rstn = locked;

  AXI_BUS #(
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ID_WIDTH   (9),
    .AXI_USER_WIDTH (4)
  ) mst_bus(), slv_bus ();

  // top clock instance
  top_clock i_top_clock (
    .reset    ( rst_i    ), // input reset
    .locked   ( locked   ), // output locked
    .clk_in1  ( clk_i    ), // input clk_in1
    .clk_out1 ( top_clk  )  // output clk_out1
  );

  // RT-SS instance
  rt_top #(
    .AxiAddrWidth ( AXI_ADDR_WIDTH ),
    .AxiDataWidth ( AXI_DATA_WIDTH ),
    .IbexRve      ( IbexRve        )
  ) i_rt_top (
    .clk_i          ( top_clk       ),
    .rst_ni         ( rt_ss_rstn    ),
    .jtag_tck_i     ( jtag_tck_i    ),
    .jtag_tms_i     ( jtag_tms_i    ),
    .jtag_trst_ni   ( jtag_trst_ni  ),
    .jtag_td_i      ( jtag_td_i     ),
    .jtag_td_o      ( jtag_td_o     ),
    .soc_mst        ( mst_bus       ),
    .soc_slv        ( slv_bus       ),
    .uart_rx_i      ( uart_rx_i     ),
    .uart_tx_o      ( uart_tx_o     ),
    .gpio_input_i   ( gpio_input_i  ),
    .gpio_output_o  ( gpio_output_o )
  );

  // Tieoff interfaces
  assign mst_bus.aw_id     = '0;
  assign mst_bus.aw_len    = '0;
  assign mst_bus.aw_size   = '0;
  assign mst_bus.aw_burst  = '0;
  assign mst_bus.aw_lock   = '0;
  assign mst_bus.aw_cache  = '0;
  assign mst_bus.aw_prot   = '0;
  assign mst_bus.aw_qos    = '0;
  assign mst_bus.aw_region = '0;
  assign mst_bus.aw_atop   = '0;
  assign mst_bus.aw_user   = '0;
  assign mst_bus.aw_valid  = '0;

  assign mst_bus.w_data  = '0;
  assign mst_bus.w_strb  = '0;
  assign mst_bus.w_last  = '0;
  assign mst_bus.w_user  = '0;
  assign mst_bus.w_valid = '0;

  assign mst_bus.b_ready = '0;

  assign mst_bus.ar_id     = '0;
  assign mst_bus.ar_len    = '0;
  assign mst_bus.ar_size   = '0;
  assign mst_bus.ar_burst  = '0;
  assign mst_bus.ar_lock   = '0;
  assign mst_bus.ar_cache  = '0;
  assign mst_bus.ar_prot   = '0;
  assign mst_bus.ar_qos    = '0;
  assign mst_bus.ar_region = '0;
  assign mst_bus.ar_user   = '0;
  assign mst_bus.ar_valid  = '0;

  assign mst_bus.r_ready   = '0;

  assign slv_bus.aw_ready  = '0;
  assign slv_bus.w_ready   = '0;

  assign slv_bus.b_id      = '0;
  assign slv_bus.b_resp    = '0;
  assign slv_bus.b_user    = '0;
  assign slv_bus.b_valid   = '0;

  assign slv_bus.ar_ready  = '0;

  assign slv_bus.r_id      = '0;
  assign slv_bus.r_data    = '0;
  assign slv_bus.r_resp    = '0;
  assign slv_bus.r_last    = '0;
  assign slv_bus.r_user    = '0;
  assign slv_bus.r_valid   = '0;


endmodule
