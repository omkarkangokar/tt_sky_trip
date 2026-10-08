`default_nettype wire
`timescale 1ns/1ps

// Passive testbench wrapper for cocotb verification
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

  // Generate a basic clock baseline for the simulator environment
  always #5 clk = ~clk;   // 100 MHz baseline

  // VCD wave dumping setup (Fixed escape character syntax error)
  initial begin
    \$dumpfile("tb_trip_1x1.vcd");
    \$dumpvars(0, tb_trip_1x1);
  end

endmodule
