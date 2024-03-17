module rt_mem_mux #(
  parameter int unsigned AddrWidth = 32,
  parameter int unsigned DataWidth = 32,
  // Derived, do not overwrite
  localparam int unsigned StrbWidth = DataWidth/8
)(
  input logic clk_i,
  input logic rst_ni,
  input logic select_i,
    // CPU side
  input  logic                 cpu_req_i,
  output logic                 cpu_gnt_o,
  output logic                 cpu_rvalid_o,
  input  logic                 cpu_we_i,
  input  logic [StrbWidth-1:0] cpu_be_i,
  input  logic [AddrWidth-1:0] cpu_addr_i,
  input  logic [DataWidth-1:0] cpu_wdata_i,
  output logic [DataWidth-1:0] cpu_rdata_o,

  // A side
  output logic                 a_req_o,
  input  logic                 a_gnt_i,
  input  logic                 a_rvalid_i,
  output logic                 a_we_o,
  output logic [StrbWidth-1:0] a_be_o,
  output logic [AddrWidth-1:0] a_addr_o,
  output logic [DataWidth-1:0] a_wdata_o,
  input  logic [DataWidth-1:0] a_rdata_i,
  // B side
  output logic                 b_req_o,
  input  logic                 b_gnt_i,
  input  logic                 b_rvalid_i,
  output logic                 b_we_o,
  output logic [StrbWidth-1:0] b_be_o,
  output logic [AddrWidth-1:0] b_addr_o,
  output logic [DataWidth-1:0] b_wdata_o,
  input  logic [DataWidth-1:0] b_rdata_i
);

logic select_r;
logic select;
logic switch;
logic cpu_req;

always_ff @(posedge clk_i or negedge rst_ni)
  begin : select_reg
    if (~rst_ni) begin
      select_r   <= '0;
    end else begin
      select_r   <= select_i;
    end
  end

assign switch  = (select_r != select_i);
assign select  = (switch) ? select_r : select_i;
assign cpu_req = (switch) ? 0 : cpu_req_i;


always_comb
  begin : mux
    a_req_o      = '0;
    a_we_o       = '0;
    a_be_o       = '0;
    a_addr_o     = '0;
    a_wdata_o    = '0;

    b_req_o      = '0;
    b_we_o       = '0;
    b_be_o       = '0;
    b_addr_o     = '0;
    b_wdata_o    = '0;

    cpu_rdata_o  = '0;
    cpu_gnt_o    = '0;

    if (select) begin
      a_req_o      = cpu_req;
      a_we_o       = cpu_we_i;
      a_be_o       = cpu_be_i;
      a_addr_o     = cpu_addr_i;
      a_wdata_o    = cpu_wdata_i;
      cpu_rdata_o  = a_rdata_i;
      cpu_gnt_o    = a_gnt_i;
      cpu_rvalid_o = a_rvalid_i;
    end else begin
      b_req_o      = cpu_req;
      b_we_o       = cpu_we_i;
      b_be_o       = cpu_be_i;
      b_addr_o     = cpu_addr_i;
      b_wdata_o    = cpu_wdata_i;
      cpu_rdata_o  = b_rdata_i;
      cpu_gnt_o    = b_gnt_i;
      cpu_rvalid_o = b_rvalid_i;
    end
  end

endmodule : rt_mem_mux
