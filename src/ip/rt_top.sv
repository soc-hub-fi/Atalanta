/*
  RT-SS top level module
  authors: Antti Nurmi <antti.nurmi@tuni.fi>
*/

`include "axi/assign.svh"
`define COMMON_CELLS_ASSERTS_OFF

module rt_top #(
  parameter int unsigned AxiAddrWidth = 32,
  parameter int unsigned AxiDataWidth = 32,
  parameter int unsigned AxiIdWidth   = 9,
  parameter int unsigned AxiUserWidth = 4,
  parameter int unsigned ClicIrqSrcs  = 64,
  parameter bit          IbexRve      = 1,
  // Derived parameters
  localparam int SrcW                 = $clog2(ClicIrqSrcs),
  localparam int unsigned StrbWidth   = (AxiDataWidth / 8)

)(
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic [3:0]             gpio_input_i,
  output logic [3:0]             gpio_output_o,
  input  logic                   uart_rx_i,
  output logic                   uart_tx_o,
  AXI_BUS.Slave                  soc_slv,
  AXI_BUS.Master                 soc_mst,
  input  logic                   jtag_tck_i,
  input  logic                   jtag_tms_i,
  input  logic                   jtag_trst_ni,
  input  logic                   jtag_td_i,
  output logic                   jtag_td_o,
  input  logic [ClicIrqSrcs-1:0] intr_src_i
);

localparam int unsigned MaxTrans = 3;
logic ibex_rst_n, ndmreset, debug_req;

logic            irq_valid;
logic            irq_ready;
logic [SrcW-1:0] irq_id;
logic [     7:0] irq_level;
logic            irq_shv;
logic [     1:0] irq_priv;

APB #() peripheral_bus ();
OBI_BUS #() axim_bus ();
OBI_BUS #() axis_bus ();
OBI_BUS #() dbgm_bus ();
OBI_BUS #() dbgs_bus ();
OBI_BUS #() rom_bus ();
OBI_BUS #() memb_bus [rt_pkg::NumMemBanks] ();

assign ibex_rst_n = rst_ni & ~(ndmreset);

rt_core #(
  .NumInterrupts (ClicIrqSrcs),
  .RVE           (IbexRve),
  .XbarCfg       (rt_pkg::ObiXbarCfg),
  .NrMemBanks    (rt_pkg::NumMemBanks)
) i_core (
  .clk_i,
  .rst_ni,
  .ibex_rst_ni     (ibex_rst_n),
  .irq_valid_i     (irq_valid),
  .irq_ready_o     (irq_ready),
  .irq_id_i        (irq_id),
  .irq_level_i     (irq_level),
  .irq_shv_i       (irq_shv),
  .irq_priv_i      (irq_priv),
  .debug_req_i     (debug_req),
  .apbm_peripheral (peripheral_bus),
  .obim_memory     (memb_bus),
  .obim_debug      (dbgs_bus),
  .obim_axi        (axim_bus),
  .obis_axi        (axis_bus),
  .obis_debug      (dbgm_bus),
  .obim_rom        (rom_bus)
);

assign memb_bus[0].gnt    = 0;
assign memb_bus[0].rvalid = 0;
assign memb_bus[1].gnt    = 0;
assign memb_bus[1].rvalid = 0;

assign axim_bus.gnt    = 0;
assign axim_bus.rvalid = 0;

rt_ibex_bootrom #() i_rom (
  .clk_i,
  .rst_ni,
  .sbr_bus (rom_bus)
);

rt_peripherals #() i_peripherals (
  .clk_i,
  .rst_ni,
  .apb_i          (peripheral_bus),
  .uart_rx_i      (uart_rx_i),
  .uart_tx_o      (uart_tx_o),
  .irq_kill_req_o (),
  .irq_kill_ack_i (),
  .irq_priv_o     (irq_priv),
  .irq_shv_o      (irq_shv),
  .irq_level_o    (irq_level),
  .irq_valid_o    (irq_valid),
  .irq_ready_i    (irq_ready),
  .irq_id_o       (irq_id_o),
  .irq_src_i      (intr_src_i),
  .gpio_i         (),
  .gpio_o         ()
);

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
  .ndmreset_o      (ndmreset),
  .debug_req_irq_o (debug_req),
  .dbg_mst         (dbgm_bus),
  .dbg_slv         (dbgs_bus)
);

// rt_memory_banks #() i_memory_banks ();

axi_to_obi_intf #(
  .AxiIdWidth   (AxiIdWidth),
  .AxiUserWidth (AxiUserWidth),
  .MaxTrans     (MaxTrans)
) i_axi_to_obi (
  .clk_i,
  .rst_ni,
  .obi_out (axis_bus),
  .axi_in  (soc_slv)
);

// obi_to_axi_intf #() i_obi_to_axi ();

// TEST TIEOFF
//assign soc_slv.aw_id = '0;
//assign soc_slv.aw_len = '0;
//assign soc_slv.aw_atop = '0;
//assign soc_slv.aw_user = '0;
//assign soc_slv.aw_qos = '0;

endmodule : rt_top
