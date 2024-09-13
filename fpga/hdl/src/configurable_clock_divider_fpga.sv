//------------------------------------------------------------------------------
// Module   : configurable_clock_divider_fpga.sv
//
// Project  : RT-SS
// Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
// Created  : 30-may-2024
//
// Description: Module used to replace tico_ctclk_configurable_divider used to
//              divide a clock using a register divider. Clock gate has been
//              replaced by a BUFGCE primitive.
//
// Parameters:
//  MAX_DIV_BY : Maximum clock division register value
//
// Inputs:
//   - clk_i: Input clock
//   - rst_n: asynchronous active low reset
//   - divider_conf: Clock divider value
//
// Outputs:
//  - clk_o: Output clock (divided)
//
// Revision History:
//  - Version 1.0: Initial release
//
//------------------------------------------------------------------------------

module configurable_clock_divider_fpga #(
  parameter integer unsigned MAX_DIV_BY = 3
) (
  input  logic                          clk_in,
  input  logic                          rst_n,
  input  logic [$clog2(MAX_DIV_BY)-1:0] divider_conf,
  output logic                          clk_out
);

  logic [$clog2(MAX_DIV_BY)-1:0] divider_r;
  logic [$clog2(MAX_DIV_BY)-1:0] cnt_r;
  logic                          en_r;

  always_ff @(posedge clk_in, negedge rst_n)
    reg_proc: begin
      if(rst_n == 1'b0) begin
        divider_r <= 'd1;
      end else begin
        divider_r <= divider_conf;
      end
  end


  always_ff @(posedge clk_in, negedge rst_n)
    divider_proc: begin
      if (rst_n == 1'b0) begin
        cnt_r <= 0;
        en_r  <= 1'b0;
      end else begin
        cnt_r <= (cnt_r == divider_r-1) ? 0 : cnt_r + 1;
        en_r  <= (cnt_r == 0) ? 1 : 0;
      end
  end

  BUFGCE i_bugce (
    .O  ( clk_out ), // 1-bit output: Clock output
    .CE ( en_r    ), // 1-bit input: Clock enable input for I0
    .I  ( clk_in  )  // 1-bit input: Primary clock
  );

endmodule // configurable_clock_divider_fpga
