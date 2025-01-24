/*
  RT-SS top level module
  authors: Antti Nurmi <antti.nurmi@tuni.fi>
*/

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
  localparam int unsigned StrbWidth   = (AxiDataWidth / 8),
  localparam int unsigned GpioPadNum  = 4,
  localparam int unsigned TimerGroupSize = 2

)(
  input  logic                   clk_i,
  input  logic                   rst_ni,

  input  logic [GpioPadNum-1:0]  gpio_input_i,
  output logic [GpioPadNum-1:0]  gpio_output_o,

  input  logic                   uart_rx_i,
  output logic                   uart_tx_o,

  AXI_BUS.Slave                  soc_slv,
  AXI_BUS.Master                 soc_mst,

  input  logic           [3:0]   spi_sdi_i,
  output logic           [3:0]   spi_sdo_o,
  output logic           [3:0]   spi_csn_o,
  output logic                   spi_clk_o,

  input  logic                   jtag_tck_i,
  input  logic                   jtag_tms_i,
  input  logic                   jtag_trst_ni,
  input  logic                   jtag_td_i,
  output logic                   jtag_td_o,

  input  logic [ClicIrqSrcs-1:0] intr_src_i
);

localparam int unsigned DgbDmuxWidth = 2;
localparam int unsigned DmaSelWidth  = $clog2(rt_pkg::NumDMAs);

logic ibex_rst_n, ndmreset, debug_req, dbg_dmux_sel;
logic [DmaSelWidth-1:0] dma_dmux_sel;

logic [rt_pkg::NumDMAs-1:0] dma_irqs;

logic            irq_valid;
logic            irq_ready;
logic [SrcW-1:0] irq_id;
logic [     7:0] irq_level;
logic            irq_shv;
logic [     1:0] irq_priv;
logic            irq_is_pcs;

APB #() apb_bus ();
OBI_BUS #() axi_mgr_bus  ();
OBI_BUS #() axi_sbr_bus  ();
OBI_BUS #() dbg_mgr_bus  ();
OBI_BUS #() dma_mgr_bus  ();
OBI_BUS #() demux_sbr_bus [DgbDmuxWidth] ();
OBI_BUS #() core_mgr_bus ();
OBI_BUS #() core_sbr_bus ();
OBI_BUS #() dbg_rom_bus  ();
OBI_BUS #() dma_dmux_bus [rt_pkg::NumDMAs] ();
OBI_BUS #() dma_rd_bus   [rt_pkg::NumDMAs] ();
OBI_BUS #() dma_wr_bus   [rt_pkg::NumDMAs] ();


assign ibex_rst_n = rst_ni & ~(ndmreset);
assign dbg_dmux_sel = (dbg_rom_bus.addr <= rt_pkg::RomRule.Start);
assign dma_dmux_sel = (dma_mgr_bus.addr <= rt_pkg::DmaRule.Start);

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
  .irq_is_pcs_i    (irq_is_pcs),
  .debug_req_i     (debug_req),
  .main_xbar_mgr   (core_mgr_bus),
  .main_xbar_sbr   (core_sbr_bus)
);

rt_interconnect #() i_interconnect (
  .clk_i,
  .rst_ni,
  .dbg_sbr     (dbg_mgr_bus),
  .dbg_rom_mgr (dbg_rom_bus),
  .core_sbr    (core_mgr_bus),
  .core_mgr    (core_sbr_bus),
  .axi_mgr     (axi_mgr_bus),
  .dma_mgr     (dma_mgr_bus),
  .axi_sbr     (axi_sbr_bus),
  .apb_mgr     (apb_bus),
  .dma_rd_sbr  (dma_rd_bus),
  .dma_wr_sbr  (dma_wr_bus)
);

for (genvar ii=0; ii<rt_pkg::NumDMAs; ii++) begin : g_dmas
  ndma #(
    .Depth (3)
  ) i_ndma (
    .clk_i,
    .rst_ni,
    .cfg_req_i     (dma_dmux_bus[ii].req),
    .cfg_gnt_o     (dma_dmux_bus[ii].gnt),
    .cfg_we_i      (dma_dmux_bus[ii].we),
    .cfg_addr_i    (dma_dmux_bus[ii].addr),
    .cfg_wdata_i   (dma_dmux_bus[ii].wdata),
    .cfg_rdata_o   (dma_dmux_bus[ii].rdata),
    .cfg_rvalid_o  (dma_dmux_bus[ii].rvalid),
    .read_mgr      (dma_rd_bus[ii]),
    .write_mgr     (dma_wr_bus[ii]),
    .tx_done_irq_o (dma_irqs)
  );
  assign dma_dmux_bus[ii].gntpar    = 0;
  assign dma_dmux_bus[ii].rvalidpar = 0;
end : g_dmas

if (rt_pkg::NumDMAs == 1'b1) begin : g_no_demux
  obi_join i_dma_join (.Dst(dma_dmux_bus[0]), .Src (dma_mgr_bus));
end else begin : g_dma_demux
obi_demux_intf #(
  .NumMgrPorts (rt_pkg::NumDMAs),
  .NumMaxTrans (rt_pkg::MainXbarCfg.MaxTrans)
) i_dma_demux (
  .clk_i,
  .rst_ni,
  .sbr_port_select_i (dma_dmux_sel),
  .sbr_port          (dma_mgr_bus),
  .mgr_ports         (dma_dmux_bus)
);
end : g_dma_demux

rt_ibex_bootrom #() i_rom (
  .clk_i,
  .rst_ni,
  .sbr_bus (demux_sbr_bus[0])
);



rt_peripherals #(
  .NSource       (ClicIrqSrcs)
) i_peripherals (
  .clk_i,
  .rst_ni,
  .apb_i          (apb_bus),
  .uart_rx_i      (uart_rx_i),
  .uart_tx_o      (uart_tx_o),
  .irq_kill_req_o (),
  .irq_kill_ack_i (1'b0),
  .irq_priv_o     (irq_priv),
  .irq_shv_o      (irq_shv),
  .irq_level_o    (irq_level),
  .irq_valid_o    (irq_valid),
  .irq_ready_i    (irq_ready),
  .irq_id_o       (irq_id),
  .irq_is_pcs_o   (irq_is_pcs),
  .irq_src_i      (intr_src_i),
  .gpio_i         (gpio_input_i),
  .gpio_o         (gpio_output_o),
  .dma_irqs_i     (dma_irqs),
  .spi_sdi_i      (spi_sdi_i),
  .spi_sdo_o      (spi_sdo_o),
  .spi_csn_o      (spi_csn_o),
  .spi_clk_o      (spi_clk_o)
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
  .dbg_mst         (dbg_mgr_bus),
  .dbg_slv         (dbg_rom_bus)
);


axi_to_obi_intf #(
  .AxiIdWidth   (AxiIdWidth),
  .AxiUserWidth (AxiUserWidth),
  .MaxTrans     (rt_pkg::MainXbarCfg.MaxTrans)
) i_axi_to_obi (
  .clk_i,
  .rst_ni,
  .obi_out (axi_sbr_bus),
  .axi_in  (soc_slv)
);


obi_to_axi_intf #(
  .AxiIdWidth   (AxiIdWidth),
  .AxiUserWidth (AxiUserWidth),
  .MaxRequests  (rt_pkg::MainXbarCfg.MaxTrans)
) i_obi_to_axi (
  .clk_i,
  .rst_ni,
  .axi_out (soc_mst),
  .obi_in  (axi_mgr_bus)
);

endmodule : rt_top
