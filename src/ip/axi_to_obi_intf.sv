`include "obi/typedef.svh"
`include "obi/assign.svh"
`include "axi/typedef.svh"
`include "axi/assign.svh"

module axi_to_obi_intf #(
  parameter obi_pkg::obi_cfg_t ObiCfg  = obi_pkg::ObiDefaultConfig,
  parameter int unsigned  AxiIdWidth   = 0,
  parameter int unsigned  AxiUserWidth = 0,
  parameter int unsigned  MaxTrans     = 0,
  localparam int unsigned AddrWidth    = 32,
  localparam int unsigned DataWidth    = 32
) (
  input logic     clk_i,
  input logic     rst_ni,
  OBI_BUS.Manager obi_out,
  AXI_BUS.Slave   axi_in
);

`OBI_TYPEDEF_ALL(mgr_port_obi, obi_pkg::ObiDefaultConfig)

mgr_port_obi_req_t mgr_ports_req;
mgr_port_obi_rsp_t mgr_ports_rsp;

`OBI_ASSIGN_FROM_REQ(obi_out, mgr_ports_req, obi_pkg::ObiDefaultConfig)
`OBI_ASSIGN_TO_RSP(mgr_ports_rsp, obi_out, obi_pkg::ObiDefaultConfig)

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

axi_req_t slv_req;
axi_resp_t slv_resp;

`AXI_ASSIGN_TO_REQ(slv_req, axi_in)
`AXI_ASSIGN_FROM_RESP(axi_in, slv_resp)

axi_to_obi #(
  .ObiCfg        (ObiCfg),
  .AxiIdWidth    (AxiIdWidth),
  .AxiUserWidth  (AxiUserWidth),
  .MaxTrans      (MaxTrans),
  .obi_req_t     (mgr_port_obi_req_t),
  .obi_rsp_t     (mgr_port_obi_rsp_t),
  .obi_a_chan_t  (mgr_port_obi_a_chan_t),
  .obi_r_chan_t  (mgr_port_obi_r_chan_t),
  .AxiAddrWidth  (AddrWidth),
  .AxiDataWidth  (DataWidth),
  .axi_req_t     (axi_req_t),
  .axi_rsp_t     (axi_resp_t)
) i_axi_to_obi (
  .clk_i,
  .rst_ni,
  .testmode_i             ('0),
  .axi_req_i              (slv_req),
  .axi_rsp_o              (slv_resp),
  .obi_req_o              (mgr_ports_req),
  .obi_rsp_i              (mgr_ports_rsp),

  .req_aw_id_o            (),
  .req_aw_user_o          (),
  .req_w_user_o           (),
  .req_write_aid_i        ('0),
  .req_write_auser_i      ('0),
  .req_write_wuser_i      ('0),

  .req_ar_id_o            (),
  .req_ar_user_o          (),
  .req_read_aid_i         ('0),
  .req_read_auser_i       ('0),

  .rsp_write_aw_user_o    (),
  .rsp_write_w_user_o     (),
  .rsp_write_bank_strb_o  (),
  .rsp_write_rid_o        (),
  .rsp_write_ruser_o      (),
  .rsp_write_last_o       (),
  .rsp_write_hs_o         (),
  .rsp_b_user_i           ('0),

  .rsp_read_ar_user_o     (),
  .rsp_read_size_enable_o (),
  .rsp_read_rid_o         (),
  .rsp_read_ruser_o       (),
  .rsp_r_user_i           ('0)
);

assign obi_out.reqpar     = '0;
assign obi_out.rready     = '0;
assign obi_out.rreadypar  = '0;

endmodule : axi_to_obi_intf
