module apb_mtimer#(
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
  output logic        timer_irq_o
);

localparam int unsigned MTimeAddrLow      = 3'b000;
localparam int unsigned MTimeAddrHigh     = 3'b001;
localparam int unsigned MTimeCmpAddrLow   = 3'b010;
localparam int unsigned MTimeCmpAddrHigh  = 3'b011;
localparam int unsigned CtrlAddr          = 3'b100;

logic [63:0] mtime_q, mtime_d;
logic [31:0] mtime_hi, mtime_lo;
logic [63:0] mtimecmp_q;
logic [31:0] mtimecmp_hi, mtimecmp_lo;
logic [2:0] prescaler_q, prescaler_d;
logic [2:0] counter_q, counter_d;
logic       enable_q, enable_d;

logic [2:0] int_addr;
assign int_addr = paddr_i[4:2];

always_ff @(posedge clk_i or negedge rst_ni)
  begin
    if(~rst_ni) begin
      mtime_q     <= '0;
      mtimecmp_q  <= '0;
      prescaler_q <= '0;
      enable_q    <= '0;
      counter_q   <= '0;
    end else begin
      mtime_q     <= mtime_d;
      mtimecmp_q  <= {mtimecmp_hi, mtimecmp_lo};
      prescaler_q <= prescaler_d;
      enable_q    <= enable_d;
      counter_q   <= counter_d;
    end
  end

always_comb
  begin
    mtime_d   = mtime_q;
    counter_d = 0;
    if (penable_i && pwrite_i) begin
      mtime_d = {mtime_hi, mtime_lo};
    end else if (enable_q) begin
      counter_d = counter_q + 1;
      if (counter_q == prescaler_q) begin
        counter_d = 0;
        mtime_d = mtime_q + 1;
      end
    end
  end

always_comb
  begin : apb_access
    mtime_hi    = mtime_d[63:32];
    mtime_lo    = mtime_d[31:0];
    mtimecmp_hi = mtimecmp_q[63:32];
    mtimecmp_lo = mtimecmp_q[31:0];
    prdata_o    = '0;
    prescaler_d = prescaler_q;
    enable_d    = enable_q;
    if (penable_i) begin
      if (pwrite_i) begin // write logic
        case (int_addr)
          MTimeAddrLow:     mtime_lo    = pwdata_i;
          MTimeAddrHigh:    mtime_hi    = pwdata_i;
          MTimeCmpAddrLow:  mtimecmp_lo = pwdata_i;
          MTimeCmpAddrHigh: mtimecmp_hi = pwdata_i;
          CtrlAddr: begin
            enable_d    = pwdata_i[0];
            prescaler_d = pwdata_i[10:8];
          end
          default:;
        endcase
      end else begin // read logic
        case (int_addr)
          MTimeAddrLow:     prdata_o = mtime_q[31:0];
          MTimeAddrHigh:    prdata_o = mtime_q[63:32];
          MTimeCmpAddrLow:  prdata_o = mtimecmp_q[31:0];
          MTimeCmpAddrHigh: prdata_o = mtimecmp_q[63:32];
          CtrlAddr: begin
            prdata_o[0]    = enable_q;
            prdata_o[10:8] = prescaler_q;
          end
          default:;
        endcase
      end
    end
  end : apb_access

assign pslverr_o = '0;
assign pready_o = penable_i;
assign timer_irq_o = (mtime_q >= mtimecmp_q) & enable_q;

endmodule
