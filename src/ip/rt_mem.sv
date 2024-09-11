module rt_mem #(
  parameter int unsigned AddrWidth  =  32,
  parameter int unsigned DataWidth  =  32,
  parameter int unsigned MemSize    =  1024,
  parameter int unsigned BaseOffset = 'h1000,

  // Derived, do not overwrite
  localparam int unsigned StrbWidth = (DataWidth/8),
  localparam int unsigned MemWords  = (MemSize/4)
)(
  input  logic                 clk_i,
  input  logic                 rst_ni,
  // CPU side
  input  logic                 req_i,
  output logic                 gnt_o,
  output logic                 rvalid_o,
  input  logic                 we_i,
  input  logic [StrbWidth-1:0] be_i,
  input  logic [AddrWidth-1:0] addr_i,
  input  logic [DataWidth-1:0] wdata_i,
  output logic [DataWidth-1:0] rdata_o
);

localparam int unsigned RamAddrLen = $clog2(MemWords);

logic [ RamAddrLen   -1:0] sram_addr;
logic [(RamAddrLen+2)-1:0] uncut_addr;

assign uncut_addr = addr_i - BaseOffset;
assign sram_addr  = uncut_addr[(RamAddrLen+2)-1:2];

rt_handshake_fsm #(
) i_fsm (
  .clk_i        (clk_i),
  .rst_ni       (rst_ni),
  .cpu_req_i    (req_i),
  .cpu_gnt_o    (gnt_o),
  .cpu_rvalid_o (rvalid_o)
);

sram #(
  .DATA_WIDTH (DataWidth),
  .NUM_WORDS  (MemWords)
) i_mem (
  .clk_i   (clk_i ),
  .rst_ni  (rst_ni),
  .req_i   (req_i),
  .we_i    (we_i),
  .addr_i  (sram_addr),
  .wdata_i (wdata_i),
  .be_i    (be_i),
  .rdata_o (rdata_o)
);

endmodule

