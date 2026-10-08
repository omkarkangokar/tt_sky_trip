/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// For each lane, counts how many valid lanes come before it.
// This is the packed position of that lane's operand pair.
module prefix_sum #(
    parameter LANES = 4,
    parameter PW    = 2             // bits per prefix value = clog2(LANES)
) (
    input  wire [LANES-1:0]    valid_mask,
    output reg  [LANES*PW-1:0] prefix
);

  integer     i;
  reg [PW:0]  count;

  always @(*) begin
    count  = 0;
    prefix = 0;
    for (i = 0; i < LANES; i = i + 1) begin
      prefix[i*PW +: PW] = count[PW-1:0];
      if (valid_mask[i]) count = count + 1;
    end
  end

endmodule
