/* Author: Antti Nurmi <antti.nurmi@tuni.fi>
 * Single interrupt pulse synchronizer
 * Produces one clk_b cycle long output pulse
 * from one clk_a cycle long input pulse.
 * Works for >= 2 integer values of `Divisor`.
 */

module irq_pulse_cdc #(
  parameter int unsigned DivMax = 2
)(
  input  logic rst_ni,
  input  logic [DivMax-1:0] divisor_i,
  input  logic clk_a_i,
  input  logic clk_b_i,
  input  logic pulse_i,
  output logic pulse_o
);

logic [DivMax-1:0] cnt_d, cnt_q;
logic pulse_d, pulse_q;


assign cnt_d = ((pulse_i | cnt_q != 0) & cnt_q != divisor_i) ? cnt_q | 1 << cnt_q : '0;

always_ff @(posedge clk_a_i or negedge rst_ni)
  begin
    if (~rst_ni) cnt_q <= '0;
    else         cnt_q <= cnt_d;
  end

assign pulse_d = pulse_i; // | (|pulse[0+:DivMax-1] & mask);
//assign pulse_d = pulse_i | (|pulse[0+:DivMax-1] & mask);

always_ff @(posedge(clk_b_i) or negedge(rst_ni))
  begin : slow_register
    if (~rst_ni)
      pulse_o <= 0;
    else
      pulse_o <= pulse_d;
  end

endmodule : irq_pulse_cdc
