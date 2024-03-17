module rt_ibex_bootrom #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32
)(
    input  logic clk_i,
    input  logic rst_ni,
    input  logic req_i,
    output logic gnt_o,
    output logic rvalid_o,
    input  logic [ADDR_WIDTH-1:0] addr_i,
    output logic [DATA_WIDTH-1:0] rdata_o
);

localparam int unsigned RomSize = 2;
localparam int unsigned RamAw   = $clog2(RomSize);

rt_handshake_fsm #(
) i_fsm (
  .clk_i   (clk_i),
  .rst_ni (rst_ni),
  .cpu_req_i (req_i),
  .cpu_gnt_o (gnt_o),
  .cpu_rvalid_o (rvalid_o)
);

const logic [DATA_WIDTH-1:0] rom [RomSize] = {
    32'h0000006F,
    32'h0000006F};

logic [RamAw-1:0] addr;

always_ff @(posedge clk_i or negedge rst_ni)
begin : addr_reg
  if (~rst_ni)
    addr <= '0;
  else
    if (req_i)
      addr <= addr_i[(RamAw+2):2];
end

assign rdata_o = rom[addr];

endmodule : rt_ibex_bootrom
