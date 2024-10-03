`include "obi/typedef.svh"
`include "obi/assign.svh"

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
  input  logic            ibex_rst_ni,
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
  OBI_BUS.Manager         obim_rom,
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
*/


rt_pkg::rule_t EmptyRule  = '{idx: 32'd0, start_addr: 32'hFFFF_FFF0,  end_addr: 32'hFFFF_FFFF };

rt_pkg::rule_t [XbarCfg.NumS-1:0] AddrMap = '{
  rt_pkg::SramRule,
  rt_pkg::SramRule,
  rt_pkg::AxiRule,
  rt_pkg::ApbRule,
  rt_pkg::DmemRule,
  rt_pkg::ImemRule,
  rt_pkg::DbgRule,
  rt_pkg::RomRule
};

logic [NumInterrupts-1:0] core_irq_x;

OBI_BUS #() mgr_bus [rt_pkg::ObiXbarCfg.NumM] (), sbr_bus [rt_pkg::ObiXbarCfg.NumS] ();

`OBI_ASSIGN(mgr_bus[0], obis_debug, obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
`OBI_ASSIGN(mgr_bus[3], obis_axi, obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)

`OBI_ASSIGN(obim_debug, sbr_bus[0], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
`OBI_ASSIGN(obim_rom, sbr_bus[1], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
`OBI_ASSIGN(obim_axi, sbr_bus[5], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)

for (genvar i = 0; i < NrMemBanks; i++) begin : g_mem_banks
  `OBI_ASSIGN(obim_memory[i], sbr_bus[6+i], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
end : g_mem_banks

//assign sbr_bus[4].gnt    = 0;
//assign sbr_bus[4].rvalid = 0;

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

obi_sram_intf #() i_imem (
  .clk_i,
  .rst_ni,
  .sbr_bus (sbr_bus[2])
);
obi_sram_intf #() i_dmem (
  .clk_i,
  .rst_ni,
  .sbr_bus (sbr_bus[3])
);

obi_to_apb_intf #() i_obi_to_apb (
  .clk_i,
  .rst_ni,
  .obi_i (sbr_bus[4]),
  .apb_o (apbm_peripheral)
);

`ifndef SYNTHESIS
ibex_top_tracing #(
`else
ibex_top #(
`endif
  .PMPEnable        (0),
  .PMPGranularity   (0),
  .PMPNumRegions    (4),
  .MHPMCounterNum   (0),
  .MHPMCounterWidth (40),
  .RV32E            (RVE),
  .RV32M            (ibex_pkg::RV32MFast),
  .RV32B            (ibex_pkg::RV32BNone),
  .WritebackStage   (1'b0),
`ifdef FPGA          //ASIC Implementation
  .RegFile          (ibex_pkg::RegFileFPGA),
`else                 // FPGA Implementation
  .RegFile          ( ibex_pkg::RegFileFF),
  //.RegFile          ( ibex_pkg::RegFileLatch),
`endif
  .ICache           (0),
  .ICacheECC        (0),
  .ICacheScramble   (0),
  .BranchPredictor  (0),
  .SecureIbex       (0),
  .CLIC             (1),
  .HardwareStacking (1'b0),
  .NumInterrupts   (NumInterrupts),
  .RndCnstLfsrSeed  (ibex_pkg::RndCnstLfsrSeedDefault),
  .RndCnstLfsrPerm  (ibex_pkg::RndCnstLfsrPermDefault),
  .DbgTriggerEn     (0),
  .DmHaltAddr       (dm::HaltAddress),
  .DmExceptionAddr  (dm::ExceptionAddress)
) i_cpu (
  // Clock and reset
  .clk_i       (clk_i),
  .rst_ni      (ibex_rst_ni),
  .test_en_i   ('0),
  .scan_rst_ni ('0),
  .ram_cfg_i   ('0),

  // Configuration
  .hart_id_i   (32'h0),
  .boot_addr_i (rt_pkg::ObiXbarCfg.RomStart),

  // Instruction memory interface
  .instr_req_o        (mgr_bus[1].req ),
  .instr_gnt_i        (mgr_bus[1].gnt ),
  .instr_rvalid_i     (mgr_bus[1].rvalid ),
  .instr_addr_o       (mgr_bus[1].addr ),
  .instr_rdata_i      (mgr_bus[1].rdata ),
  .instr_rdata_intg_i ('0 ),
  .instr_err_i        ('0 ),

  // Data memory interface
  .data_req_o             (mgr_bus[2].req),
  .data_gnt_i             (mgr_bus[2].gnt),
  .data_rvalid_i          (mgr_bus[2].rvalid),
  .data_we_o              (mgr_bus[2].we),
  .data_be_o              (mgr_bus[2].be),
  .data_addr_o            (mgr_bus[2].addr),
  .data_wdata_o           (mgr_bus[2].wdata),
  .data_wdata_intg_o      (),
  .data_rdata_i           (mgr_bus[2].rdata),
  .data_rdata_intg_i      ('0 ),
  .data_err_i             ('0 ),

  // Interrupt inputs
  .irq_i       (core_irq_x),
  .irq_id_o    (),
  .irq_ack_o   (irq_ready_o),
  .irq_level_i (irq_level_i),
  .irq_shv_i   (irq_shv_i),
  .irq_priv_i  (irq_priv_i),

  // Debug interface
  .debug_req_i,
  .crash_dump_o (),

  // Special control signals
  .fetch_enable_i         (4'b0101),
  .alert_minor_o          (),
  .alert_major_internal_o (),
  .alert_major_bus_o      (),
  .core_sleep_o           (),

  .scramble_key_valid_i   ('0),
  .scramble_key_i         ('0),
  .scramble_nonce_i       ('0),
  .scramble_req_o         (),
  .double_fault_seen_o    ()
);

always_comb begin : gen_core_irq_x
    core_irq_x = '0;
    if (irq_valid_i) begin
        core_irq_x[irq_id_i] = 1'b1;
    end
end

for (genvar i = 0; i < rt_pkg::ObiXbarCfg.NumM; i++) begin : g_tieoff
  // OBI_ASSIGN seems to miss some signals
  assign mgr_bus[i].reqpar     = 0;
  assign mgr_bus[i].rready     = 0;
  assign mgr_bus[i].rreadypar  = 0;
  if (i == 1 || i == 2) begin : g_extra_tieoff
    assign mgr_bus[i].aid        = 0;
    assign mgr_bus[i].a_optional = 0;
  end : g_extra_tieoff
  assign sbr_bus[i].gntpar     = 0;
  assign sbr_bus[i].rvalidpar  = 0;
  assign sbr_bus[i].rready     = 0;
  assign sbr_bus[i].rreadypar  = 0;
end : g_tieoff

// IMEM tieoff
assign mgr_bus[1].we    = '0;
assign mgr_bus[1].be    = '0;
assign mgr_bus[1].wdata = '0;


endmodule : rt_core
