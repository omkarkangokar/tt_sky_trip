/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Matching and packing unit: intersects the two masks, then packs the
// matching operand pairs to the low lanes.
module mfiu #(
    parameter DW    = 4,
    parameter LANES = 4,
    parameter PW    = 2
) (
    input  wire [LANES-1:0]    a_mask,
    input  wire [LANES-1:0]    b_mask,
    input  wire [LANES*DW-1:0] a_values,
    input  wire [LANES*DW-1:0] b_values,
    output wire [LANES*DW-1:0] packed_a,
    output wire [LANES*DW-1:0] packed_b
);

  wire [LANES-1:0]    valid_mask = a_mask & b_mask;
  wire [LANES*PW-1:0] prefix;

  prefix_sum #(.LANES(LANES), .PW(PW)) u_prefix (
      .valid_mask(valid_mask),
      .prefix    (prefix)
  );

  shift_unit #(.DW(DW), .LANES(LANES), .PW(PW)) u_shift (
      .valid_mask(valid_mask),
      .prefix    (prefix),
      .a_values  (a_values),
      .b_values  (b_values),
      .packed_a  (packed_a),
      .packed_b  (packed_b)
  );

endmodule
