/*
  rt_mem_axi_intf.sv
  AXI lite slave port to memory converter

  authors: Antti Nurmi    <antti.nurmi@tuni.fi>
           Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
*/
module rt_mem_axi_intf #(
  /* NOTE: Limitation exists that MEM DW/AW must be larger or equal to the
     respective AXI AW/DW i.e. AXI CANNOT be wider than mem */
  parameter int unsigned MEM_AW                         = 16,
  parameter int unsigned MEM_DW                         = 32,
  parameter int unsigned AXI_AW                         = 16,
  parameter int unsigned AXI_DW                         = 32,
  parameter logic [MEM_AW-1:0] ADDR_MASK  = 'h0 // bits set to 1 in the mask will be set to 0 in the addr_o
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,
  // memory side
  output logic                  req_o,
  output logic                  we_o,
  output logic [    MEM_AW-1:0] addr_o,
  output logic [    MEM_DW-1:0] wdata_o,
  output logic [(MEM_DW/8)-1:0] be_o,
  input  logic [    MEM_DW-1:0] rdata_i,
  // AXI side
  AXI_LITE.Slave               axi_lite_s
);

typedef enum logic [3:0] {
  IDLE,
  READ_START,
  AW_HANDSHAKE,
  AR_HANDSHAKE,
  AW_OK,
  //W_OK,
  R_HANDSHAKE,
  W_HANDSHAKE,
  B_HANDSHAKE
} state_t;

state_t curr_state, next_state;

logic r_valid;

logic                  we_s;
logic                  w_ready_s;
logic                  aw_ready_s;
logic                  ar_ready_s;
logic                  rd_req_s;
logic                  wr_req_s;
logic [(MEM_DW/8)-1:0] be_s;
logic     [MEM_DW-1:0] wdata_s;
logic     [MEM_AW-1:0] addr_r;
logic     [MEM_AW-1:0] addr_s;

//for now direct assignment
assign be_o       = be_s;
assign axi_lite_s.r_data = rdata_i;
assign req_o      = (rd_req_s | wr_req_s);
assign we_o       = we_s;
assign wdata_o    = wdata_s;
assign axi_lite_s.w_ready  = w_ready_s;
assign axi_lite_s.aw_ready = aw_ready_s;
assign axi_lite_s.ar_ready = ar_ready_s;

// apply masking to address for translation
assign addr_o = addr_s & ~(ADDR_MASK);

always_ff @(posedge(clk_i) or negedge(rst_ni))
  begin : state_reg
    if(~rst_ni) begin
      curr_state <= IDLE;
    end
    else begin
      curr_state <= next_state;
    end
  end // state_reg

always_ff @(posedge(clk_i) or negedge(rst_ni))
 begin : r_valid_out
   if(~rst_ni) begin
    axi_lite_s.r_valid <= 0;
   end
   else begin
    axi_lite_s.r_valid <= r_valid;
   end
 end // r_valid_out

 
always_comb
begin : w_data_update
  if (w_ready_s & axi_lite_s.w_valid) begin
    wdata_s  = axi_lite_s.w_data;
    we_s     = 1'b1;
    wr_req_s = 1'b1;
    be_s     = axi_lite_s.w_strb;
  end else begin 
    wdata_s  = '0;
    we_s     = 1'b0;
    wr_req_s = 1'b0;
    be_s     = '0;
  end
end

// assigns addr_r depending on whether a read/write transaction is occurring
always_ff @(posedge clk_i or negedge rst_ni)
begin : addr_reg_update
  if (~rst_ni) begin
    addr_r   <= '0;
  end else begin
    if(ar_ready_s & axi_lite_s.ar_valid) begin
      addr_r   <= axi_lite_s.ar_addr;
    end else if (aw_ready_s & axi_lite_s.aw_valid) begin
      addr_r   <= axi_lite_s.aw_addr;
    end
  end
end

always_comb
  begin : addr_update

    rd_req_s = 1'b0;

    if (ar_ready_s & axi_lite_s.ar_valid) begin
      addr_s   = axi_lite_s.ar_addr;
      rd_req_s = 1'b1;
    end else if (aw_ready_s & axi_lite_s.aw_valid) begin
      addr_s = axi_lite_s.aw_addr;
    end else begin
      addr_s = addr_r;
    end
  end


always_comb
  begin : main_comb

    next_state         = IDLE;
    aw_ready_s         =  0; // AW
    w_ready_s          =  0; // W
    axi_lite_s.b_resp  =  0; // B
    axi_lite_s.b_valid =  0;
    ar_ready_s         =  0; // AR
    axi_lite_s.r_resp  =  0;
    r_valid            =  0;

    case (curr_state)
      IDLE: begin
        r_valid      =  0;
        if (axi_lite_s.ar_valid) begin
          next_state = READ_START;
          end
        else if (axi_lite_s.aw_valid) begin
          next_state = AW_HANDSHAKE;
          end
        else
          next_state = IDLE;
        end
      READ_START: begin
        ar_ready_s   =  1;
        next_state   = AR_HANDSHAKE;
        end
      AR_HANDSHAKE: begin
        r_valid      =  1;
        next_state   = R_HANDSHAKE;
        end
      R_HANDSHAKE: begin
        if (axi_lite_s.r_ready) begin
          r_valid      =  0;
          next_state   = IDLE;
          end
        else begin
          r_valid      =  1;
          next_state   = R_HANDSHAKE;
          end
        end
      AW_HANDSHAKE: begin
        aw_ready_s   =  1;
        next_state   = AW_OK;
        end
      AW_OK: begin
        if (axi_lite_s.w_valid) begin
          w_ready_s  = 0;
          next_state = W_HANDSHAKE;
          end
        else begin
          next_state = AW_OK;
          end
        end
      W_HANDSHAKE: begin
        w_ready_s    =  1;
        next_state   =  B_HANDSHAKE;
        end
      B_HANDSHAKE: begin
        axi_lite_s.b_valid =  1;
        next_state   = IDLE;
        end
      default: begin
        end
    endcase
  end // main_comb
endmodule : rt_mem_axi_intf


