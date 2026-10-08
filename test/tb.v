`default_nettype wire
`timescale 1ns/1ps

// Self-checking testbench for tt_um_trip_accelerator (1x1 tile version).
// Loads operands byte by byte, presses start, reads the 10-bit result
// back in two bytes and compares it with a reference model.

module tb_trip_1x1;

  reg        clk   = 1'b0;
  reg        rst_n = 1'b0;
  reg        ena   = 1'b1;
  reg  [7:0] ui_in  = 8'd0;
  reg  [7:0] uio_in = 8'd0;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  tt_um_trip_accelerator dut (
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  always #5 clk = ~clk;   // 100 MHz in simulation

  integer errors = 0;
  integer tests  = 0;

  // ------------------------------------------------------------
  // Reference model: sum of a[i]*b[i] over lanes where both masks are 1
  // a and b hold lane 0 in bits [3:0] up to lane 3 in bits [15:12]
  // ------------------------------------------------------------
  function [9:0] model;
    input [3:0]  am;
    input [3:0]  bm;
    input [15:0] a;
    input [15:0] b;
    integer i;
    reg [9:0] s;
    begin
      s = 10'd0;
      for (i = 0; i < 4; i = i + 1)
        if (am[i] & bm[i])
          s = s + a[i*4 +: 4] * b[i*4 +: 4];
      model = s;
    end
  endfunction

  // ------------------------------------------------------------
  // Load one byte: put it on ui_in, hold the strobe 5 cycles
  // ------------------------------------------------------------
  task load_byte;
    input [7:0] value;
    begin
      @(negedge clk);
      ui_in      = value;
      uio_in[0]  = 1'b1;
      repeat (5) @(negedge clk);
      uio_in[0]  = 1'b0;
      repeat (3) @(negedge clk);
    end
  endtask

  // ------------------------------------------------------------
  // Run one case and check the result
  // ------------------------------------------------------------
  task run_case;
    input [255:0] name;
    input [3:0]   am;
    input [3:0]   bm;
    input [15:0]  a;
    input [15:0]  b;
    reg   [9:0]   expected;
    reg   [9:0]   got;
    reg   [7:0]   high_byte;
    begin
      expected = model(am, bm, a, b);

      load_byte({bm, am});
      load_byte(a[7:0]);
      load_byte(a[15:8]);
      load_byte(b[7:0]);
      load_byte(b[15:8]);

      // Start pulse
      @(negedge clk);
      uio_in[1] = 1'b1;
      repeat (5) @(negedge clk);
      uio_in[1] = 1'b0;
      repeat (3) @(negedge clk);

      if (uio_out[7] !== 1'b1) begin
        errors = errors + 1;
        $display("FAIL %0s: done flag not set", name);
      end

      // Read result: byte select 0 then 1
      uio_in[2] = 1'b0;
      repeat (2) @(negedge clk);
      got[7:0] = uo_out;

      uio_in[2] = 1'b1;
      repeat (2) @(negedge clk);
      high_byte = uo_out;
      got[9:8]  = high_byte[1:0];
      uio_in[2] = 1'b0;

      if (high_byte[7:2] !== 6'd0) begin
        errors = errors + 1;
        $display("FAIL %0s: upper bits of high byte not zero (%b)", name, high_byte);
      end

      tests = tests + 1;
      if (got !== expected) begin
        errors = errors + 1;
        $display("FAIL %0s: masks=%b,%b a=%h b=%h  got=%0d expected=%0d",
                 name, am, bm, a, b, got, expected);
      end else begin
        $display("PASS %0s: result=%0d (0x%03h)", name, got, got);
      end
    end
  endtask

  // ------------------------------------------------------------
  // Main test sequence
  // ------------------------------------------------------------
  integer k;
  reg [3:0]  r_am, r_bm;
  reg [15:0] r_a, r_b;

  initial begin
    $dumpfile("tb_trip_1x1.vcd");
    $dumpvars(0, tb_trip_1x1);

    // Reset
    rst_n = 1'b0;
    repeat (10) @(negedge clk);
    rst_n = 1'b1;
    repeat (5) @(negedge clk);

    // Pin directions and done flag after reset
    if (uio_oe !== 8'b1000_0000) begin
      errors = errors + 1;
      $display("FAIL: uio_oe = %b, expected 10000000", uio_oe);
    end
    if (uio_out[7] !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL: done flag is set after reset");
    end

    // Directed tests (a and b written lane 3 first, lane 0 last)
    //             name              am      bm      a(A3..A0)  b(B3..B0)
    run_case("sparse 5x2+7x3  ", 4'b0101, 4'b0101, 16'h0705,  16'h0302);  // 31
    run_case("dense  1..4     ", 4'b1111, 4'b1111, 16'h6543,  16'h4321);  // 50
    run_case("no overlap      ", 4'b1111, 4'b0000, 16'h4321,  16'h8765);  // 0
    run_case("maximum 15x15x4 ", 4'b1111, 4'b1111, 16'hFFFF,  16'hFFFF);  // 900
    run_case("partial overlap ", 4'b1011, 4'b1110, 16'h4321,  16'h8765);  // 44
    run_case("single lane 3   ", 4'b1000, 4'b1000, 16'h9000,  16'h7000);  // 63
    run_case("all zero values ", 4'b1111, 4'b1111, 16'h0000,  16'h0000);  // 0

    // Done flag must clear when a new byte is loaded
    load_byte(8'h00);
    if (uio_out[7] !== 1'b0) begin
      errors = errors + 1;
      $display("FAIL: done flag did not clear after loading a new byte");
    end else
      $display("PASS done flag clears on new load");

    // That single byte moved the byte counter to 1. A start pulse resets it
    // to 0, so the next case begins with byte 0 (the mask byte).
    @(negedge clk);
    uio_in[1] = 1'b1;
    repeat (5) @(negedge clk);
    uio_in[1] = 1'b0;
    repeat (3) @(negedge clk);

    // Random tests
    for (k = 0; k < 200; k = k + 1) begin
      r_am = $random;
      r_bm = $random;
      r_a  = $random;
      r_b  = $random;
      run_case("random          ", r_am, r_bm, r_a, r_b);
    end

    $display("----------------------------------------");
    if (errors == 0)
      $display("ALL %0d TESTS PASSED", tests);
    else
      $display("%0d ERRORS in %0d tests", errors, tests);
    $display("----------------------------------------");
    $finish;
  end

  // Safety timeout
  initial begin
    #50000000;
    $display("TIMEOUT");
    $finish;
  end

endmodule
