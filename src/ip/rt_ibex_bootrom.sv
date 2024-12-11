//TODO: get rid of this eventually and replace with a functional, compiled ROM
// inspiration from https://github.com/pulp-platform/pulpissimo/tree/master/sw/bootcode

module rt_ibex_bootrom #()(
    input         logic clk_i,
    input         logic rst_ni,
    OBI_BUS.Subordinate sbr_bus
  );

  localparam int unsigned RomSize = 2;
  localparam int unsigned RomAddrWidth = $clog2(RomSize);

  localparam logic [31:0] BootRom [RomSize] = {
    32'h0000_006F,
    32'h0000_006F
  };

  logic [RomAddrWidth-1:0] RomAddr;

  obi_handshake_fsm i_fsm (
    .clk_i,
    .rst_ni,
    .req_i    (sbr_bus.req),
    .gnt_o    (sbr_bus.gnt),
    .rvalid_o (sbr_bus.rvalid)
  );

  always_ff @(posedge clk_i or negedge rst_ni)
    begin
      if (~rst_ni)
        RomAddr <= '0;
      else
        RomAddr <= sbr_bus.addr[RomAddrWidth-1:0];
    end


  assign sbr_bus.rdata = BootRom[RomAddr];

  assign sbr_bus.gntpar    = 0;
  assign sbr_bus.rvalidpar = 0;

  endmodule : rt_ibex_bootrom
