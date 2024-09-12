`include "obi/typedef.svh"
`include "obi/assign.svh"

module rt_core #(
  parameter int unsigned AddrWidth     = 32,
  parameter int unsigned DataWidth     = 32,
  parameter int unsigned NumInterrupts = 64,
  parameter bit           RVE           = 1,
  parameter bit          CutObiDbg         = 1,
  parameter bit          CutObiMem         = 1,
  localparam int unsigned SrcW          = $clog2(NumInterrupts),
  localparam int unsigned MemSize      = 32'h4000,
  localparam int unsigned ImemOffset   = 32'h1000,
  localparam int unsigned DmemOffset   = 32'h5000
)(
  input  logic            clk_i,
  input  logic            rst_ni,
  input  logic            irq_valid_i,
  output logic            irq_ready_o,
  input  logic [SrcW-1:0] irq_id_i,
  input  logic [     7:0] irq_level_i,
  input  logic            irq_shv_i,
  input  logic [     1:0] irq_priv_i,
  input  logic            jtag_tck_i,    // JTAG test clock pad
  input  logic            jtag_tms_i,    // JTAG test mode select pad
  input  logic            jtag_trst_ni,  // JTAG test reset pad
  input  logic            jtag_td_i,     // JTAG test data input pad
  output logic            jtag_td_o,     // JTAG test data output pad
`ifndef STANDALONE
  AXI_LITE.Slave          axi_s,
`endif
  AXI_LITE.Master         axi_m
);

`ifndef STANDALONE
  localparam int CONNECTIVITY = 1;
`else
  localparam int CONNECTIVITY = 0;
`endif

localparam int unsigned NumM = 3 + CONNECTIVITY;
localparam int unsigned NumS = 5;
localparam int unsigned NumRules = NumS;

logic [NumInterrupts-1:0] core_irq_x;
logic debug_req, ibex_rst_n, ndmreset;


typedef struct packed {
  int unsigned idx;
  logic [AddrWidth-1:0] start_addr;
  logic [AddrWidth:0] end_addr;
} rule_t;

localparam rule_t [NumRules-1:0] AddrMap = '{
  '{idx: 32'd4, start_addr: 32'h0003_0000, end_addr: 32'hFFFF_FFFF}, // System
  '{idx: 32'd3, start_addr: 32'h0001_0000, end_addr: 32'h0001_1000}, // System
  '{idx: 32'd2, start_addr: DmemOffset, end_addr: DmemOffset+MemSize}, // DMEM
  '{idx: 32'd1, start_addr: ImemOffset, end_addr: ImemOffset+MemSize}, // IMEM
  '{idx: 32'd0, start_addr: 32'h0000_0000, end_addr: 32'h0000_1000}  // Debug
};

OBI_BUS #() mgr_bus [NumM] (), sbr_bus [NumS] (), dbg_mst (), dbg_slv (), imem_slv (), dmem_slv ();

if (CONNECTIVITY) begin : gen_slv_connectivity

  rt_mem_axi_intf #(
    .MEM_AW (AddrWidth),
    .MEM_DW (DataWidth),
    .AXI_AW (AddrWidth),
    .AXI_DW (DataWidth)
  ) i_axis_intf (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .req_o      (mgr_bus[3].req),
    .we_o       (mgr_bus[3].we),
    .addr_o     (mgr_bus[3].addr),
    .wdata_o    (mgr_bus[3].wdata),
    .be_o       (mgr_bus[3].be),
    .rdata_i    (mgr_bus[3].rdata),
    .axi_lite_s (axi_s)
  );

end


// TODO: replace with interface version
ibex_axi_bridge #(
  .IBEX_AW (AddrWidth),
  .IBEX_DW (DataWidth),
  .AXI_AW (AddrWidth),
  .AXI_DW (DataWidth)
) i_axim_intf (
  .clk_i      (clk_i),
  .rst_ni     (rst_ni),
  .req_i      (sbr_bus[4].req),
  .gnt_o      (sbr_bus[4].gnt),
  .rvalid_o   (sbr_bus[4].rvalid),
  .we_i       (sbr_bus[4].we),
  .be_i       (sbr_bus[4].be),
  .addr_i     (sbr_bus[4].addr),
  .wdata_i    (sbr_bus[4].wdata),
  .rdata_o    (sbr_bus[4].rdata),
  .err_o      (),
  .aw_addr_o  (axi_m.aw_addr),
  .aw_valid_o (axi_m.aw_valid),
  .aw_ready_i (axi_m.aw_ready),
  .w_data_o   (axi_m.w_data),
  .w_strb_o   (axi_m.w_strb),
  .w_valid_o  (axi_m.w_valid),
  .w_ready_i  (axi_m.w_ready),
  .b_resp_i   (axi_m.b_resp),
  .b_valid_i  (axi_m.b_valid),
  .b_ready_o  (axi_m.b_ready),
  .ar_addr_o  (axi_m.ar_addr),
  .ar_valid_o (axi_m.ar_valid),
  .ar_ready_i (axi_m.ar_ready),
  .r_data_i   (axi_m.r_data),
  .r_resp_i   (axi_m.r_resp),
  .r_valid_i  (axi_m.r_valid),
  .r_ready_o  (axi_m.r_ready)
);


obi_xbar_intf #(
  .NumSbrPorts     (NumM),
  .NumMgrPorts     (NumS),
  .NumMaxTrans     (3),
  .NumAddrRules    (NumRules),
  .addr_map_rule_t (rule_t),
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

rt_mem #(
  .AddrWidth  (AddrWidth),
  .DataWidth  (DataWidth),
  .MemSize    (MemSize),
  .BaseOffset (ImemOffset)
) i_imem (
  .clk_i    (clk_i),
  .rst_ni   (rst_ni),
  .req_i    (imem_slv.req),
  .gnt_o    (imem_slv.gnt),
  .rvalid_o (imem_slv.rvalid),
  .we_i     (imem_slv.we),
  .be_i     (imem_slv.be),
  .addr_i   (imem_slv.addr),
  .wdata_i  (imem_slv.wdata),
  .rdata_o  (imem_slv.rdata)
);

rt_mem #(
  .AddrWidth  (AddrWidth),
  .DataWidth  (DataWidth),
  .MemSize    (MemSize),
  .BaseOffset (DmemOffset)
) i_dmem (
  .clk_i    (clk_i),
  .rst_ni   (rst_ni),
  .req_i    (dmem_slv.req),
  .gnt_o    (dmem_slv.gnt),
  .rvalid_o (dmem_slv.rvalid),
  .we_i     (dmem_slv.we),
  .be_i     (dmem_slv.be),
  .addr_i   (dmem_slv.addr),
  .wdata_i  (dmem_slv.wdata),
  .rdata_o  (dmem_slv.rdata)
);

rt_bootrom #(
) i_bootrom (
  .clk_i,
  .rst_ni,
  .sbr_bus (sbr_bus[3])
);

`ifdef DEBUG
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
    .rst_ni      (ibex_rst_n),
    .test_en_i   ('0),
    .scan_rst_ni ('0),
    .ram_cfg_i   ('0),

    // Configuration
    .hart_id_i   (32'h0),
    .boot_addr_i (32'h800),

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
    .debug_req_i  (debug_req),
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

if (CutObiDbg) begin : g_obi_cut_dbg
  obi_m2s_cut #() i_dbg_mst_cut (
    .clk_i (clk_i),
    .rst_ni(rst_ni),
    .obi_s (dbg_mst),
    .obi_m (mgr_bus[0])
  );
  obi_m2s_cut #() i_dbg_slv_cut (
    .clk_i (clk_i),
    .rst_ni(rst_ni),
    .obi_s (sbr_bus[0]),
    .obi_m (dbg_slv)
  );
end else begin : g_no_cut_dbg
  `OBI_ASSIGN(dbg_mst, mgr_bus[0], obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(sbr_bus[0], dbg_slv, obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
end

if (CutObiMem) begin : g_obi_cut_mem
  obi_m2s_cut #() i_imem_cut (
    .clk_i (clk_i),
    .rst_ni(rst_ni),
    .obi_s (sbr_bus[1]),
    .obi_m (imem_slv)
  );
  obi_m2s_cut #() i_dmem_cut (
    .clk_i (clk_i),
    .rst_ni(rst_ni),
    .obi_s (sbr_bus[2]),
    .obi_m (dmem_slv)
  );
end else begin : g_no_cut_mem
  `OBI_ASSIGN(sbr_bus[1], imem_slv, obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
  `OBI_ASSIGN(sbr_bus[2], dmem_slv, obi_pkg::ObiDefaultConfig, obi_pkg::ObiDefaultConfig)
end


rt_debug #(
  .DmBaseAddr(32'h0)
) i_riscv_dbg (
  .clk_i  (clk_i),
  .rstn_i (rst_ni),
  // DEBUG
  .jtag_tck_i      (jtag_tck_i),   // JTAG test clock pad
  .jtag_tms_i      (jtag_tms_i),   // JTAG test mode select pad
  .jtag_trst_ni    (jtag_trst_ni), // JTAG test reset pad
  .jtag_td_i       (jtag_td_i),    // JTAG test data input pad
  .jtag_td_o       (jtag_td_o),    // JTAG test data output pad
  .ndmreset_o      (ndmreset),
  .debug_req_irq_o (debug_req),
  // dbg_m
  .dbg_m_req_o     (dbg_mst.req),
  .dbg_m_add_o     (dbg_mst.addr),
  .dbg_m_we_o      (dbg_mst.we),
  .dbg_m_wdata_o   (dbg_mst.wdata),
  .dbg_m_be_o      (dbg_mst.be),
  .dbg_m_rdata_i   (dbg_mst.rdata),
  .dbg_m_gnt_i     (dbg_mst.gnt),
  .dbg_m_valid_i   (dbg_mst.rvalid),
  // dbg_s
  .dbg_s_req_i     (dbg_slv.req),
  .dbg_s_gnt_o     (dbg_slv.gnt),
  .dbg_s_we_i      (dbg_slv.we),
  .dbg_s_addr_i    (dbg_slv.addr),
  .dbg_s_wdata_i   (dbg_slv.wdata),
  .dbg_s_be_i      (dbg_slv.be),
  .dbg_s_rdata_o   (dbg_slv.rdata),
  .dbg_s_rvalid_o  (dbg_slv.rvalid)
);

assign ibex_rst_n = rst_ni & ~(ndmreset);


// Tie-off
for (genvar ii=0; ii<NumM; ii++)
  begin : g_mgr_bus_tieoff
    assign mgr_bus[ii].rreadypar = 0;
    assign mgr_bus[ii].reqpar    = 0;
    assign mgr_bus[ii].rready    = 0;
  end

for (genvar ii=0; ii<NumS; ii++)
  begin : g_sbr_bus_tieoff
    assign sbr_bus[ii].rvalidpar = 0;
    assign sbr_bus[ii].gntpar    = 0;
  end

assign axi_m.aw_prot = '0;
assign axi_m.ar_prot = '0;

assign mgr_bus[1].we           = 1'b0;
assign mgr_bus[1].be           = 4'hF;
assign mgr_bus[1].wdata        = 32'b0;

assign mgr_bus[1].aid[0]        = 1'b0;
assign mgr_bus[1].a_optional    = 1'b0;
assign mgr_bus[2].aid[0]        = 1'b0;
assign mgr_bus[2].a_optional    = 1'b0;
//assign mgr_bus[3].aid[0]        = 1'b0;
//assign mgr_bus[3].a_optional    = 1'b0;

assign sbr_bus[3].rid[0]        = 1'b0;
assign sbr_bus[3].err           = 1'b0;
assign sbr_bus[3].r_optional    = 1'b0;

assign dbg_mst.reqpar           = 1'b0;
assign dbg_mst.gntpar           = 1'b0;
assign dbg_mst.aid              = 1'b0;
assign dbg_mst.a_optional       = 1'b0;
assign dbg_mst.rvalidpar        = 1'b0;
assign dbg_mst.rready           = 1'b0;
assign dbg_mst.rreadypar        = 1'b0;

assign dbg_slv.reqpar           = 1'b0;
assign dbg_slv.gntpar           = 1'b0;
assign dbg_slv.rvalidpar        = 1'b0;
assign dbg_slv.rready           = 1'b0;
assign dbg_slv.rreadypar        = 1'b0;
assign dbg_slv.rid              = 1'b0;
assign dbg_slv.err              = 1'b0;
assign dbg_slv.r_optional       = 1'b0;



endmodule : rt_core
