`default_nettype wire
`timescale 1ns/1ps

// Standalone self-checking Verilog testbench for tt_um_trip_accelerator.
// It drives its own clock, so do NOT use it as test/tb.v in the cocotb flow.
//
// Run:
//   iverilog -g2012 -o sim.out tb_trip_1x1.v ../src/tt_um_trip_accelerator.v ../src/trip_core.v \
//            ../src/mfiu.v ../src/prefix_sum.v ../src/shift_unit.v ../src/multiplier_array.v \
//            ../src/reduction_tree.v
//   vvp sim.out
//
// Pin map:  ui_in = data byte | uio_in[0] = load strobe | uio_in[1] = start
//           uio_in[2] = result byte select | uio_out[7] = done | uo_out = result byte

module tb;

  reg        clk    = 1'b0;
  reg        rst_n  = 1'b0;
  reg        ena    = 1'b1;
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

  // ------------------------------------------------------------------
  // Reference model: sum of a[i]*b[i] over lanes where both masks are 1.
  // a and b hold lane 0 in bits [3:0] up to lane 3 in bits [15:12].
  // ------------------------------------------------------------------
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

  // ------------------------------------------------------------------
  // Basic helpers
  // ------------------------------------------------------------------
  task cyc;                       // wait n clock cycles
    input integer n;
    begin
      repeat (n) @(negedge clk);
    end
  endtask

  task do_reset;
    begin
      rst_n  = 1'b0;
      ui_in  = 8'd0;
      uio_in = 8'd0;
      cyc(10);
      rst_n  = 1'b1;
      cyc(5);
    end
  endtask

  task check;                     // record a pass/fail for one condition
    input         cond;
    input [255:0] msg;
    begin
      tests = tests + 1;
      if (!cond) begin
        errors = errors + 1;
        $display("FAIL: %0s", msg);
      end
    end
  endtask

  // ------------------------------------------------------------------
  // Protocol tasks
  // ------------------------------------------------------------------
  task load_byte;                 // value on ui_in, strobe high for 'hold' cycles
    input [7:0]   value;
    input integer hold;
    input integer gap;
    begin
      @(negedge clk);
      ui_in  = value;
      uio_in = 8'b0000_0001;
      cyc(hold);
      uio_in = 8'b0000_0000;
      cyc(gap);
    end
  endtask

  task load_case;                 // masks, A1A0, A3A2, B1B0, B3B2
    input [3:0]   am;
    input [3:0]   bm;
    input [15:0]  a;
    input [15:0]  b;
    input integer hold;
    input integer gap;
    begin
      load_byte({bm, am}, hold, gap);
      load_byte(a[7:0],   hold, gap);
      load_byte(a[15:8],  hold, gap);
      load_byte(b[7:0],   hold, gap);
      load_byte(b[15:8],  hold, gap);
    end
  endtask

  task press_start;
    input integer width;
    begin
      @(negedge clk);
      uio_in = 8'b0000_0010;
      cyc(width);
      uio_in = 8'b0000_0000;
    end
  endtask

  task wait_done;                 // up to 50 cycles for uio_out[7]
    output ok;
    integer n;
    begin
      ok = 1'b0;
      n  = 0;
      while (!ok && n < 50) begin
        @(negedge clk);
        n = n + 1;
        if (uio_out[7] === 1'b1) ok = 1'b1;
      end
    end
  endtask

  task read_result;               // two bytes, uio[2] selects which
    output [9:0] r;
    reg [7:0] low, high;
    begin
      uio_in = 8'b0000_0000;
      cyc(2);
      low = uo_out;
      uio_in = 8'b0000_0100;
      cyc(2);
      high = uo_out;
      uio_in = 8'b0000_0000;
      check(high[7:2] === 6'd0, "upper bits of the high byte must be 0");
      r = {high[1:0], low};
    end
  endtask

  // ------------------------------------------------------------------
  // One complete case: load, start, wait for done, read, compare
  // ------------------------------------------------------------------
  task run_case;
    input [255:0] name;
    input [3:0]   am;
    input [3:0]   bm;
    input [15:0]  a;
    input [15:0]  b;
    input integer hold;
    input integer gap;
    reg           ok;
    reg [9:0]     got, want;
    begin
      want = model(am, bm, a, b);
      load_case(am, bm, a, b, hold, gap);
      press_start(5);
      wait_done(ok);
      check(ok, "done flag never went high");
      read_result(got);
      tests = tests + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: masks=%b,%b a=%h b=%h  got=%0d expected=%0d",
                 name, am, bm, a, b, got, want);
      end else
        $display("PASS %0s: result=%0d", name, got);
    end
  endtask

  // ------------------------------------------------------------------
  // Test sequence
  // ------------------------------------------------------------------
  integer k, w;
  reg [3:0]  r_am, r_bm;
  reg [15:0] r_a, r_b;

  initial begin
    $dumpfile("tb_trip_1x1.vcd");
    $dumpvars(0, tb);

    do_reset;

    // ---- 1. State after reset ----
    check(uio_oe === 8'b1000_0000, "uio_oe must be 10000000");
    check(uio_out === 8'b0000_0000, "done must be 0 after reset");
    check(uo_out === 8'b0000_0000, "result must be 0 after reset");

    // ---- 2. Directed cases (a and b: lane 3 in the top nibble) ----
    //         name                 am      bm      a(A3..A0)  b(B3..B0)  hold gap
    run_case("sparse 5x2+7x3      ", 4'b0101, 4'b0101, 16'h0705, 16'h0302, 5, 3);  // 31
    run_case("dense 1..4          ", 4'b1111, 4'b1111, 16'h6543, 16'h4321, 5, 3);  // 50
    run_case("no overlap          ", 4'b1111, 4'b0000, 16'h4321, 16'h8765, 5, 3);  // 0
    run_case("maximum 15x15x4     ", 4'b1111, 4'b1111, 16'hFFFF, 16'hFFFF, 5, 3);  // 900
    run_case("partial overlap     ", 4'b1011, 4'b1110, 16'h4321, 16'h8765, 5, 3);  // 44
    run_case("single lane 3       ", 4'b1000, 4'b1000, 16'h9000, 16'h7000, 5, 3);  // 63
    run_case("all zero values     ", 4'b1111, 4'b1111, 16'h0000, 16'h0000, 5, 3);  // 0

    // ---- 3. Done flag behaviour ----
    check(uio_out[7] === 1'b1, "done should stay high until a new byte is loaded");
    load_byte(8'h00, 5, 3);
    check(uio_out[7] === 1'b0, "done must clear when a new byte is loaded");
    check(uio_oe === 8'b1000_0000, "uio_oe must stay 10000000");

    // ---- 4. Recovery: the byte counter is now at 1. A start pulse resets it. ----
    press_start(5);
    cyc(3);
    run_case("after start realign ", 4'b0101, 4'b0101, 16'h0705, 16'h0302, 5, 3);  // 31

    load_byte(8'hFF, 5, 3);              // two stray bytes, then start
    load_byte(8'h12, 5, 3);
    press_start(5);
    cyc(3);
    run_case("after partial load  ", 4'b1011, 4'b1110, 16'h4321, 16'h8765, 5, 3);  // 44

    load_byte(8'hAB, 5, 3);              // reset in the middle of a load
    load_byte(8'hCD, 5, 3);
    do_reset;
    run_case("after reset mid-load", 4'b0101, 4'b0101, 16'h0705, 16'h0302, 5, 3);  // 31

    // ---- 5. Strobe widths 1 to 6 cycles ----
    for (w = 1; w <= 6; w = w + 1)
      run_case("strobe width sweep  ", 4'b1011, 4'b1110, 16'h4321, 16'h8765,
               w, (7 - w < 1) ? 1 : (7 - w));

    // ---- 6. Random cases, back to back ----
    for (k = 0; k < 200; k = k + 1) begin
      r_am = $random;
      r_bm = $random;
      r_a  = $random;
      r_b  = $random;
      run_case("random              ", r_am, r_bm, r_a, r_b, 5, 3);
    end

    $display("----------------------------------------");
    if (errors == 0)
      $display("ALL %0d CHECKS PASSED", tests);
    else
      $display("%0d ERRORS in %0d checks", errors, tests);
    $display("----------------------------------------");
    if (errors != 0) $fatal(1, "Testbench failed");
    $finish;
  end

  // Safety timeout
  initial begin
    #200000000;
    $display("TIMEOUT");
    $fatal(1, "Testbench timeout");
  end

endmodule
