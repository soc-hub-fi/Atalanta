module obi_sram_intf #(
  parameter int unsigned  NumWords  = 1024,
  parameter int unsigned  BaseAddr  = 0,
  parameter int unsigned  DataWidth = 32,
  parameter int unsigned  Latency   = 1,
  localparam int unsigned AddrWidth = $clog2(NumWords)
)(
  input  logic        clk_i,
  input  logic        rst_ni,
  OBI_BUS.Subordinate sbr_bus
);

logic [31:0] offset_addr;
logic [29:0] word_addr;
logic [AddrWidth-1:0] sram_addr;

assign offset_addr = sbr_bus.addr - BaseAddr;
assign word_addr   = offset_addr[31:2];
assign sram_addr   = word_addr[AddrWidth-1:0];

obi_handshake_fsm i_fsm (
  .clk_i,
  .rst_ni,
  .req_i    (sbr_bus.req),
  .gnt_o    (sbr_bus.gnt),
  .rvalid_o (sbr_bus.rvalid)
);

`ifdef FPGA_MEM
  //$fatal("FPGA memories not yet supported, exiting");
logic [3:0] bw_ena;

assign bw_ena = (sbr_bus.we) ? (4'b1111 & sbr_bus.be) : 4'b0;

xilinx_sp_BRAM #(
  .RAM_DEPTH (NumWords)
) i_sram (
  .clk_i    (clk_i),
  .rst_ni   (rst_ni),
  .req_i    (sbr_bus.req),
  .bwe_i    (bw_ena),
  .addr_i   (sram_addr),
  .wdata_i  (sbr_bus.wdata),
  .rdata_o  (sbr_bus.rdata)
);

`else
  `ifdef SYNTHESIS
rt_ss_tech_mem #(
  .DATA_WIDTH (DataWidth),
  .NUM_WORDS  (NumWords)
) i_tech_sram (
  .clk_i   (clk_i),
  .req_i   (sbr_bus.req),
  .we_i    (sbr_bus.we),
  .addr_i  (sram_addr),
  .wdata_i (sbr_bus.wdata),
  .be_i    (sbr_bus.be),
  .rdata_o (sbr_bus.rdata)
);

  `else
tc_sram #(
  .NumWords  (NumWords),
  .DataWidth (DataWidth),
  .SimInit   ("random"),
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
`endif

endmodule : obi_sram_intf
