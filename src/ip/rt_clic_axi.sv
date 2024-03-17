`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"
`include "axi/typedef.svh"
`include "axi/assign.svh"

module rt_clic_axi #(
  parameter int unsigned AxiAddrWidth = 32,
  parameter int unsigned AxiDataWidth = 32,
  parameter int          NSource       = 256,
  parameter int          IntCtlBits     = 8,
  localparam int SRC_W = $clog2(NSource)
)(
  input  logic             clk_i,
  input  logic             rst_ni,
  AXI_LITE.Slave           axi_s,
  // Interrupt Sources
  input [NSource-1:0]     intr_src_i,
  // Interrupt notification to core
  output logic             irq_valid_o,
  input  logic             irq_ready_i,
  output logic [SRC_W-1:0] irq_id_o,
  output logic [7:0]       irq_level_o,
  output logic             irq_shv_o,
  output logic [1:0]       irq_priv_o,
  output logic             irq_kill_req_o,
  input  logic             irq_kill_ack_i
);


// Boilerplate for protocol conversion
typedef logic [AxiAddrWidth-1:0] addr_t;
typedef logic [AxiDataWidth-1:0] data_t;
typedef logic [AxiDataWidth/8-1:0] strb_t;

`REG_BUS_TYPEDEF_REQ(reg_req_t, addr_t, data_t, strb_t)
`REG_BUS_TYPEDEF_RSP(reg_rsp_t, data_t)

`AXI_LITE_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t)
`AXI_LITE_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t)
`AXI_LITE_TYPEDEF_B_CHAN_T(b_chan_t)
`AXI_LITE_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t)
`AXI_LITE_TYPEDEF_R_CHAN_T(r_chan_t, data_t)
`AXI_LITE_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
`AXI_LITE_TYPEDEF_RESP_T(axi_resp_t, b_chan_t, r_chan_t)

axi_req_t  axi_req;
axi_resp_t axi_resp;
reg_req_t reg_req;
reg_rsp_t reg_rsp;

`AXI_LITE_ASSIGN_TO_REQ(axi_req, axi_s)
`AXI_LITE_ASSIGN_FROM_RESP(axi_s, axi_resp)

axi_lite_to_reg #(
  .ADDR_WIDTH       ( AxiAddrWidth ),
  .DATA_WIDTH       ( AxiDataWidth ),
  .axi_lite_req_t   ( axi_req_t      ),
  .axi_lite_rsp_t   ( axi_resp_t     ),
  .reg_req_t        ( reg_req_t      ),
  .reg_rsp_t        ( reg_rsp_t      )
) i_axi_to_reg (
  .clk_i          ( clk_i   ),
  .rst_ni         ( rst_ni  ),
  .axi_lite_req_i ( axi_req ),
  .axi_lite_rsp_o ( axi_resp),
  .reg_req_o      ( reg_req ),
  .reg_rsp_i      ( reg_rsp )
);

clic #(
  .N_SOURCE  ( NSource          ),
  .INTCTLBITS( IntCtlBits        ),
  .reg_req_t ( reg_req_t ),
  .reg_rsp_t ( reg_rsp_t )
) i_clic_core (
  .clk_i          ( clk_i          ),
  .rst_ni         ( rst_ni         ),
  .reg_req_i      ( reg_req        ),
  .reg_rsp_o      ( reg_rsp        ),
  .intr_src_i     ( intr_src_i     ),
  .irq_valid_o    ( irq_valid_o    ),
  .irq_ready_i    ( irq_ready_i    ),
  .irq_id_o       ( irq_id_o       ),
  .irq_level_o    ( irq_level_o    ),
  .irq_shv_o      ( irq_shv_o      ),
  .irq_priv_o     ( irq_priv_o     ),
  .irq_kill_req_o ( irq_kill_req_o ),
  .irq_kill_ack_i ( irq_kill_ack_i )
);

endmodule : rt_clic_axi
