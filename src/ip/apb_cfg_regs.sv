module apb_cfg_regs #(
  parameter int unsigned DivDefault
)(
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        penable_i,
  input  logic        pwrite_i,
  input  logic [31:0] paddr_i,
  input  logic        psel_i,
  input  logic [31:0] pwdata_i,
  output logic [31:0] prdata_o,
  output logic        pready_o,
  output logic        pslverr_o,
  output logic  [3:0] div_o
);

localparam int unsigned ClkDivAddr = 3'b000;

logic [3:0] div_d, div_q;

always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if (~rst_ni) begin
      div_q <= DivDefault;
    end else begin
      div_q <= div_d;
    end
  end

logic [2:0] int_addr;
assign int_addr  = paddr_i[4:2];
assign pslverr_o = '0;
assign pready_o  = penable_i;
assign div_o     = div_q;

always_comb
  begin : apb_access
    div_d = div_q;
    prdata_o = '0;
    if (penable_i) begin
      if (pwrite_i) begin // write logic
        case (int_addr)
          ClkDivAddr: div_d = pwdata_i[3:0];
          default:;
        endcase
      end else begin // read logic
        case (int_addr)
          ClkDivAddr: prdata_o = {28'h0, div_q};
          default:;
        endcase
      end
    end
  end : apb_access

endmodule : apb_cfg_regs
