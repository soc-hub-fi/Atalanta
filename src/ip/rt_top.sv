/*
  RT-SS top level module
  authors: Antti Nurmi <antti.nurmi@tuni.fi>
*/

`include "axi/assign.svh"
`define COMMON_CELLS_ASSERTS_OFF

module rt_top #(
  parameter int unsigned AxiAddrWidth = 32,
  parameter int unsigned AxiDataWidth = 32,
  parameter int unsigned ClicIrqSrcs  = 64,
  parameter bit          IbexRve      = 1,
  // Derived parameters
  localparam int SrcW                 = $clog2(ClicIrqSrcs),
  localparam int unsigned StrbWidth   = (AxiDataWidth / 8)

)(
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic [3:0]         gpio_input_i,
  output logic [3:0]         gpio_output_o,
  input  logic               uart_rx_i,
  output logic               uart_tx_o,
`ifndef STANDALONE
  AXI_LITE.Slave             soc_slv,
  AXI_LITE.Master            soc_mst,
`endif
  input  logic                   jtag_tck_i,
  input  logic                   jtag_tms_i,
  input  logic                   jtag_trst_ni,
  input  logic                   jtag_td_i,
  output logic                   jtag_td_o,
  input  logic [ClicIrqSrcs-1:0] intr_src_i
);

localparam int unsigned NumM = 3;
localparam int unsigned NumS = 6;

OBI_BUS #() mst_bus [NumM] (), slv_bus [NumS] ();

rt_debug #() i_riscv_dbg ();

rt_memory_banks #() i_memory_banks ();

axi_to_obi_intf #() i_axi_to_obi ();

obi_to_axi_intf #() i_obi_to_axi ();

rt_core #() i_core ();

rt_peripherals #() i_peripherals ();

endmodule : rt_top
