/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Adds the four lane products with a two-level adder tree.
// Written for LANES = 4. Largest sum with DW = 4 is 4 x 15 x 15 = 900,
// which fits in 10 bits.
module reduction_tree #(
    parameter PROD_W = 8,
    parameter SUM_W  = 10
) (
    input  wire [4*PROD_W-1:0] products,
    output wire [SUM_W-1:0]    sum
);

  wire [SUM_W-1:0] p0 = {{(SUM_W-PROD_W){1'b0}}, products[0*PROD_W +: PROD_W]};
  wire [SUM_W-1:0] p1 = {{(SUM_W-PROD_W){1'b0}}, products[1*PROD_W +: PROD_W]};
  wire [SUM_W-1:0] p2 = {{(SUM_W-PROD_W){1'b0}}, products[2*PROD_W +: PROD_W]};
  wire [SUM_W-1:0] p3 = {{(SUM_W-PROD_W){1'b0}}, products[3*PROD_W +: PROD_W]};

  wire [SUM_W-1:0] s0 = p0 + p1;
  wire [SUM_W-1:0] s1 = p2 + p3;

  assign sum = s0 + s1;

endmodule
