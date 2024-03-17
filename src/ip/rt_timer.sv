module rt_timer
#(
  parameter int unsigned AXI_DATA_WIDTH = 32,
  parameter int unsigned AXI_ADDR_WIDTH = 32
)(

  input  logic       clk_i,
  input  logic       rst_ni,
  output logic       timer_irq_o,
  AXI_LITE.Slave     axi_lite_s
);

localparam int unsigned MTimeAddrLow      = 3'b000;
localparam int unsigned MTimeAddrHigh     = 3'b001;
localparam int unsigned MTimeCmpAddrLow   = 3'b010;
localparam int unsigned MTimeCmpAddrHigh  = 3'b011;
localparam int unsigned CtrlAddr          = 3'b100;

logic                          we;
logic [    AXI_ADDR_WIDTH-1:0] addr;
logic [    AXI_DATA_WIDTH-1:0] wdata;
logic [(AXI_DATA_WIDTH/8)-1:0] be;
logic [    AXI_DATA_WIDTH-1:0] rdata;
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

mem_axi_bridge #(
  .MEM_AW     ( AXI_ADDR_WIDTH        ),
  .MEM_DW     ( AXI_DATA_WIDTH        ),
  .AXI_AW     ( AXI_ADDR_WIDTH        ),
  .AXI_DW     ( AXI_DATA_WIDTH        )
) i_mem_axi_bridge (
  .clk_i      ( clk_i                 ),
  .rst_ni     ( rst_ni                ),
  // memory side
  .req_o      ( /*NC*/                ),
  .we_o       ( we                    ),
  .addr_o     ( addr                  ),
  .wdata_o    ( wdata                 ),
  .be_o       ( be                    ),
  .rdata_i    ( rdata                 ),
  // AXI side
  .aw_addr_i  ( axi_lite_s.aw_addr    ),
  .aw_valid_i ( axi_lite_s.aw_valid   ),
  .aw_ready_o ( axi_lite_s.aw_ready   ),
  .w_data_i   ( axi_lite_s.w_data     ),
  .w_strb_i   ( axi_lite_s.w_strb     ),
  .w_valid_i  ( axi_lite_s.w_valid    ),
  .w_ready_o  ( axi_lite_s.w_ready    ),
  .b_resp_o   ( axi_lite_s.b_resp     ),
  .b_valid_o  ( axi_lite_s.b_valid    ),
  .b_ready_i  ( axi_lite_s.b_ready    ),
  .ar_addr_i  ( axi_lite_s.ar_addr    ),
  .ar_valid_i ( axi_lite_s.ar_valid   ),
  .ar_ready_o ( axi_lite_s.ar_ready   ),
  .r_data_o   ( axi_lite_s.r_data     ),
  .r_resp_o   ( axi_lite_s.r_resp     ),
  .r_valid_o  ( axi_lite_s.r_valid    ),
  .r_ready_i  ( axi_lite_s.r_ready    )
);

always_ff @( posedge clk_i or negedge rst_ni )
  begin : write_logic
    if ( ~rst_ni )
      begin
        mtime_r             <= 64'b0;
        mtimecmp_high_r     <= 32'b0;
        mtimecmp_low_r      <= 32'b0;
        active_r            <=  1'b0;
        prescale_r          <= 12'b0;
      end else if (we) begin
        case (addr[4:2])
          MTimeAddrLow: begin
            mtime_r[63:32] <= wdata;
          end
          MTimeAddrHigh: begin
            mtime_r[31:0] <= wdata;
          end
          MTimeCmpAddrLow: begin
            mtimecmp_low_r <= wdata;
          end
          MTimeCmpAddrHigh: begin
            mtimecmp_high_r <= wdata;
          end
          CtrlAddr: begin
            active_r   <= wdata[0];
            prescale_r <= wdata[20:8];
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
    rdata = '0;
    if (~we) begin
      case (addr[4:2])
        MTimeAddrLow: begin
          rdata = mtime_read_low_r;
        end
        MTimeAddrHigh: begin
          rdata = mtime_read_high_r;
        end
        MTimeCmpAddrLow: begin
          rdata = mtimecmp_low_r;
        end
        MTimeCmpAddrHigh: begin
          rdata = mtimecmp_high_r;
        end
        CtrlAddr: begin
          rdata = {12'b0, prescale_r, 7'b0, active_r};
        end
        default: begin
          rdata = '0;
        end
      endcase
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
