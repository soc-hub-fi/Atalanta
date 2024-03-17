//------------------------------------------------------------------------------
// Module   : prim_clock_gating.sv
//
// Project  : RT-SS
// Author(s): Tom Szymkowiak <thomas.szymkowiak@tuni.fi>
// Created  : 04-dec-2023
//
// Description: Module used to replace clock gates used within Ibex IP of RT-SS.
// No gating is applied and input clock is connected straight to output clock.
//
// Parameters:
//  None
//
// Inputs:
//   - clk_i: Input clock
//   - en_i: Clock gate enable (not used)
//   - test_en_i: Test enable (not used)
//
// Outputs:
//  - clk_o: Output clock
//
// Revision History:
//  - Version 1.0: Initial release
//
//------------------------------------------------------------------------------

module prim_clock_gating (
  input  clk_i,
  input  en_i,
  input  test_en_i,
  output clk_o
);

  assign clk_o = clk_i;

endmodule
