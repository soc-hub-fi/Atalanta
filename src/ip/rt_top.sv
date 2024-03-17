/*
  RT-SS top level module
  authors: Antti Nurmi <antti.nurmi@tuni.fi>
*/

`include "axi/assign.svh"
`define COMMON_CELLS_ASSERTS_OFF

module rt_top #(
  parameter int unsigned AxiAddrWidth   = 32,
  parameter int unsigned AxiDataWidth   = 32,
  parameter int unsigned ClicIrqSrcs    = 64,
  parameter bit          IbexRve        = 1,
  localparam int SrcW = $clog2(ClicIrqSrcs)

)(
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic [3:0]         gpio_input_i,
  output logic [3:0]         gpio_output_o,
  input  logic               uart_rx_i,
  output logic               uart_tx_o,
`ifdef SOC_CONNECTIVITY
  AXI_LITE.Slave             soc_slv,
  AXI_LITE.Master            soc_mst,
`endif
  input  logic               jtag_tck_i,
  input  logic               jtag_tms_i,
  input  logic               jtag_trst_ni,
  input  logic               jtag_td_i,
  output logic               jtag_td_o,
  input [ClicIrqSrcs-1:16] intr_src_i
);

`ifdef SOC_CONNECTIVITY
  localparam int CONNECTIVITY = 1;
`else
  localparam int CONNECTIVITY = 0;
`endif

localparam int unsigned NrMst = 3 + CONNECTIVITY;
localparam int unsigned NrSlv = 4 + CONNECTIVITY;

localparam int unsigned DbgBase   = 32'h0000_0100;
localparam int unsigned ImemBase  = 32'h0000_1000;
localparam int unsigned DmemBase  = 32'h0000_2000;
localparam int unsigned PeripBase = 32'h0003_0000;
localparam int unsigned IrqBase   = 32'h0005_0000;
localparam int unsigned MemSize   = 'h1000;
localparam int unsigned DbgSize   = 'h800;
localparam int unsigned PeripSize = 'h800;
localparam int unsigned IrqSize   = 'h1000+(4*ClicIrqSrcs);

localparam axi_pkg::xbar_cfg_t xbar_cfg = {
  32'(NrMst),          //NoSlvPorts:
  32'(NrSlv),          //NoMstPorts:
  32'd4,                //MaxMstTrans:
  32'd4,                //MaxSlvTrans:
  1'b0,                 //FallThrough:
  axi_pkg::CUT_ALL_AX,  //LatencyMode:
  //'d0,                //PipelineStages:
  32'd0,                //AxiIdWidthSlvPorts:
  32'd0,                //AxiIdUsedSlvPorts:
  1'b0,                 //UniqueIds:
  32'(AxiDataWidth),  //AxiDataWidth:
  32'(AxiAddrWidth),  //AxiAddrWidth:
  32'(NrSlv)           //NoAddrRules:
};

localparam axi_pkg::xbar_rule_32_t [xbar_cfg.NoAddrRules-1:0] AddrMap = '{
`ifdef SOC_CONNECTIVITY
  '{idx: 32'd5, start_addr: 32'h0006_0000, end_addr: 32'h0006_1000},
`endif
  '{idx: 32'd3, start_addr: IrqBase,   end_addr: IrqBase+IrqSize},
  '{idx: 32'd2, start_addr: PeripBase, end_addr: PeripBase+PeripSize},
  //'{idx: 32'd2, start_addr: LPMEM_BASE, end_addr: LPMEM_BASE+MemSize},
  '{idx: 32'd1, start_addr: ImemBase,  end_addr: ImemBase+(2*MemSize)},
  '{idx: 32'd0, start_addr: DbgBase,   end_addr: DbgBase+DbgSize}
};

AXI_LITE #(
  .AXI_ADDR_WIDTH ( AxiAddrWidth ),
  .AXI_DATA_WIDTH ( AxiDataWidth )
) master [NrMst-1:0] ();

AXI_LITE #(
  .AXI_ADDR_WIDTH ( AxiAddrWidth ),
  .AXI_DATA_WIDTH ( AxiDataWidth )
) slave [NrSlv-1:0] ();

// SIGNALS
//////////
logic ndmreset;
logic ibex_rst_n;
logic debug_req;
logic fetch_enable;
logic reg_reset;
logic mtimer_irq;
logic [23:0] boot_addr;

logic [ClicIrqSrcs-1:0] intr_src;
// TODO: connect machine sw irq and machine ext irq
assign intr_src = {intr_src_i, 12'b0, mtimer_irq, 7'b0};

logic irq_valid;
logic irq_ready;
logic [SrcW-1:0] irq_id;
logic [      7:0] irq_level;
logic irq_shv;
logic [      1:0] irq_priv;

`ifdef SOC_CONNECTIVITY
  `AXI_LITE_ASSIGN( master[3], soc_slv )
  `AXI_LITE_ASSIGN( soc_mst, slave[4]  )
`endif

// MODULE INSTANCES
///////////////////


axi_lite_xbar_intf #(
  .Cfg    ( xbar_cfg               ),
  .rule_t ( axi_pkg::xbar_rule_32_t)
) i_xbar (
  .clk_i                  ( clk_i     ),
  .rst_ni                 ( rst_ni    ),
  .test_i                 ( 1'b0      ),
  .slv_ports              ( master    ),
  .mst_ports              ( slave     ),
  .addr_map_i             ( AddrMap   ),
  .en_default_mst_port_i  ( 3'b0      ),
  .default_mst_port_i     ( 6'b0      )
);

rt_cpu #(
  .AxiAddrWidth   ( AxiAddrWidth ),
  .AxiDataWidth   ( AxiDataWidth ),
  .MemSize        ( MemSize      ),
  .IbexRve        ( IbexRve      ),
  .NumInterrupts ( ClicIrqSrcs  )
) i_cpu (
  .clk_i          ( clk_i         ),
  .rst_ni         ( ibex_rst_n    ),
  .hart_id_i      ( '0            ),
  .boot_addr_i    ({boot_addr,8'h00}),
  .debug_req_i    ( debug_req     ),
  .fetch_enable_i ( fetch_enable  ),
  .axi_mem_slv    ( slave[1]      ),
  .axi_dmem_m     ( master[1]     ),
  .axi_imem_m     ( master[2]     ),
  .irq_valid_i    ( irq_valid     ),
  .irq_ready_o    ( irq_ready     ),
  .irq_id_i       ( irq_id        ),
  .irq_level_i    ( irq_level     ),
  .irq_shv_i      ( irq_shv       ),
  .irq_priv_i     ( irq_priv      )
);

rt_irq #(
  .AxiAddrWidth ( AxiAddrWidth ),
  .AxiDataWidth ( AxiDataWidth ),
  .NSource       ( ClicIrqSrcs  ),
  .IntCtlBits     ( 8 /*default*/  )
) i_irq (
  .clk_i          ( clk_i          ),
  .rst_ni         ( rst_ni         ),
  .axi_s          ( slave[3]       ),
  .intr_src_i     ( intr_src       ), // 0-15 -> CLINT IRQS are here
  .irq_valid_o    ( irq_valid      ),
  .irq_ready_i    ( irq_ready      ),
  .irq_id_o       ( irq_id         ),
  .irq_level_o    ( irq_level      ),
  .irq_shv_o      ( irq_shv        ),
  .irq_priv_o     ( irq_priv       ),
  .irq_kill_req_o ( /*NC*/         ),
  .irq_kill_ack_i ( '0             )
);

rt_peripherals #() i_peripherals (
  .clk_i          ( clk_i         ),
  .rst_ni         ( rst_ni        ),
  .gpio_output_o  ( gpio_output_o ),
  .gpio_input_i   ( gpio_input_i  ),
  .fetch_enable_o ( fetch_enable  ),
  .cpu_rst_o      ( reg_reset     ),
  .cpu_boot_addr_o( boot_addr     ),
  .uart_rx_i      ( uart_rx_i     ),
  .uart_tx_o      ( uart_tx_o     ),
  .uart_intr_o    (),
  .mtimer_irq_o   ( mtimer_irq    ),
  .axi_lite_slv   ( slave[2]      )
);

rt_debug #(
  .AxiAddrWidth  ( AxiAddrWidth ),
  .AxiDataWidth  ( AxiDataWidth ),
  .DmBaseAddr    ( DbgBase      )
) i_dbg (
  .clk_i           ( clk_i            ),
  .rstn_i          ( rst_ni           ),
  .jtag_tck_i      ( jtag_tck_i       ),
  .jtag_tms_i      ( jtag_tms_i       ),
  .jtag_trst_ni    ( jtag_trst_ni     ),
  .jtag_td_i       ( jtag_td_i        ),
  .jtag_td_o       ( jtag_td_o        ),
  .ndmreset_o      ( ndmreset         ),
  .debug_req_irq_o ( debug_req        ),
  .dbg_axi_lite_m  ( master[0]        ),
  .dbg_axi_lite_s  ( slave[0]         )
);

// ASSIGNMENTS
//////////////
assign ibex_rst_n = rst_ni & ~(ndmreset) & (reg_reset);

endmodule : rt_top
