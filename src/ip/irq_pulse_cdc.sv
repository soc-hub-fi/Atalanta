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

localparam int unsigned CntWidth = $clog2(DivMax);

logic [CntWidth-1:0] cnt_d, cnt_q;
logic [DivMax-1:0] decode;
logic pulse_d, pulse_q;

always_comb
  begin
    cnt_d = 0;
    if (pulse_i) cnt_d = 1;
    else if (cnt_q == divisor_i) cnt_d = 0;
    else if (cnt_q != 0) cnt_d = cnt_q + 1;
  end

assign decode = (2**cnt_q) - 1;

always_ff @(posedge clk_a_i or negedge rst_ni)
  begin
    if (~rst_ni) cnt_q <= '0;
    else         cnt_q <= cnt_d;
  end

assign pulse_d = |decode;

always_ff @(posedge(clk_b_i) or negedge(rst_ni))
  begin : slow_register
    if (~rst_ni)
      pulse_o <= 0;
    else
      pulse_o <= pulse_d;
  end

endmodule : irq_pulse_cdc
