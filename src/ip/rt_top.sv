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

localparam int unsigned MaxTrans  = 3;
localparam int unsigned NumMemBanks = rt_pkg::NumMemBanks;

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
OBI_BUS #() memb_bus [NumMemBanks] ();
OBI_BUS #() mgr_bus [rt_pkg::MainXbarCfg.NumM] (), sbr_bus [rt_pkg::MainXbarCfg.NumS] ();

assign ibex_rst_n = rst_ni & ~(ndmreset);


// Compile-time mapping of SRAM to size, # ports
rt_pkg::xbar_rule_t [NumMemBanks] SramRules;
for (genvar i=0; i<NumMemBanks; i++) begin : g_sram_rules
  assign SramRules[i] = '{
    idx: 32'd4+i,
    start_addr : (rt_pkg::SramRule.Start) + rt_pkg::SramSize*(i*1/NumMemBanks),
    end_addr   : (rt_pkg::SramRule.Start) + rt_pkg::SramSize*((i+1)*1/NumMemBanks)
  };
end

rt_pkg::xbar_rule_t [rt_pkg::MainXbarCfg.NumS-NumMemBanks+1] OtherRules = '{
  '{idx: 0, start_addr: rt_pkg::ImemRule.Start, end_addr: rt_pkg::DmemRule.End},
  '{idx: 1, start_addr: rt_pkg::DbgRule.Start,  end_addr: rt_pkg::DbgRule.End},
  '{idx: 1, start_addr: rt_pkg::RomRule.Start,  end_addr: rt_pkg::RomRule.End},
  '{idx: 2, start_addr: rt_pkg::ApbRule.Start,  end_addr: rt_pkg::ApbRule.End},
  '{idx: 3, start_addr: rt_pkg::AxiRule.Start,  end_addr: rt_pkg::AxiRule.End}
};


rt_pkg::xbar_rule_t [rt_pkg::MainXbarCfg.NumS] MainAddrMap = {SramRules, OtherRules};

rt_core #(
  .NumInterrupts (ClicIrqSrcs),
  .RVE           (IbexRve),
  .XbarCfg       (rt_pkg::CoreXbarCfg),
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
  .main_xbar_mgr   (mgr_bus[0]),
  .main_xbar_sbr   (sbr_bus[0])
);

obi_xbar_intf #(
  .NumSbrPorts     (rt_pkg::MainXbarCfg.NumM),
  .NumMgrPorts     (rt_pkg::MainXbarCfg.NumS),
  .NumMaxTrans     (rt_pkg::MainXbarCfg.MaxTrans),
  .NumAddrRules    (rt_pkg::MainXbarCfg.NumS),
  .addr_map_rule_t (rt_pkg::xbar_rule_t),
  .UseIdForRouting (0)
) i_main_xbar (
  .clk_i,
  .rst_ni,
  .testmode_i       (1'b0),
  .sbr_ports        (mgr_bus),
  .mgr_ports        (sbr_bus),
  .addr_map_i       (MainAddrMap),
  .en_default_idx_i ('0),
  .default_idx_i    ('0)
);

//assign memb_bus[0].gnt    = 0;
//assign memb_bus[0].rvalid = 0;
//assign memb_bus[1].gnt    = 0;
//assign memb_bus[1].rvalid = 0;

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
  .irq_id_o       (irq_id),
  .irq_src_i      (intr_src_i),
  .gpio_i         (gpio_input_i),
  .gpio_o         (gpio_output_o)
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

rt_memory_banks #(
  .NrMemBanks    (rt_pkg::NumMemBanks)
) i_memory_banks (
  .clk_i,
  .rst_ni,
  .obi_sbr (memb_bus)
);

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
