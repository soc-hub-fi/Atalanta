/*
  ibex_axi_bridge.sv
  memory to AXI lite master port converter

  authors: Antti Nurmi    <antti.nurmi@tuni.fi>
           Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
*/
module ibex_axi_bridge #(
  /* NOTE: Limitation exists that IBEX DW/AW must be larger or equal to the
     respective AXI AW/DW. i.e. AXI CANNOT be wider than IBEX */
  parameter int AXI_AW  = 16,
  parameter int AXI_DW  = 32,
  parameter int IBEX_AW = 32,
  parameter int IBEX_DW = 32
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,
  // ibex side
  input  logic                  req_i,
  output logic                  gnt_o,
  output logic                  rvalid_o,
  input  logic                  we_i,
  input  logic [           3:0] be_i,
  input  logic [   IBEX_AW-1:0] addr_i,
  input  logic [   IBEX_DW-1:0] wdata_i,
  output logic [   IBEX_DW-1:0] rdata_o,
  output logic                  err_o,
  // AXI side
  output logic [    AXI_AW-1:0] aw_addr_o,
  output logic                  aw_valid_o,
  input  logic                  aw_ready_i,

  output logic [    AXI_DW-1:0] w_data_o,
  output logic [(AXI_DW/8)-1:0] w_strb_o,
  output logic                  w_valid_o,
  input  logic                  w_ready_i,

  input  logic [           1:0] b_resp_i,
  input  logic                  b_valid_i,
  output logic                  b_ready_o,

  output logic [    AXI_AW-1:0] ar_addr_o,
  output logic                  ar_valid_o,
  input  logic                  ar_ready_i,

  input  logic [    AXI_DW-1:0] r_data_i,
  input  logic [           1:0] r_resp_i,
  input  logic                  r_valid_i,
  output logic                  r_ready_o
);

typedef enum logic [2:0] {
  IDLE,
  AR_REQ,
  AW_REQ,
  W_REQ,
  R_RSP,
  B_RSP,
  GNT,
  RVALID
} state_t;

state_t curr_state, next_state;

//for now direct assignment
assign w_strb_o = be_i;

always_ff @(posedge(clk_i) or negedge(rst_ni))
  begin : state_reg
    if(~rst_ni) begin
      curr_state <= IDLE;
    end
    else begin
      curr_state <= next_state;
    end
  end // state_reg

always_comb
  begin : main_comb

    next_state = IDLE;
    gnt_o      =  0;
    rdata_o    = '0;
    rvalid_o   =  0;
    err_o      =  0;
    aw_addr_o  = '0;
    aw_valid_o =  0;
    w_data_o   = '0;
    w_valid_o  =  0;
    b_ready_o  = '0;
    ar_addr_o  = '0;
    ar_valid_o =  0;
    r_ready_o  =  0;

    case (curr_state)
      IDLE: begin
        if(req_i) begin
          if (we_i) begin
            next_state = AW_REQ;
          end else begin
            next_state = AR_REQ;
          end
        end
      end
      AR_REQ: begin
        ar_addr_o  = addr_i[AXI_AW-1:0];
        ar_valid_o =  1;
        next_state = AR_REQ;
        if (ar_ready_i) begin
          next_state = R_RSP;
        end
      end
      R_RSP: begin
        r_ready_o  = 1;
        next_state = R_RSP;
        if (r_valid_i) begin
          next_state = GNT;
        end
      end
      AW_REQ: begin
        aw_addr_o  = addr_i[AXI_AW-1:0];
        aw_valid_o =  1;
        next_state = AW_REQ;
        if (aw_ready_i) begin
          next_state = W_REQ;
        end
      end
      W_REQ: begin
        w_data_o   = wdata_i;
        w_valid_o  = 1;
        next_state = W_REQ;
        if (w_ready_i) begin
          next_state = B_RSP;
        end
      end
      B_RSP: begin
        b_ready_o  = 1;
        next_state = B_RSP;
        if (b_valid_i) begin
          next_state = GNT;
        end
      end
      GNT: begin
        gnt_o      = 1;
        err_o      = r_resp_i[1];
        next_state = RVALID;
      end
      RVALID: begin
        rvalid_o   = 1;
        rdata_o    = r_data_i;
        next_state = IDLE;
      end
      default: begin
        end

      endcase
    end // main_comb
endmodule : ibex_axi_bridge
