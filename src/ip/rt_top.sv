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

// TODO: move to pkg
localparam int unsigned NumMemBanks = 2;
localparam int unsigned NumM        = 3;
localparam int unsigned NumS        = 6 + NumMemBanks;
localparam int unsigned MemSize     = 32'h4000;
localparam int unsigned ImemOffset  = 32'h1000;
localparam int unsigned DmemOffset  = 32'h5000;

APB #() peripheral_bus ();
OBI_BUS #() axim_bus ();
OBI_BUS #() axis_bus ();
OBI_BUS #() dbgm_bus ();
OBI_BUS #() dbgs_bus ();
OBI_BUS #() memb_bus [NumMemBanks] ();

rt_core #(
  .NumInterrupts (ClicIrqSrcs),
  .RVE           (IbexRve),
  .XbarCfg       (rt_pkg::ObiXbarCfg)
) i_core (
  .clk_i,
  .rst_ni,
  .irq_valid_i     (),
  .irq_ready_o     (),
  .irq_id_i        (),
  .irq_level_i     (),
  .irq_shv_i       (),
  .irq_priv_i      (),
  .debug_req_i     (),
  .apbm_peripheral (peripheral_bus),
  .obim_memory     (memb_bus),
  .obim_debug      (dbgs_bus),
  .obim_axi        (axim_bus),
  .obis_axi        (axis_bus),
  .obis_debug      (dbgm_bus)
);

rt_peripherals #() i_peripherals ();

rt_debug #(
  .DmBaseAddr ('h0000)
) i_riscv_dbg (
  .clk_i,
  .rst_ni,
  .jtag_tck_i,
  .jtag_tms_i,
  .jtag_trst_ni,
  .jtag_td_i,
  .jtag_td_o,
  .ndmreset_o      (),
  .debug_req_irq_o (),
  .dbg_mst         (dbgm_bus),
  .dbg_slv         (dbgs_bus)
);

rt_memory_banks #() i_memory_banks ();

axi_to_obi_intf #() i_axi_to_obi ();

obi_to_axi_intf #() i_obi_to_axi ();


endmodule : rt_top
