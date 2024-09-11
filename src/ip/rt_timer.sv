module rt_timer
#(
  parameter int unsigned AXI_DATA_WIDTH = 32,
  parameter int unsigned AXI_ADDR_WIDTH = 32
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

logic                          active_r;
logic [                  31:0] mtime_read_low_r;
logic [                  31:0] mtime_read_high_r;
logic [                  31:0] mtime_write_low_r;
logic [                  31:0] mtime_write_high_r;
logic [                  31:0] mtimecmp_low_r;
logic [                  31:0] mtimecmp_high_r;

logic tick;
logic [11:0] prescale_r;
logic [63:0] mtime_r;


always_ff @( posedge clk_i or negedge rst_ni )
  begin : write_logic
    if ( ~rst_ni )
      begin
        mtime_r             <= 64'b0;
        mtimecmp_high_r     <= 32'b0;
        mtimecmp_low_r      <= 32'b0;
        active_r            <=  1'b0;
        prescale_r          <= 12'b0;
      end else if (pwrite_i) begin
        case (paddr_i[4:2])
          MTimeAddrLow: begin
            mtime_r[63:32] <= pwdata_i;
          end
          MTimeAddrHigh: begin
            mtime_r[31:0] <= pwdata_i;
          end
          MTimeCmpAddrLow: begin
            mtimecmp_low_r <= pwdata_i;
          end
          MTimeCmpAddrHigh: begin
            mtimecmp_high_r <= pwdata_i;
          end
          CtrlAddr: begin
            active_r   <= pwdata_i[0];
            prescale_r <= pwdata_i[20:8];
          end
          default: begin
            //nothing
          end
        endcase
      end
      else if (tick) begin
        mtime_r <= mtime_r + 1;
      end
  end

always_comb
  begin : read_logic
    prdata_o = '0;
    if (~pwrite_i) begin
      case (paddr_i[4:2])
        MTimeAddrLow: begin
          prdata_o = mtime_read_low_r;
        end
        MTimeAddrHigh: begin
          prdata_o = mtime_read_high_r;
        end
        MTimeCmpAddrLow: begin
          prdata_o = mtimecmp_low_r;
        end
        MTimeCmpAddrHigh: begin
          prdata_o = mtimecmp_high_r;
        end
        CtrlAddr: begin
          prdata_o = {12'b0, prescale_r, 7'b0, active_r};
        end
        default: begin
          prdata_o = '0;
        end
      endcase
    end
  end

always_comb begin
  pready_o = '0;
  pslverr_o = '0;
  if (penable_i) begin
    pready_o = 1;
  end
end

timer_core #(
) i_timer (
  .clk_i     (clk_i),
  .rst_ni    (rst_ni),
  .active    (active_r),
  .prescaler (prescale_r),
  .step      (8'b0),
  .tick      (tick),
  .mtime_d   ({mtime_read_high_r,mtime_read_low_r}),
  .mtime     (mtime_r),
  .mtimecmp  ({mtimecmp_high_r, mtimecmp_low_r}),
  .intr      (timer_irq_o)
);


endmodule
