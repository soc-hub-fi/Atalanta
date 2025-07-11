// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Michael Rogenmoser <michaero@iis.ee.ethz.ch>

// Adapted by Antti Nurmi <antti.nurmi@tuni.fi> - add interface wrapper
/*
module obi_cut #(
    /// The OBI configuration.
  parameter obi_pkg::obi_cfg_t ObiCfg       = obi_pkg::ObiDefaultConfig,
  /// The obi A channel struct.
  parameter type               obi_a_chan_t = logic,
  /// The obi R channel struct.
  parameter type               obi_r_chan_t = logic,
  /// The request struct.
  parameter type               obi_req_t    = logic,
  /// The response struct.
  parameter type               obi_rsp_t    = logic,
  /// Bypass enable, can be individually overridden!
  parameter bit                Bypass       = 1'b0,
  /// Bypass enable for Request side.
  parameter bit                BypassReq    = Bypass,
  /// Bypass enable for Response side.
  parameter bit                BypassRsp    = Bypass
) (
  input  logic     clk_i,
  input  logic     rst_ni,

  input  obi_req_t sbr_port_req_i,
  output obi_rsp_t sbr_port_rsp_o,

  output obi_req_t mgr_port_req_o,
  input  obi_rsp_t mgr_port_rsp_i
);

  spill_register #(
    .T      ( obi_a_chan_t ),
    .Bypass ( BypassReq    )
  ) i_reg_a (
    .clk_i,
    .rst_ni,
    .valid_i ( sbr_port_req_i.req ),
    .ready_o ( sbr_port_rsp_o.gnt ),
    .data_i  ( sbr_port_req_i.a   ),
    .valid_o ( mgr_port_req_o.req ),
    .ready_i ( mgr_port_rsp_i.gnt ),
    .data_o  ( mgr_port_req_o.a   )
  );

  logic unused_rready;

  spill_register #(
    .T      ( obi_r_chan_t ),
    .Bypass ( BypassRsp    )
  ) i_req_r (
    .clk_i,
    .rst_ni,
    .valid_i (                    mgr_port_rsp_i.rvalid                 ),
    .ready_o (  unused_rready ),
    .data_i  (                    mgr_port_rsp_i.r                      ),
    .valid_o (                    sbr_port_rsp_o.rvalid                 ),
    .ready_i (  1'b1          ),
    .data_o  (                    sbr_port_rsp_o.r                      )
  );

endmodule
*/
`include "obi/typedef.svh"
`include "obi/assign.svh"

module obi_cut_intf #(
)(
  input logic         clk_i,
  input logic         rst_ni,
  OBI_BUS.Manager     obi_m,
  OBI_BUS.Subordinate obi_s
);

`OBI_TYPEDEF_ALL(sbr_port_obi, obi_pkg::ObiDefaultConfig)
`OBI_TYPEDEF_ALL(mgr_port_obi, obi_pkg::ObiDefaultConfig)

sbr_port_obi_req_t sbr_ports_req;
sbr_port_obi_rsp_t sbr_ports_rsp;
mgr_port_obi_req_t mgr_ports_req;
mgr_port_obi_rsp_t mgr_ports_rsp;

`OBI_ASSIGN_TO_REQ(sbr_ports_req, obi_s, obi_pkg::ObiDefaultConfig)
`OBI_ASSIGN_FROM_RSP(obi_s, sbr_ports_rsp, obi_pkg::ObiDefaultConfig)

`OBI_ASSIGN_FROM_REQ(obi_m, mgr_ports_req, obi_pkg::ObiDefaultConfig)
`OBI_ASSIGN_TO_RSP(mgr_ports_rsp, obi_m, obi_pkg::ObiDefaultConfig)

obi_cut #(
  .obi_a_chan_t (sbr_port_obi_a_chan_t),
  .obi_r_chan_t (sbr_port_obi_r_chan_t),
  .obi_req_t    (sbr_port_obi_req_t),
  .obi_rsp_t    (sbr_port_obi_rsp_t)
) i_obi_cut (
  .clk_i,
  .rst_ni,
  .sbr_port_req_i (sbr_ports_req),
  .sbr_port_rsp_o (sbr_ports_rsp),
  .mgr_port_req_o (mgr_ports_req),
  .mgr_port_rsp_i (mgr_ports_rsp)
);

assign obi_m.reqpar    = 0;
assign obi_m.rready    = 0;
assign obi_m.rreadypar = 0;

assign obi_s.gntpar    = 0;
assign obi_s.rvalidpar = 0;


endmodule
