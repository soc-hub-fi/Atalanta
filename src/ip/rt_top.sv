/*
  RT-SS top level module
  authors: Antti Nurmi <antti.nurmi@tuni.fi>
*/

`include "axi/assign.svh"
`define COMMON_CELLS_ASSERTS_OFF

module rt_top #(
  parameter int unsigned AxiAddrWidth = 32,
  parameter int unsigned AxiDataWidth = 32,
  parameter int unsigned ClicIrqSrcs  = 64,
  parameter bit          IbexRve      = 1,
  // Derived parameters
  localparam int SrcW                 = $clog2(ClicIrqSrcs),
  localparam int unsigned StrbWidth   = (AxiDataWidth / 8)

)(
  input  logic               clk_i,
  input  logic               rst_ni,
  input  logic [3:0]         gpio_input_i,
  output logic [3:0]         gpio_output_o,
  input  logic               uart_rx_i,
  output logic               uart_tx_o,
`ifndef STANDALONE
  AXI_LITE.Slave             soc_slv,
  AXI_LITE.Master            soc_mst,
`endif
  input  logic                   jtag_tck_i,
  input  logic                   jtag_tms_i,
  input  logic                   jtag_trst_ni,
  input  logic                   jtag_td_i,
  output logic                   jtag_td_o,
  input  logic [ClicIrqSrcs-1:0] intr_src_i
);

`ifndef STANDALONE
  localparam int CONNECTIVITY = 1;
`else
  localparam int CONNECTIVITY = 0;
`endif

localparam int unsigned NrMst = 1 + CONNECTIVITY;
localparam int unsigned NrSlv = 1 + ( 2*CONNECTIVITY) ;

localparam int unsigned DbgBase   = 32'h0000_0000;
localparam int unsigned PeripBase = 32'h0003_0000;
localparam int unsigned DbgSize   = 'h3000;
localparam int unsigned PeripSize = 'h800;
localparam int unsigned IrqSize   = 'h1000+(4*ClicIrqSrcs);

localparam axi_pkg::xbar_cfg_t XbarCfg = {
  32'(NrMst),          //NoSlvPorts:
  32'(NrSlv),          //NoMstPorts:
  32'd3,                //MaxMstTrans:
  32'd3,                //MaxSlvTrans:
  1'b0,                 //FallThrough:
  axi_pkg::CUT_SLV_PORTS,  //LatencyMode:
  //'d0,                //PipelineStages:
  32'd9,                //AxiIdWidthSlvPorts:
  32'd0,                //AxiIdUsedSlvPorts:
  1'b0,                 //UniqueIds:
  32'(AxiDataWidth),  //AxiDataWidth:
  32'(AxiAddrWidth),  //AxiAddrWidth:
  32'(NrSlv)           //NoAddrRules:
};

localparam axi_pkg::xbar_rule_32_t [XbarCfg.NoAddrRules-1:0] AddrMap = '{
`ifndef STANDALONE
  '{idx: 32'd2, start_addr: 32'h0006_0000, end_addr: 32'hFFFF_FFFF},
  '{idx: 32'd1, start_addr: DbgBase,       end_addr: PeripBase},
`endif
  '{idx: 32'd0, start_addr: PeripBase, end_addr: 32'h0006_0000}
};

typedef struct packed {
  int unsigned             idx;
  logic [AxiAddrWidth-1:0] start_addr;
  logic [AxiDataWidth-1:0] end_addr;
} apb_rule_t;

localparam apb_rule_t PeripMap = '{ idx:        32'h0,
                                    start_addr: PeripBase,
                                    end_addr:   32'h0006_0000
                                  };

AXI_LITE #(
  .AXI_ADDR_WIDTH (AxiAddrWidth),
  .AXI_DATA_WIDTH (AxiDataWidth)
) master [NrMst-1:0] (), slave [NrSlv-1:0] ();

APB #(
  .ADDR_WIDTH (AxiAddrWidth),
  .DATA_WIDTH (AxiDataWidth)
) apb_bus ();

logic [AxiAddrWidth-1:0] paddr;
logic              [2:0] pprot;
logic                    pselx;
logic                    penable;
logic                    pwrite;
logic [AxiDataWidth-1:0] pwdata;
logic    [StrbWidth-1:0] pstrb;
logic                    pready;
logic [AxiDataWidth-1:0] prdata;
logic                    pslverr;

logic                    irq_valid;
logic                    irq_ready;
logic         [SrcW-1:0] irq_id;
logic              [7:0] irq_level;
logic                    irq_shv;
logic              [1:0] irq_priv;

`ifndef STANDALONE
  `AXI_LITE_ASSIGN( master[1], soc_slv )
  `AXI_LITE_ASSIGN( soc_mst, slave[2]  )
`endif

axi_lite_xbar_intf #(
  .Cfg    (XbarCfg),
  .rule_t (axi_pkg::xbar_rule_32_t)
) i_xbar (
  .clk_i                  (clk_i),
  .rst_ni                 (rst_ni),
  .test_i                 (1'b0),
  .slv_ports              (master),
  .mst_ports              (slave),
  .addr_map_i             (AddrMap),
  .en_default_mst_port_i  ('0),
  .default_mst_port_i     ('0)
);

axi_lite_to_apb_intf #(
  .NoApbSlaves      (32'd1),     // Number of connected APB slaves
  .NoRules          (32'd1),     // Number of APB address rules
  .AddrWidth        (32'd32),    // Address width
  .DataWidth        (32'd32),    // Data width
  .PipelineRequest  (1'b0),      // Pipeline request path
  .PipelineResponse (1'b0),      // Pipeline response path
  .rule_t           (apb_rule_t) // Address Decoder rule from `common_cells`
) i_axi_to_apb (
  .clk_i      (clk_i),
  .rst_ni     (rst_ni),
  .slv        (slave[0]),
  .paddr_o    (paddr),
  .pprot_o    (pprot),
  .pselx_o    (pselx),
  .penable_o  (penable),
  .pwrite_o   (pwrite),
  .pwdata_o   (pwdata),
  .pstrb_o    (pstrb),
  .pready_i   (pready),
  .prdata_i   (prdata),
  .pslverr_i  (pslverr),
  .addr_map_i (PeripMap)
);

rt_core #(
  .RVE (IbexRve)
) i_core_subsystem (
  .clk_i        (clk_i),
  .rst_ni       (rst_ni),
  .jtag_tck_i   (jtag_tck_i),
  .jtag_tms_i   (jtag_tms_i),
  .jtag_trst_ni (jtag_trst_ni),
  .jtag_td_i    (jtag_td_i),
  .jtag_td_o    (jtag_td_o),
  .irq_valid_i  (irq_valid),
  .irq_ready_o  (irq_ready),
  .irq_id_i     (irq_id),
  .irq_level_i  (irq_level),
  .irq_shv_i    (irq_shv),
  .irq_priv_i   (irq_priv),
`ifndef STANDALONE
  .axi_s        (slave[1]),
`endif
  .axi_m        (master[0])
);

rt_peripherals #(
  .NSource (ClicIrqSrcs),
  .rule_t  (apb_rule_t)  // Address Decoder rule from `common_cells`
) i_peripheral_subsystem (
  .clk_i          (clk_i),
  .rst_ni         (rst_ni),
  .apb_i          (apb_bus),
  .gpio_output_o  (gpio_output_o),
  .gpio_input_i   (gpio_input_i),
  .intr_src_i     (intr_src_i), // 0-15 -> CLINT IRQS are here
  .irq_valid_o    (irq_valid),
  .irq_ready_i    (irq_ready),
  .irq_id_o       (irq_id),
  .irq_level_o    (irq_level),
  .irq_shv_o      (irq_shv),
  .irq_priv_o     (irq_priv),
  .irq_kill_ack_i (1'b0),
  .irq_kill_req_o (),
  .uart_rx_i      (uart_rx_i),
  .uart_tx_o      (uart_tx_o)
);

assign apb_bus.paddr   = paddr;
assign apb_bus.pprot   = pprot;
assign apb_bus.psel    = pselx;
assign apb_bus.penable = penable;
assign apb_bus.pwrite  = pwrite;
assign apb_bus.pwdata  = pwdata;
assign apb_bus.pstrb   = pstrb;
assign pready          = apb_bus.pready;
assign prdata          = apb_bus.prdata;
assign pslverr         = apb_bus.pslverr;

endmodule : rt_top
