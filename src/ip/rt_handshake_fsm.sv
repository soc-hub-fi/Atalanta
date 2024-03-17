module rt_handshake_fsm #()(
  input  logic clk_i,
  input  logic rst_ni,
  input  logic cpu_req_i,
  output logic cpu_gnt_o,
  output logic cpu_rvalid_o
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
    cpu_gnt_o    = 0;
    cpu_rvalid_o = 0;
    case (curr_state)
      IDLE: begin
        if(cpu_req_i) begin
          cpu_gnt_o  = 1;
          next_state = ACK;
        end
      end
      ACK: begin
        cpu_rvalid_o = 1;
        if (cpu_req_i) begin
          cpu_gnt_o = 1;
          next_state = ACK;
        end else begin
          next_state = IDLE;
        end
      end
      VALID: begin
        cpu_rvalid_o = 1;
          next_state = IDLE;
        end
      default: begin
        // nothing
      end
    endcase
  end // handshake_fsm

endmodule : rt_handshake_fsm
