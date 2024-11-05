`include "obi/typedef.svh"
`include "obi/assign.svh"

module rt_interconnect #(
  parameter bit CutMgrPorts = 1,
  parameter bit CutSbrPorts = 1
)(
  input  logic        clk_i,
  input  logic        rst_ni,
  OBI_BUS.Subordinate dbg_sbr,
  OBI_BUS.Manager     dbg_rom_mgr,
  OBI_BUS.Subordinate core_sbr,
  OBI_BUS.Manager     core_mgr,
  OBI_BUS.Manager     axi_mgr,
  OBI_BUS.Subordinate axi_sbr,
  APB.Master          apb_mgr
);
localparam rt_pkg::xbar_cfg_t XbarCfg = rt_pkg::MainXbarCfg;
localparam int unsigned NumMemBanks = rt_pkg::NumMemBanks;

OBI_BUS #() mgr_bus [XbarCfg.NumM] (), sbr_bus [XbarCfg.NumS] ();
OBI_BUS #() mem_bus [NumMemBanks] ();
OBI_BUS #() apb_bus ();


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

if (CutMgrPorts) begin : g_mgr_cut

  obi_cut_intf i_core_mgr_cut (.clk_i, .rst_ni, .obi_s(sbr_bus[0]), .obi_m(core_mgr));
  obi_cut_intf i_dbg_rom_cut  (.clk_i, .rst_ni, .obi_s(sbr_bus[1]), .obi_m(dbg_rom_mgr));
  obi_cut_intf i_apb_mgr_cut  (.clk_i, .rst_ni, .obi_s(sbr_bus[2]), .obi_m(apb_bus));
  obi_cut_intf i_axi_mgr_cut  (.clk_i, .rst_ni, .obi_s(sbr_bus[3]), .obi_m(axi_mgr));

  for (genvar i = 0; i < NumMemBanks; i++) begin : g_mem_ports
    obi_cut_intf i_axi_sbr_cut (.clk_i, .rst_ni, .obi_s(sbr_bus[4+i]), .obi_m(mem_bus[i]));
  end : g_mem_ports

end else begin : g_no_mgr_cut

  `OBI_ASSIGN(core_mgr,    sbr_bus[0], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(dbg_rom_mgr, sbr_bus[1], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(apb_bus,     sbr_bus[2], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(axi_mgr,     sbr_bus[3], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)

  for (genvar i = 0; i < NumMemBanks; i++) begin : g_mem_ports
    `OBI_ASSIGN(mem_bus[i], sbr_bus[4+i], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  end : g_mem_ports
end

if (CutSbrPorts) begin : g_sbr_cut
  obi_cut_intf i_core_sbr_cut (.clk_i, .rst_ni, .obi_s(core_sbr), .obi_m(mgr_bus[0]));
  obi_cut_intf i_axi_dbg_cut  (.clk_i, .rst_ni, .obi_s(dbg_sbr),  .obi_m(mgr_bus[1]));
  obi_cut_intf i_axi_sbr_cut  (.clk_i, .rst_ni, .obi_s(axi_sbr),  .obi_m(mgr_bus[2]));
end else begin : g_no_sbr_cut
  `OBI_ASSIGN(mgr_bus[0], core_sbr, obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(mgr_bus[1], dbg_sbr,  obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(mgr_bus[2], axi_sbr,  obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
end

obi_xbar_intf #(
  .NumSbrPorts     (XbarCfg.NumM),
  .NumMgrPorts     (XbarCfg.NumS),
  .NumMaxTrans     (XbarCfg.MaxTrans),
  .NumAddrRules    (XbarCfg.NumS),
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

rt_memory_banks #(
  .NrMemBanks    (rt_pkg::NumMemBanks)
) i_memory_banks (
  .clk_i,
  .rst_ni,
  .obi_sbr (mem_bus)
);

obi_to_apb_intf #() i_obi_to_apb (
  .clk_i,
  .rst_ni,
  .obi_i (apb_bus),
  .apb_o (apb_mgr)
);

endmodule : rt_interconnect
