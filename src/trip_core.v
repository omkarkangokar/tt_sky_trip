/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// TRIP core, 1x1 tile version: 4 lanes x 4 bits, fully combinational.
// result = sum of a[i] * b[i] over the lanes where both masks are 1.
module trip_core #(
    parameter DW    = 4,
    parameter LANES = 4,
    parameter PW    = 2,
    parameter SUM_W = 10
) (
    input  wire [LANES-1:0]    a_mask,
    input  wire [LANES-1:0]    b_mask,
    input  wire [LANES*DW-1:0] a_values,
    input  wire [LANES*DW-1:0] b_values,
    output wire [SUM_W-1:0]    result
);

  wire [LANES*DW-1:0]   packed_a, packed_b;
  wire [LANES*2*DW-1:0] products;

  mfiu #(.DW(DW), .LANES(LANES), .PW(PW)) u_mfiu (
      .a_mask  (a_mask),
      .b_mask  (b_mask),
      .a_values(a_values),
      .b_values(b_values),
      .packed_a(packed_a),
      .packed_b(packed_b)
  );

  multiplier_array #(.DW(DW), .LANES(LANES)) u_mult (
      .a_data  (packed_a),
      .b_data  (packed_b),
      .products(products)
  );

  reduction_tree #(.PROD_W(2*DW), .SUM_W(SUM_W)) u_reduce (
      .products(products),
      .sum     (result)
  );

endmodule
