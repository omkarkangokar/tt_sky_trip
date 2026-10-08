/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// One multiplier per lane. Unused lanes carry zeros after packing,
// so their product is zero and no valid gating is needed.
module multiplier_array #(
    parameter DW    = 4,
    parameter LANES = 4
) (
    input  wire [LANES*DW-1:0]   a_data,
    input  wire [LANES*DW-1:0]   b_data,
    output wire [LANES*2*DW-1:0] products
);

  genvar i;
  generate
    for (i = 0; i < LANES; i = i + 1) begin : g_mult
      assign products[i*2*DW +: 2*DW] = a_data[i*DW +: DW] * b_data[i*DW +: DW];
    end
  endgenerate

endmodule
