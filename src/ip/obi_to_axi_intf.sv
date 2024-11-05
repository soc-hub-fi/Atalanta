`include "obi/typedef.svh"
`include "obi/assign.svh"
`include "axi/typedef.svh"
`include "axi/assign.svh"

module obi_to_axi_intf #(
  parameter int unsigned AxiIdWidth   = 0,
  parameter int unsigned AxiUserWidth = 0,
  parameter int unsigned AddrWidth    = 32,
  parameter int unsigned DataWidth    = 32,
  parameter int unsigned MaxRequests  = 0
) (
  input logic         clk_i,
  input logic         rst_ni,
  AXI_BUS.Master      axi_out,
  OBI_BUS.Subordinate obi_in
);

`OBI_TYPEDEF_ALL(sbr_port_obi, obi_pkg::ObiDefaultConfig)

sbr_port_obi_req_t sbr_ports_req;
sbr_port_obi_rsp_t sbr_ports_rsp;

`OBI_ASSIGN_TO_REQ(sbr_ports_req, obi_in, obi_pkg::ObiDefaultConfig)
`OBI_ASSIGN_FROM_RSP(obi_in, sbr_ports_rsp, obi_pkg::ObiDefaultConfig)

typedef logic [  AxiIdWidth-1:0] id_t;
typedef logic [   AddrWidth-1:0] addr_t;
typedef logic [   DataWidth-1:0] data_t;
typedef logic [ DataWidth/8-1:0] strb_t;
typedef logic [AxiUserWidth-1:0] user_t;

`AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)
`AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
`AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)
`AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t)
`AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t)
`AXI_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
`AXI_TYPEDEF_RESP_T(axi_resp_t, b_chan_t, r_chan_t)

axi_req_t mst_req;
axi_resp_t mst_resp;

`AXI_ASSIGN_FROM_REQ(axi_out, mst_req)
`AXI_ASSIGN_TO_RESP(mst_resp, axi_out)

obi_to_axi #(
  .obi_req_t   (sbr_port_obi_req_t),
  .obi_rsp_t   (sbr_port_obi_rsp_t),
  .axi_req_t   (axi_req_t),
  .axi_rsp_t   (axi_resp_t),
  .AxiUserWidth(AxiUserWidth),
  .MaxRequests (MaxRequests)
) i_obi_to_axi (
  .clk_i,
  .rst_ni,
  .obi_req_i (sbr_ports_req),
  .obi_rsp_o (sbr_ports_rsp),
  .axi_req_o (mst_req),
  .axi_rsp_i (mst_resp),
  .axi_rsp_channel_sel (),
  .axi_rsp_b_user_o (),
  .axi_rsp_r_user_o (),
  .obi_rsp_user_i   ('0),
  .user_i           ('0)
);

endmodule : obi_to_axi_intf
