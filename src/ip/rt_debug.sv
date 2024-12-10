/*******************************************************************************
-- Title      : Wrapper for RT-SS Debug Components 
-- Project    : SoCHub - Bow
********************************************************************************
-- File       : rt_debug.sv
-- Author(s)  : Tom Szymkowiak, Antti Nurmi
-- Company    : TUNI
-- Created    : 2022-11-15
-- Design     : dla_debug
-- Platform   : -
-- Standard   : SystemVerilog '17
********************************************************************************
-- Description: Structural wrapper to contain all debug components used within
--              the RT subsystem.
********************************************************************************
-- Revisions:
-- Date        Version  Author  Description
-- 2022-11-15  1.0      TZS     Created
-- 2023-11-09  1.1      ANU     Renamed, adapted for RT-SS
-- 2024-04-15  1.2      ANU     Changed AXI interfaces to generic OBI compatible
*******************************************************************************/

module rt_debug #(
  parameter int DmBaseAddr = 'h0000,
  localparam int unsigned DbgBusWidth = 32

) (
  input  logic clk_i,
  input  logic rst_ni,
  // DEBUG
  input  logic jtag_tck_i,    // JTAG test clock pad
  input  logic jtag_tms_i,    // JTAG test mode select pad
  input  logic jtag_trst_ni,  // JTAG test reset pad
  input  logic jtag_td_i,     // JTAG test data input pad
  output logic jtag_td_o,     // JTAG test data output pad
  output logic ndmreset_o,
  output logic debug_req_irq_o,
  // dbg_m
  OBI_BUS.Manager dbg_mst,
  //output logic                       dbg_m_req_o,
  //output logic     [DbgBusWidth-1:0] dbg_m_add_o,
  //output logic                       dbg_m_we_o,
  //output logic     [DbgBusWidth-1:0] dbg_m_wdata_o,
  //output logic [(DbgBusWidth/8)-1:0] dbg_m_be_o,
  //input  logic     [DbgBusWidth-1:0] dbg_m_rdata_i,
  //input  logic                       dbg_m_gnt_i,
  //input  logic                       dbg_m_valid_i,
  // dbg_s
  OBI_BUS.Subordinate dbg_slv
  //input  logic                       dbg_s_req_i,
  //output logic                       dbg_s_gnt_o,
  //output logic                       dbg_s_rvalid_o,
  //input  logic                       dbg_s_we_i,
  //input  logic     [DbgBusWidth-1:0] dbg_s_addr_i,
  //input  logic     [DbgBusWidth-1:0] dbg_s_wdata_i,
  //input  logic [(DbgBusWidth/8)-1:0] dbg_s_be_i,
  //output logic     [DbgBusWidth-1:0] dbg_s_rdata_o
);

/****** LOCAL VARIABLES AND CONSTANTS *****************************************/

localparam int unsigned NrHarts     =  1;

// static debug hartinfo
localparam dm::hartinfo_t DebugHartInfo = '{
  zero1:                 '0,
  nscratch:               2, // Debug module needs at least two scratch regs
  zero0:                 '0,
  dataaccess:          1'b1, // data registers are memory mapped in the debugger
  datasize:   dm::DataCount,
  dataaddr:   dm::DataAddr
};

// JTAG TAP <-> DMI signals
dm::dmi_req_t                 dmi_req_s;
dm::dmi_resp_t                dmi_resp_s;
logic                         dmi_req_valid_s;
logic                         dmi_req_ready_s;
logic                         dmi_resp_valid_s;
logic                         dmi_resp_ready_s;

obi_handshake_fsm #(
) i_handshake_ctrl (
  .clk_i,
  .rst_ni,
  .req_i    (dbg_slv.req),
  .gnt_o    (dbg_slv.gnt),
  .rvalid_o (dbg_slv.rvalid)
);


/****** COMPONENT + INTERFACE INSTANTIATIONS **********************************/

  dmi_jtag #(
    .IdcodeValue ( 32'hFEEDC0D3 )
  ) i_dmi_jtag (
    .clk_i            (clk_i           ),
    .rst_ni           (rst_ni          ),
    .testmode_i       ('0              ),
    .dmi_rst_no       (/*nc*/          ),
    .dmi_req_valid_o  (dmi_req_valid_s ),
    .dmi_req_ready_i  (dmi_req_ready_s ),
    .dmi_req_o        (dmi_req_s       ),
    .dmi_resp_valid_i (dmi_resp_valid_s),
    .dmi_resp_ready_o (dmi_resp_ready_s),
    .dmi_resp_i       (dmi_resp_s      ),
    .tck_i            (jtag_tck_i      ),
    .tms_i            (jtag_tms_i      ),
    .trst_ni          (jtag_trst_ni    ),
    .td_i             (jtag_td_i       ),
    .td_o             (jtag_td_o       ),
    .tdo_oe_o         (/*nc*/          )
  );

  dm_top #(
    .NrHarts         ( NrHarts         ),
    .BusWidth        ( DbgBusWidth   ),
    .DmBaseAddress   ( DmBaseAddr ), // TBD
    .SelectableHarts ( {NrHarts{1'b1}} ),
    .ReadByteEnable  ( 1               ) // toggle new behavior to drive master_be_o during a read
  ) i_dm_top (
    .clk_i                (clk_i           ),
    .rst_ni               (rst_ni          ),
    .testmode_i           ('0              ),
    .ndmreset_o           (ndmreset_o      ),
    .dmactive_o           (/*nc*/          ),
    .debug_req_o          (debug_req_irq_o ),
    .unavailable_i        ('0              ),
    .hartinfo_i           (DebugHartInfo   ),
    .slave_req_i          (dbg_slv.req     ),
    .slave_we_i           (dbg_slv.we      ),
    .slave_addr_i         (dbg_slv.addr    ),
    .slave_be_i           (dbg_slv.be      ),
    .slave_wdata_i        (dbg_slv.wdata   ),
    .slave_rdata_o        (dbg_slv.rdata   ),
    .master_req_o         (dbg_mst.req     ),
    .master_add_o         (dbg_mst.addr    ),
    .master_we_o          (dbg_mst.we      ),
    .master_wdata_o       (dbg_mst.wdata   ),
    .master_be_o          (dbg_mst.be      ),
    .master_gnt_i         (dbg_mst.gnt     ),
    .master_r_valid_i     (dbg_mst.rvalid  ),
    .master_r_rdata_i     (dbg_mst.rdata   ),
    .dmi_rst_ni           (rst_ni          ),
    .dmi_req_valid_i      (dmi_req_valid_s ),
    .dmi_req_ready_o      (dmi_req_ready_s ),
    .dmi_req_i            (dmi_req_s       ),
    .dmi_resp_valid_o     (dmi_resp_valid_s),
    .dmi_resp_ready_i     (dmi_resp_ready_s),
    .dmi_resp_o           (dmi_resp_s      ),
    .master_r_other_err_i ('0),
    .master_r_err_i       ('0)
  );

// Mst/mgr tie-offs
assign dbg_mst.reqpar     = 0;
assign dbg_mst.aid        = 0;
assign dbg_mst.a_optional = 0;
assign dbg_mst.rready     = 0;
assign dbg_mst.rreadypar  = 0;


// Slv/sbr tie-offs
assign dbg_slv.gntpar     = 0;
assign dbg_slv.rvalidpar  = 0;
assign dbg_slv.rready     = 0;
assign dbg_slv.rreadypar  = 0;
assign dbg_slv.rid        = 0;
assign dbg_slv.err        = 0;
assign dbg_slv.r_optional = 0;

endmodule
