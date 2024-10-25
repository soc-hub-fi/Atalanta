module rt_memory_banks #(
  parameter rt_pkg::xbar_cfg_t XbarCfg  = rt_pkg::ObiXbarCfg,
  parameter int unsigned NrMemBanks     = 2
)(
  input logic         clk_i,
  input logic         rst_ni,
  OBI_BUS.Subordinate obi_sbr [NrMemBanks]
);

localparam int unsigned NrBanks        = NrMemBanks;
localparam int unsigned SramStart      = XbarCfg.SramStart;
localparam int unsigned SramEnd        = XbarCfg.SramEnd;
localparam int unsigned SramSizeBytes  = rt_pkg::get_addr_size(SramEnd, SramStart);

for (genvar i=0; i<NrMemBanks; i++) begin : g_mem_banks

  obi_sram_intf #(
    .NumWords ((SramSizeBytes / 4) / NrBanks)
  ) i_bank (
    .clk_i,
    .rst_ni,
    .sbr_bus (obi_sbr[i])
  );

end : g_mem_banks

endmodule : rt_memory_banks
