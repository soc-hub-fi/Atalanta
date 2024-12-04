/* Author: Antti Nurmi <antti.nurmi@tuni.fi>
 * Single interrupt pulse synchronizer
 * Produces one clk_b cycle long output pulse
 * from one clk_a cycle long input pulse.
 * Works for >= 2 integer values of `Divisor`.
 */

module irq_pulse_cdc #(
  parameter int unsigned Divisor = 2
)(
  input  logic rst_ni,
  input  logic clk_a_i,
  input  logic clk_b_i,
  input  logic pulse_i,
  output logic pulse_o
);

logic [Divisor-1:0] pulse;
logic pulse_d, pulse_q;

for (genvar ii=0; ii<Divisor; ii++)
  always_ff @(posedge(clk_a_i) or negedge(rst_ni))
    begin : g_delay_regs
      if (~rst_ni) begin
        pulse[ii] <= 0;
      end else begin
        if (ii == 0)
          pulse[ii] <= pulse_i;
        else
          pulse[ii] <= pulse[ii-1];
      end
    end : g_delay_regs

assign pulse_d = pulse_i | (|pulse[0+:Divisor-1]);

always_ff @(posedge(clk_b_i) or negedge(rst_ni))
  begin : slow_register
    if (~rst_ni)
      pulse_o <= 0;
    else
      pulse_o <= pulse_d;
  end

endmodule : irq_pulse_cdc
