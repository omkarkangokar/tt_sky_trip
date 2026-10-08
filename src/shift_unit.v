/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Packs the valid operand pairs to the low lanes, using the prefix positions.
// Lanes that are not valid stay at zero.
module shift_unit #(
    parameter DW    = 4,
    parameter LANES = 4,
    parameter PW    = 2
) (
    input  wire [LANES-1:0]    valid_mask,
    input  wire [LANES*PW-1:0] prefix,
    input  wire [LANES*DW-1:0] a_values,
    input  wire [LANES*DW-1:0] b_values,
    output reg  [LANES*DW-1:0] packed_a,
    output reg  [LANES*DW-1:0] packed_b
);

  integer i;

  always @(*) begin
    packed_a = 0;
    packed_b = 0;
    for (i = 0; i < LANES; i = i + 1) begin
      if (valid_mask[i]) begin
        packed_a[prefix[i*PW +: PW]*DW +: DW] = a_values[i*DW +: DW];
        packed_b[prefix[i*PW +: PW]*DW +: DW] = b_values[i*DW +: DW];
      end
    end
  end

endmodule
