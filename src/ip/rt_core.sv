//`include "obi/typedef.svh"
//`include "obi/assign.svh"

module rt_core #(
  parameter int unsigned AddrWidth      = 32,
  parameter int unsigned DataWidth      = 32,
  parameter int unsigned NumInterrupts  = 64,
  parameter bit          RVE            =  1,
  parameter rt_pkg::xbar_cfg_t XbarCfg  = rt_pkg::ObiXbarCfg,
  parameter int unsigned NrMemBanks     = 2,
  localparam int unsigned SrcW          = $clog2(NumInterrupts)

  )(
  input  logic            clk_i,
  input  logic            rst_ni,
  input  logic            irq_valid_i,
  output logic            irq_ready_o,
  input  logic [SrcW-1:0] irq_id_i,
  input  logic [     7:0] irq_level_i,
  input  logic            irq_shv_i,
  input  logic [     1:0] irq_priv_i,
  input  logic            debug_req_i,
  // crossbar m-ports
  APB.Master              apbm_peripheral,
  OBI_BUS.Manager         obim_memory [NrMemBanks],
  OBI_BUS.Manager         obim_debug,
  OBI_BUS.Manager         obim_axi,
  // crossbar s-ports
  OBI_BUS.Subordinate     obis_axi,
  OBI_BUS.Subordinate     obis_debug
);
/*
localparam int unsigned SramStart = XbarCfg.SramStart;
localparam int unsigned SramEnd   = XbarCfg.SramEnd;
localparam int unsigned SramSize  = rt_pkg::get_addr_size(SramEnd, SramStart);

rt_pkg::rule_t [NrMemBanks] SramRules;

for (genvar i=0; i<NrMemBanks; i++) begin : g_sram_rules
  assign SramRules[i] = '{
    idx: 32'd5+i,
    start_addr : (XbarCfg.SramStart) + SramSize*(i*1/NrMemBanks),
    end_addr   : (XbarCfg.SramStart) + SramSize*((i+1)*1/NrMemBanks)
  };
end

rt_pkg::rule_t [XbarCfg.NumS-1:0] AddrMap = '{
  SramRules,
  rt_pkg::AxiRule,
  rt_pkg::ApbRule,
  rt_pkg::DmemRule,
  rt_pkg::ImemRule,
  rt_pkg::DbgRule,
  rt_pkg::RomRule
};
*/

OBI_BUS #() mgr_bus [rt_pkg::ObiXbarCfg.NumM] (), sbr_bus [rt_pkg::ObiXbarCfg.NumS] ();

obi_xbar_intf #(
  .NumSbrPorts     (XbarCfg.NumM),
  .NumMgrPorts     (XbarCfg.NumS),
  .NumMaxTrans     (XbarCfg.MaxTrans),
  .NumAddrRules    (XbarCfg.NumS),
  .addr_map_rule_t (rt_pkg::rule_t),
  .UseIdForRouting (0)
) i_obi_xbar (
  .clk_i            (clk_i),
  .rst_ni           (rst_ni),
  .testmode_i       (1'b0),
  .sbr_ports        (mgr_bus),
  .mgr_ports        (sbr_bus),
  .addr_map_i       (AddrMap),
  .en_default_idx_i ('0),
  .default_idx_i    ('0)
);

obi_sram_intf #() i_imem ();
obi_sram_intf #() i_dmem ();

endmodule : rt_core
