module irq_pulse_cdc #()(
  input  logic rst_ni,
  input  logic clk_a_i,
  input  logic clk_b_i,
  input  logic pulse_i,
  output logic pulse_o
);

logic slow_pulse, slow_pulse_q;

always_ff @(posedge(clk_a_i) or negedge(rst_ni))
  begin : delay
    if (~rst_ni) begin
      pulse_o      <= 0;
      //slow_pulse_q <= 0;
    end else begin
      pulse_o      <= pulse_i;
      //slow_pulse_q <= slow_pulse;
    end
  end

always_ff @(posedge(clk_b_i) or negedge(rst_ni))
  begin : slow_delay
    if (~rst_ni) begin
      //pulse_o      <= 0;
      slow_pulse_q <= 0;
    end else begin
      //pulse_o      <= pulse_i;
      slow_pulse_q <= slow_pulse;
    end
  end

assign slow_pulse = pulse_i | pulse_o;

endmodule : irq_pulse_cdc
