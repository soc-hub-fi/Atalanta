// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// adapted by Antti Nurmi <antti.nurmi@tuni.fi>


module timer_core #(
) (
  input clk_i,
  input rst_ni,

  input        active,
  input [11:0] prescaler,
  input [ 7:0] step,

  output logic        tick,
  output logic [63:0] mtime_d,
  input        [63:0] mtime,
  input        [63:0] mtimecmp,

  output logic intr
);

  logic [11:0] tick_count;

  always_ff @(posedge clk_i or negedge rst_ni) begin : generate_tick
    if (!rst_ni) begin
      tick_count <= 12'h0;
    end else if (!active) begin
      tick_count <= 12'h0;
    end else if (tick_count == prescaler) begin
      tick_count <= 12'h0;
    end else begin
      tick_count <= tick_count + 1'b1;
    end
  end

  assign tick = active & (tick_count >= prescaler);

  assign mtime_d = mtime + 64'(step);

  // interrupt is generated if mtime is greater than or equal to mtimecmp
  assign intr = active & (mtime >= mtimecmp);


endmodule : timer_core
