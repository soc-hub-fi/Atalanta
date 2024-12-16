module rt_core #(
  parameter int unsigned AddrWidth      = 32,
  parameter int unsigned DataWidth      = 32,
  parameter int unsigned NumInterrupts  = 64,
  parameter bit          RVE            =  1,
  parameter rt_pkg::xbar_cfg_t XbarCfg  = rt_pkg::CoreXbarCfg,
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
  OBI_BUS.Manager         main_xbar_mgr,
  OBI_BUS.Subordinate     main_xbar_sbr
);

OBI_BUS #() lsu_mgr  ();
OBI_BUS #() if_mgr   ();
OBI_BUS #() if_demux  [3]();
OBI_BUS #() lsu_demux [2]();
OBI_BUS #() ext_demux [2]();
OBI_BUS #() imem_mux  [2]();
OBI_BUS #() dmem_mux  [2]();
OBI_BUS #() ext_mux   [2]();
OBI_BUS #() imem_sbr  ();
OBI_BUS #() dmem_sbr  ();

logic [NumInterrupts-1:0] core_irq_x;
logic lsu_sel, ext_sel;
logic lsu_dmem_hit;
logic [1:0] if_sel;
logic debug_mode;
logic if_dbg_sel;

// add hierarchy for xbar without module
if (1) begin : g_part_connected_xbar


assign if_dbg_sel = debug_mode | debug_req_i;
assign lsu_dmem_hit = lsu_mgr.req & (lsu_mgr.addr >= rt_pkg::DmemRule.Start
                                   & lsu_mgr.addr <  rt_pkg::DmemRule.End);

assign lsu_sel = (if_dbg_sel | ~lsu_dmem_hit);

assign if_sel  = (if_dbg_sel) ? 2'b01 : (if_mgr.addr < rt_pkg::ImemRule.End) ? 2'b00 : 2'b10;
assign ext_sel = ~(main_xbar_sbr.addr < rt_pkg::ImemRule.End);

obi_join if_imem_join  ( .Src (if_demux[0]),  .Dst (imem_mux[0]));
obi_join if_ext_join   ( .Src (if_demux[1]),  .Dst (ext_mux[0] ));
obi_join lsu_dmem_join ( .Src (lsu_demux[0]), .Dst (dmem_mux[0]));
obi_join lsu_ext_join  ( .Src (lsu_demux[1]), .Dst (ext_mux[1] ));
obi_join ext_imem_join ( .Src (ext_demux[0]), .Dst (imem_mux[1]));
obi_join ext_dmem_join ( .Src (ext_demux[1]), .Dst (dmem_mux[1]));

obi_demux_intf #(
  .NumMgrPorts (3),
  .NumMaxTrans    (XbarCfg.MaxTrans)
) i_if_demux (
  .clk_i,
  .rst_ni,
  .sbr_port_select_i (if_sel),
  .sbr_port          (if_mgr),
  .mgr_ports         (if_demux)
);

obi_demux_intf #(
  .NumMgrPorts (2),
  .NumMaxTrans    (XbarCfg.MaxTrans)
) i_lsu_demux (
  .clk_i,
  .rst_ni,
  .sbr_port_select_i (lsu_sel),
  .sbr_port          (lsu_mgr),
  .mgr_ports         (lsu_demux)
);

obi_demux_intf #(
  .NumMgrPorts (2),
  .NumMaxTrans    (XbarCfg.MaxTrans)
) i_ext_demux (
  .clk_i,
  .rst_ni,
  .sbr_port_select_i (ext_sel),
  .sbr_port          (main_xbar_sbr),
  .mgr_ports         (ext_demux)
);

obi_mux_intf #(
  .NumSbrPorts (2),
  .NumMaxTrans    (XbarCfg.MaxTrans)
) i_imem_mux (
  .clk_i,
  .rst_ni,
  .testmode_i (1'b0),
  .sbr_ports  (imem_mux),
  .mgr_port   (imem_sbr)
);

obi_mux_intf #(
  .NumSbrPorts (2),
  .NumMaxTrans    (XbarCfg.MaxTrans)
) i_dmem_mux (
  .clk_i,
  .rst_ni,
  .testmode_i (1'b0),
  .sbr_ports  (dmem_mux),
  .mgr_port   (dmem_sbr)
);

obi_mux_intf #(
  .NumSbrPorts (2),
  .NumMaxTrans    (XbarCfg.MaxTrans)
) i_ext_mux (
  .clk_i,
  .rst_ni,
  .testmode_i (1'b0),
  .sbr_ports  (ext_mux),
  .mgr_port   (main_xbar_mgr)
);

assign main_xbar_mgr.reqpar    = '0;
assign main_xbar_mgr.rready    = '0;
assign main_xbar_mgr.rreadypar = '0;

//assign ext_mux[1].reqpar    = '0;
//assign ext_mux[1].rready    = '0;
//assign ext_mux[1].rreadypar = '0;

end : g_part_connected_xbar


obi_sram_intf #(
  .NumWords (rt_pkg::ImemSizeBytes / 4),
  .BaseAddr (rt_pkg::ImemRule.Start)
) i_imem (
  .clk_i,
  .rst_ni,
  .sbr_bus (imem_sbr)
);

rt_ibex_bootrom #() i_rom (
  .clk_i,
  .rst_ni,
  .sbr_bus (if_demux[2])
);

obi_sram_intf #(
  .NumWords (rt_pkg::DmemSizeBytes / 4),
  .BaseAddr (rt_pkg::DmemRule.Start)
) i_dmem (
  .clk_i,
  .rst_ni,
  .sbr_bus (dmem_sbr)
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
  .WritebackStage   (1'b1),
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
  .NumInterrupts    (NumInterrupts),
  .RndCnstLfsrSeed  (ibex_pkg::RndCnstLfsrSeedDefault),
  .RndCnstLfsrPerm  (ibex_pkg::RndCnstLfsrPermDefault),
  .DbgTriggerEn     (0),
  .DmHaltAddr       (dm::HaltAddress),
  .DmExceptionAddr  (dm::ExceptionAddress),
  .BranchTargetALU  (1'b1)
) i_cpu (
  // Clock and reset
  .clk_i       (clk_i),
  .rst_ni      (ibex_rst_ni),
  .test_en_i   ('0),
  .scan_rst_ni ('0),
  .ram_cfg_i   ('0),

  // Configuration
  .hart_id_i   (32'h0),
  .boot_addr_i (rt_pkg::RomRule.Start),

  // Instruction memory interface
  .instr_req_o        (if_mgr.req ),
  .instr_gnt_i        (if_mgr.gnt ),
  .instr_rvalid_i     (if_mgr.rvalid ),
  .instr_addr_o       (if_mgr.addr ),
  .instr_rdata_i      (if_mgr.rdata ),
  .instr_rdata_intg_i ('0 ),
  .instr_err_i        ('0 ),

  // Data memory interface
  .data_req_o             (lsu_mgr.req),
  .data_gnt_i             (lsu_mgr.gnt),
  .data_rvalid_i          (lsu_mgr.rvalid),
  .data_we_o              (lsu_mgr.we),
  .data_be_o              (lsu_mgr.be),
  .data_addr_o            (lsu_mgr.addr),
  .data_wdata_o           (lsu_mgr.wdata),
  .data_wdata_intg_o      (),
  .data_rdata_i           (lsu_mgr.rdata),
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
  .debug_mode_o (debug_mode),
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


// Tie off unused signals
assign if_mgr.reqpar     = 1'b0;
assign if_mgr.aid        = '0;
assign if_mgr.a_optional = '0;
assign if_mgr.rready     = '0;
assign if_mgr.rreadypar  = '0;

assign lsu_mgr.reqpar     = 1'b0;
assign lsu_mgr.aid        = '0;
assign lsu_mgr.a_optional = '0;
assign lsu_mgr.rready     = '0;
assign lsu_mgr.rreadypar  = '0;


assign if_mgr.be     = 4'hF;
assign if_mgr.wdata  = '0;
assign if_mgr.we     = 1'b0;


endmodule : rt_core
