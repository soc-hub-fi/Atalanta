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
  OBI_BUS.Manager     dma_mgr,
  OBI_BUS.Subordinate axi_sbr,
  OBI_BUS.Subordinate dma_rd_sbr [rt_pkg::NumDMAs],
  OBI_BUS.Subordinate dma_wr_sbr [rt_pkg::NumDMAs],
  APB.Master          apb_mgr
);

localparam rt_pkg::xbar_cfg_t XbarCfg = rt_pkg::MainXbarCfg;
localparam int unsigned NumMemBanks   = rt_pkg::NumMemBanks;
localparam int unsigned NumDMAs       = rt_pkg::NumDMAs;
localparam int unsigned IcnNrSlv      = rt_pkg::MainXbarCfg.NumS;

OBI_BUS #() mgr_bus [XbarCfg.NumM] (), sbr_bus [XbarCfg.NumS] ();
OBI_BUS #() sram_bus [NumMemBanks] ();
OBI_BUS #() apb_bus ();


// Compile-time mapping of SRAM to size, # ports
rt_pkg::xbar_rule_t [NumMemBanks-1:0] SramRules;
for (genvar i=0; i<NumMemBanks; i++) begin : g_sram_rules
  assign SramRules[i] = '{
    idx: 32'd5+i,
    start_addr : (rt_pkg::SramRule.Start) + rt_pkg::SramSizeBytes*(i*1/NumMemBanks),
    end_addr   : (rt_pkg::SramRule.Start) + rt_pkg::SramSizeBytes*((i+1)*1/NumMemBanks)
  };
end : g_sram_rules

rt_pkg::xbar_rule_t [(rt_pkg::MainXbarCfg.NumS-NumMemBanks+1)-1:0] OtherRules;
assign OtherRules[0] = '{idx: 0, start_addr: rt_pkg::ImemRule.Start, end_addr: rt_pkg::DmemRule.End};
assign OtherRules[1] = '{idx: 1, start_addr: rt_pkg::DbgRule.Start,  end_addr: rt_pkg::DbgRule.End};
assign OtherRules[2] = '{idx: 1, start_addr: rt_pkg::RomRule.Start,  end_addr: rt_pkg::RomRule.End};
assign OtherRules[3] = '{idx: 2, start_addr: rt_pkg::ApbRule.Start,  end_addr: rt_pkg::ApbRule.End};
assign OtherRules[4] = '{idx: 3, start_addr: rt_pkg::AxiRule.Start,  end_addr: rt_pkg::AxiRule.End};
assign OtherRules[5] = '{idx: 4, start_addr: rt_pkg::DmaRule.Start,  end_addr: rt_pkg::DmaRule.End};


rt_pkg::xbar_rule_t [IcnNrSlv-1:0] MainAddrMap; // = {OtherRules, SramRules};
for (genvar i=0; i<IcnNrSlv; i++) begin : g_addr_map_assign
  if (i < IcnNrSlv-NumMemBanks) begin : g_other_rules
    assign MainAddrMap[i] = OtherRules[i];
  end else begin : g_sram_rules
    assign MainAddrMap[i] = SramRules[i-(IcnNrSlv-NumMemBanks)];
  end
end : g_addr_map_assign


if (CutMgrPorts) begin : g_mgr_cut

  obi_cut_intf i_core_mgr_cut (.clk_i, .rst_ni, .obi_s(sbr_bus[0]), .obi_m(core_mgr));
  obi_cut_intf i_dbg_rom_cut  (.clk_i, .rst_ni, .obi_s(sbr_bus[1]), .obi_m(dbg_rom_mgr));
  obi_cut_intf i_apb_mgr_cut  (.clk_i, .rst_ni, .obi_s(sbr_bus[2]), .obi_m(apb_bus));
  obi_cut_intf i_axi_mgr_cut  (.clk_i, .rst_ni, .obi_s(sbr_bus[3]), .obi_m(axi_mgr));
  obi_cut_intf i_dma_mgr_cut  (.clk_i, .rst_ni, .obi_s(sbr_bus[4]), .obi_m(dma_mgr));

  for (genvar i = 0; i < NumMemBanks; i++) begin : g_mem_ports
    obi_cut_intf i_sram_sbr_cut (.clk_i, .rst_ni, .obi_s(sbr_bus[5+i]), .obi_m(sram_bus[i]));
  end : g_mem_ports

end else begin : g_no_mgr_cut

  `OBI_ASSIGN(core_mgr,    sbr_bus[0], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(dbg_rom_mgr, sbr_bus[1], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(apb_bus,     sbr_bus[2], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(axi_mgr,     sbr_bus[3], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(dma_mgr,     sbr_bus[4], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)

  for (genvar i = 0; i < NumMemBanks; i++) begin : g_mem_ports
    `OBI_ASSIGN(sram_bus[i], sbr_bus[5+i], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  end : g_mem_ports
end

if (CutSbrPorts) begin : g_sbr_cut
  obi_cut_intf i_core_sbr_cut (.clk_i, .rst_ni, .obi_s(core_sbr), .obi_m(mgr_bus[0]));
  obi_cut_intf i_axi_dbg_cut  (.clk_i, .rst_ni, .obi_s(dbg_sbr),  .obi_m(mgr_bus[1]));
  obi_cut_intf i_axi_sbr_cut  (.clk_i, .rst_ni, .obi_s(axi_sbr),  .obi_m(mgr_bus[2]));

  for (genvar i = 0; i < NumDMAs; i++) begin : g_dma_mgrs
    obi_cut_intf i_dma_rd_cut (.clk_i, .rst_ni, .obi_s(dma_rd_sbr[i]), .obi_m(mgr_bus[3+(2*i)]));
    obi_cut_intf i_dma_wd_cut (.clk_i, .rst_ni, .obi_s(dma_wr_sbr[i]), .obi_m(mgr_bus[4+(2*i)]));
  end

end else begin : g_no_sbr_cut
  `OBI_ASSIGN(mgr_bus[0], core_sbr, obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(mgr_bus[1], dbg_sbr,  obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(mgr_bus[2], axi_sbr,  obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)

  for (genvar i = 0; i < NumDMAs; i++) begin : g_dma_mgrs
    `OBI_ASSIGN(mgr_bus[3+(2*i)], dma_rd_sbr, obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
    `OBI_ASSIGN(mgr_bus[4+(2*i)], dma_wr_sbr, obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  end
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

for (genvar i=0; i<NumMemBanks; i++) begin : g_mem_banks

  obi_sram_intf #(
    .NumWords ((rt_pkg::SramSizeBytes / 4) / NumMemBanks),
    .BaseAddr ((rt_pkg::SramRule.Start) + rt_pkg::SramSizeBytes*(i*1/NumMemBanks))
  ) i_bank (
    .clk_i,
    .rst_ni,
    .sbr_bus (sram_bus[i])
  );

end : g_mem_banks

obi_to_apb_intf #() i_obi_to_apb (
  .clk_i,
  .rst_ni,
  .obi_i (apb_bus),
  .apb_o (apb_mgr)
);
endmodule : rt_interconnect
