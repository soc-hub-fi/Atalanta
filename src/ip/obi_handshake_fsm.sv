module obi_handshake_fsm #()(
  input  logic clk_i,
  input  logic rst_ni,
  input  logic req_i,
  output logic gnt_o,
  output logic rvalid_o
);

typedef enum logic [1:0] {
  IDLE,
  ACK,
  VALID
} handshake_t;

handshake_t curr_state, next_state;

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
  begin : handshake_fsm
    next_state = IDLE;
    gnt_o    = 0;
    rvalid_o = 0;
    case (curr_state)
      IDLE: begin
        if(req_i) begin
          gnt_o  = 1;
          next_state = ACK;
        end
      end
      ACK: begin
        rvalid_o = 1;
        if (req_i) begin
          gnt_o = 1;
          next_state = ACK;
        end else begin
          next_state = IDLE;
        end
      end
      VALID: begin
        rvalid_o = 1;
          next_state = IDLE;
        end
      default: begin
        // nothing
      end
    endcase
  end // handshake_fsm

endmodule : obi_handshake_fsm
