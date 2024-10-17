module obi_sram_intf #(
  parameter int unsigned  NumWords  = 1024,
  parameter int unsigned  DataWidth = 32,
  parameter int unsigned  Latency   = 1,
  localparam int unsigned AddrWidth = $clog2(NumWords)
)(
  input  logic        clk_i,
  input  logic        rst_ni,
  OBI_BUS.Subordinate sbr_bus
);

logic [29:0] word_addr;
logic [AddrWidth-1:0] sram_addr;

assign word_addr = sbr_bus.addr[31:2];
assign sram_addr = word_addr[AddrWidth-1:0];

obi_handshake_fsm i_fsm (
  .clk_i,
  .rst_ni,
  .req_i    (sbr_bus.req),
  .gnt_o    (sbr_bus.gnt),
  .rvalid_o (sbr_bus.rvalid)
);

`ifdef FPGA
  $fatal("FPGA memories not yet supported, exiting");
`else

tc_sram #(
  .NumWords  (NumWords),
  .DataWidth (DataWidth),
  .NumPorts  (1),
  .Latency   (Latency)
) i_sram (
  .clk_i,
  .rst_ni,
  .req_i   (sbr_bus.req),
  .we_i    (sbr_bus.we),
  .be_i    (sbr_bus.be),
  .addr_i  (sram_addr),
  .wdata_i (sbr_bus.wdata),
  .rdata_o (sbr_bus.rdata)
);
`endif

endmodule : obi_sram_intf
