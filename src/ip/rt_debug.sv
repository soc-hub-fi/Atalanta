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
--              the DLA subsystem.
********************************************************************************
-- Revisions:
-- Date        Version  Author  Description
-- 2022-11-15  1.0      TZS     Created
-- 2023-11-09  1.1      ANU     Renamed, adapted for RT-SS
*******************************************************************************/

module rt_debug #(
  parameter int AxiAddrWidth  =     32,
  parameter int AxiDataWidth  =     32,
  parameter int DmBaseAddr = 'h0000
) (
  input  logic clk_i,
  input  logic rstn_i,
  // DEBUG
  input  logic jtag_tck_i,    // JTAG test clock pad
  input  logic jtag_tms_i,    // JTAG test mode select pad
  input  logic jtag_trst_ni,  // JTAG test reset pad
  input  logic jtag_td_i,     // JTAG test data input pad
  output logic jtag_td_o,     // JTAG test data output pad
  output logic ndmreset_o,
  output logic debug_req_irq_o,
  // AXI-Lite
  AXI_LITE.Master dbg_axi_lite_m,
  AXI_LITE.Slave  dbg_axi_lite_s
);

/****** LOCAL VARIABLES AND CONSTANTS *****************************************/

localparam int unsigned NrHarts       =  1;
localparam int unsigned DBG_BUS_WIDTH = 32;

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
// dbg_s 
logic                         dbg_s_req_s;
logic                         dbg_s_we_s;
logic [DBG_BUS_WIDTH-1:0]     dbg_s_addr_s;
logic [DBG_BUS_WIDTH-1:0]     dbg_s_wdata_s;
logic [(DBG_BUS_WIDTH/8)-1:0] dbg_s_be_s;
logic [DBG_BUS_WIDTH-1:0]     dbg_s_rdata_s;
// dbg_m
logic                         dbg_m_req_s;
logic [DBG_BUS_WIDTH-1:0]     dbg_m_add_s;
logic                         dbg_m_we_s;
logic [DBG_BUS_WIDTH-1:0]     dbg_m_wdata_s;
logic [DBG_BUS_WIDTH/8-1:0]   dbg_m_be_s;
logic                         dbg_m_gnt_s;
logic                         dbg_m_valid_s;
logic [DBG_BUS_WIDTH-1:0]     dbg_m_rdata_s;

/****** COMPONENT + INTERFACE INSTANTIATIONS **********************************/

  ibex_axi_bridge #(
    .AXI_AW ( AxiAddrWidth ),
    .AXI_DW ( AxiDataWidth ),
    .IBEX_AW( DBG_BUS_WIDTH  ),
    .IBEX_DW( DBG_BUS_WIDTH  )
  ) i_debug2axi_lite_bridge (
    .clk_i      ( clk_i                   ),
    .rst_ni     ( rstn_i                  ),
    .req_i      ( dbg_m_req_s             ),
    .gnt_o      ( dbg_m_gnt_s             ),
    .rvalid_o   ( dbg_m_valid_s           ),
    .we_i       ( dbg_m_we_s              ),
    .be_i       ( dbg_m_be_s              ),
    .addr_i     ( dbg_m_add_s             ),
    .wdata_i    ( dbg_m_wdata_s           ),
    .rdata_o    ( dbg_m_rdata_s           ),
    .err_o      ( /* NC */                ),
    .aw_addr_o  ( dbg_axi_lite_m.aw_addr  ),
    .aw_valid_o ( dbg_axi_lite_m.aw_valid ),
    .aw_ready_i ( dbg_axi_lite_m.aw_ready ),
    .w_data_o   ( dbg_axi_lite_m.w_data   ),
    .w_strb_o   ( dbg_axi_lite_m.w_strb   ),
    .w_valid_o  ( dbg_axi_lite_m.w_valid  ),
    .w_ready_i  ( dbg_axi_lite_m.w_ready  ),
    .b_resp_i   ( dbg_axi_lite_m.b_resp   ),
    .b_valid_i  ( dbg_axi_lite_m.b_valid  ),
    .b_ready_o  ( dbg_axi_lite_m.b_ready  ),
    .ar_addr_o  ( dbg_axi_lite_m.ar_addr  ),
    .ar_valid_o ( dbg_axi_lite_m.ar_valid ),
    .ar_ready_i ( dbg_axi_lite_m.ar_ready ),
    .r_data_i   ( dbg_axi_lite_m.r_data   ),
    .r_resp_i   ( dbg_axi_lite_m.r_resp   ),
    .r_valid_i  ( dbg_axi_lite_m.r_valid  ),
    .r_ready_o  ( dbg_axi_lite_m.r_ready  )
  );

  assign dbg_axi_lite_m.aw_prot = '0;
  assign dbg_axi_lite_m.ar_prot = '0;

  mem_axi_bridge #(
    .MEM_AW    ( DBG_BUS_WIDTH  ),
    .MEM_DW    ( DBG_BUS_WIDTH  ),
    .AXI_AW    ( AxiAddrWidth ),
    .AXI_DW    ( AxiDataWidth ),
    .ADDR_MASK ( 'h0            )
  ) i_axi_lite2debug_bridge (
    .clk_i      ( clk_i                     ),
    .rst_ni     ( rstn_i                    ),
    .req_o      ( dbg_s_req_s               ),
    .we_o       ( dbg_s_we_s                ),
    .addr_o     ( dbg_s_addr_s              ),
    .wdata_o    ( dbg_s_wdata_s             ),
    .be_o       ( dbg_s_be_s                ),
    .rdata_i    ( dbg_s_rdata_s             ),
    .aw_addr_i  ( dbg_axi_lite_s.aw_addr    ),
    .aw_valid_i ( dbg_axi_lite_s.aw_valid   ),
    .aw_ready_o ( dbg_axi_lite_s.aw_ready   ),
    .w_data_i   ( dbg_axi_lite_s.w_data     ),
    .w_strb_i   ( dbg_axi_lite_s.w_strb     ),
    .w_valid_i  ( dbg_axi_lite_s.w_valid    ),
    .w_ready_o  ( dbg_axi_lite_s.w_ready    ),
    .b_resp_o   ( dbg_axi_lite_s.b_resp     ),
    .b_valid_o  ( dbg_axi_lite_s.b_valid    ),
    .b_ready_i  ( dbg_axi_lite_s.b_ready    ),
    .ar_addr_i  ( dbg_axi_lite_s.ar_addr    ),
    .ar_valid_i ( dbg_axi_lite_s.ar_valid   ),
    .ar_ready_o ( dbg_axi_lite_s.ar_ready   ),
    .r_data_o   ( dbg_axi_lite_s.r_data     ),
    .r_resp_o   ( dbg_axi_lite_s.r_resp     ),
    .r_valid_o  ( dbg_axi_lite_s.r_valid    ),
    .r_ready_i  ( dbg_axi_lite_s.r_ready    )
  );


  dmi_jtag #(
    .IdcodeValue ( 32'hFEEDC0D3 )
  ) i_dmi_jtag (
    .clk_i                ( clk_i            ),
    .rst_ni               ( rstn_i           ),
    .testmode_i           ( '0               ),
    .dmi_rst_no           ( /*nc*/           ),
    .dmi_req_valid_o      ( dmi_req_valid_s  ),
    .dmi_req_ready_i      ( dmi_req_ready_s  ),
    .dmi_req_o            ( dmi_req_s        ),
    .dmi_resp_valid_i     ( dmi_resp_valid_s ),
    .dmi_resp_ready_o     ( dmi_resp_ready_s ),
    .dmi_resp_i           ( dmi_resp_s       ),
    .tck_i                ( jtag_tck_i       ),
    .tms_i                ( jtag_tms_i       ),
    .trst_ni              ( jtag_trst_ni     ),
    .td_i                 ( jtag_td_i        ),
    .td_o                 ( jtag_td_o        ),
    .tdo_oe_o             ( /*nc*/           )
  );

  dm_top #(
    .NrHarts         ( NrHarts         ),
    .BusWidth        ( DBG_BUS_WIDTH   ),
    .DmBaseAddress   ( DmBaseAddr ), // TBD
    .SelectableHarts ( {NrHarts{1'b1}} ),          
    .ReadByteEnable  ( 1               ) // toggle new behavior to drive master_be_o during a read    
  ) i_dm_top (
    .clk_i                ( clk_i               ),  
    .rst_ni               ( rstn_i              ),   
    .testmode_i           ( '0                  ),       
    .ndmreset_o           ( ndmreset_o          ),       
    .dmactive_o           ( /*nc*/              ),       
    .debug_req_o          ( debug_req_irq_o     ),        
    .unavailable_i        ( '0                  ),          
    .hartinfo_i           ( DebugHartInfo       ),       
    .slave_req_i          ( dbg_s_req_s         ),        
    .slave_we_i           ( dbg_s_we_s          ),       
    .slave_addr_i         ( dbg_s_addr_s        ),         
    .slave_be_i           ( dbg_s_be_s          ),       
    .slave_wdata_i        ( dbg_s_wdata_s       ),          
    .slave_rdata_o        ( dbg_s_rdata_s       ),          
    .master_req_o         ( dbg_m_req_s         ),         
    .master_add_o         ( dbg_m_add_s         ),         
    .master_we_o          ( dbg_m_we_s          ),        
    .master_wdata_o       ( dbg_m_wdata_s       ),           
    .master_be_o          ( dbg_m_be_s          ),        
    .master_gnt_i         ( dbg_m_gnt_s         ),         
    .master_r_valid_i     ( dbg_m_valid_s       ),             
    .master_r_rdata_i     ( dbg_m_rdata_s       ),             
    .dmi_rst_ni           ( rstn_i              ),       
    .dmi_req_valid_i      ( dmi_req_valid_s     ),            
    .dmi_req_ready_o      ( dmi_req_ready_s     ),            
    .dmi_req_i            ( dmi_req_s           ),      
    .dmi_resp_valid_o     ( dmi_resp_valid_s    ),             
    .dmi_resp_ready_i     ( dmi_resp_ready_s    ),             
    .dmi_resp_o           ( dmi_resp_s          )
    //.master_r_err_i       ( '0                  ),
    //.master_r_other_err_i ( '0                  )      
  );

endmodule