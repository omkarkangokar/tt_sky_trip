/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_trip_accelerator (
    input  wire [7:0] ui_in,    // Dedicated inputs: data byte to load
    output wire [7:0] uo_out,   // Dedicated outputs: selected result byte
    input  wire [7:0] uio_in,   // IOs: Input path (load strobe, start, byte select)
    output wire [7:0] uio_out,  // IOs: Output path (done flag on bit 7)
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  localparam DW     = 4;
  localparam LANES  = 4;
  localparam SUM_W  = 10;
  localparam NBYTES = 5;   // mask byte + 2 bytes of A + 2 bytes of B

  wire rst = ~rst_n;

  // Synchronise and edge-detect the load strobe (uio[0]) and start (uio[1])
  reg [1:0] wr_sync, start_sync;
  reg       wr_prev, start_prev;

  always @(posedge clk) begin
    if (rst) begin
      wr_sync    <= 2'b00;
      start_sync <= 2'b00;
      wr_prev    <= 1'b0;
      start_prev <= 1'b0;
    end else begin
      wr_sync    <= {wr_sync[0],    uio_in[0]};
      start_sync <= {start_sync[0], uio_in[1]};
      wr_prev    <= wr_sync[1];
      start_prev <= start_sync[1];
    end
  end

  wire wr_rise    = wr_sync[1]    & ~wr_prev;
  wire start_rise = start_sync[1] & ~start_prev;

  // Operand registers, loaded one byte per load strobe
  //   byte 0: {b_mask[3:0], a_mask[3:0]}
  //   byte 1: {a1, a0}     byte 2: {a3, a2}
  //   byte 3: {b1, b0}     byte 4: {b3, b2}
  reg [2:0]          idx;
  reg [LANES-1:0]    a_mask, b_mask;
  reg [LANES*DW-1:0] a_flat, b_flat;

  always @(posedge clk) begin
    if (rst) begin
      idx    <= 3'd0;
      a_mask <= {LANES{1'b0}};
      b_mask <= {LANES{1'b0}};
    end else if (start_rise) begin
      idx <= 3'd0;
    end else if (wr_rise) begin
      case (idx)
        3'd0: begin
          a_mask <= ui_in[3:0];
          b_mask <= ui_in[7:4];
        end
        3'd1: a_flat[7:0]  <= ui_in;
        3'd2: a_flat[15:8] <= ui_in;
        3'd3: b_flat[7:0]  <= ui_in;
        3'd4: b_flat[15:8] <= ui_in;
        default: ;
      endcase
      idx <= (idx == NBYTES-1) ? 3'd0 : idx + 3'd1;
    end
  end

  // TRIP core (combinational)
  wire [SUM_W-1:0] core_result;

  trip_core #(
      .DW   (DW),
      .LANES(LANES),
      .PW   (2),
      .SUM_W(SUM_W)
  ) core (
      .a_mask  (a_mask),
      .b_mask  (b_mask),
      .a_values(a_flat),
      .b_values(b_flat),
      .result  (core_result)
  );

  // Capture the result on start and hold it until the next start
  reg [SUM_W-1:0] result_reg;
  reg             done_flag;

  always @(posedge clk) begin
    if (rst || wr_rise) begin
      done_flag <= 1'b0;
      if (rst) result_reg <= {SUM_W{1'b0}};
    end else if (start_rise) begin
      result_reg <= core_result;
      done_flag  <= 1'b1;
    end
  end

  // Result byte select (uio[2]): 0 = bits 7:0, 1 = bits 9:8
  wire sel = uio_in[2];

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = sel ? {{(16-SUM_W){1'b0}}, result_reg[SUM_W-1:8]} : result_reg[7:0];
  assign uio_out = {done_flag, 7'b0};
  assign uio_oe  = 8'b1000_0000;  // only uio[7] (done) is an output

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, uio_in[7:3], 1'b0};

endmodule
