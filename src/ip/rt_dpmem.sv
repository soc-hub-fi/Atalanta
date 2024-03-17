module rt_dpmem #(
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
  input  logic                 cpu_req_i,
  output logic                 cpu_gnt_o,
  output logic                 cpu_rvalid_o,
  input  logic                 cpu_we_i,
  input  logic [StrbWidth-1:0] cpu_be_i,
  input  logic [AddrWidth-1:0] cpu_addr_i,
  input  logic [DataWidth-1:0] cpu_wdata_i,
  output logic [DataWidth-1:0] cpu_rdata_o,
  // AXI side
  input  logic                 axi_req_i,
  input  logic                 axi_we_i,
  input  logic [StrbWidth-1:0] axi_be_i,
  input  logic [AddrWidth-1:0] axi_addr_i,
  input  logic [DataWidth-1:0] axi_wdata_i,
  output logic [DataWidth-1:0] axi_rdata_o

);

logic [($clog2(MemWords)+2)-1:0] aaddr;
logic [($clog2(MemWords)+2)-1:0] baddr;

assign aaddr = cpu_addr_i - BaseOffset;
assign baddr = axi_addr_i - BaseOffset;

rt_handshake_fsm #(
) i_fsm (
  .clk_i,
  .rst_ni,
  .cpu_req_i,
  .cpu_gnt_o,
  .cpu_rvalid_o
);

dp_sram #(
  .DataWidth (DataWidth),
  .NumWords  (MemWords)
) i_mem (
  .clk_i   (clk_i),
  .rst_ni  (rst_ni),
  // Port A
  .areq_i  (cpu_req_i),
  .awe_i   (cpu_we_i),
  .aaddr_i (aaddr[($clog2(MemWords)+2)-1:2]),
  .awdata_i(cpu_wdata_i),
  .abe_i   (cpu_be_i),
  .ardata_o(cpu_rdata_o),
  // Port B
  .breq_i  (axi_req_i),
  .bwe_i   (axi_we_i),
  .baddr_i (baddr[($clog2(MemWords)+2)-1:2]),
  .bwdata_i(axi_wdata_i),
  .bbe_i   (axi_be_i),
  .brdata_o(axi_rdata_o)
);

endmodule

