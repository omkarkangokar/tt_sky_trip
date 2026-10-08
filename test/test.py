# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
   
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Test project behavior")

    # ==========================================
    # TEST CASE 1: Expected Result = 31
    # ==========================================
    dut._log.info("Running Case 1...")
    
    # Load Masks: 0b0101 (bm) and 0b0101 (am) -> 0x55
    dut.ui_in.value = 0x55
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Load A lanes 0 and 1: [5, 0] -> 0x05
    dut.ui_in.value = 0x05
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Load A lanes 2 and 3: [7, 0] -> 0x07
    dut.ui_in.value = 0x07
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Load B lanes 0 and 1: [2, 0] -> 0x02
    dut.ui_in.value = 0x02
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Load B lanes 2 and 3: [3, 0] -> 0x03
    dut.ui_in.value = 0x03
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Pulse Start signal
    dut.uio_in.value = 0b010
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)

    # Check Done Flag (bit 7 of uio_out)
    assert (int(dut.uio_out.value) >> 7) & 1 == 1, "Case 1 done flag not set"

    # Read low byte (byte select = 0b000)
    dut.uio_in.value = 0b000
    await ClockCycles(dut.clk, 2)
    low_byte = int(dut.uo_out.value)

    # Read high byte (byte select = 0b100)
    dut.uio_in.value = 0b100
    await ClockCycles(dut.clk, 2)
    high_byte = int(dut.uo_out.value)
    
    # Clear control pins and verify total calculated value
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 2)
    
    got_1 = (high_byte << 8) | low_byte
    assert got_1 == 31, f"Case 1 failed: got {got_1}, expected 31"


    # ==========================================
    # TEST CASE 2: Expected Result = 50
    # ==========================================
    dut._log.info("Running Case 2...")
    
    # Load Masks: 0b1111 (bm) and 0b1111 (am) -> 0xFF
    dut.ui_in.value = 0xFF
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Load A lanes 0 and 1: [3, 4] -> 0x43
    dut.ui_in.value = 0x43
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Load A lanes 2 and 3: [5, 6] -> 0x65
    dut.ui_in.value = 0x65
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Load B lanes 0 and 1: [1, 2] -> 0x21
    dut.ui_in.value = 0x21
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Load B lanes 2 and 3: [3, 4] -> 0x43
    dut.ui_in.value = 0x43
    dut.uio_in.value = 0b001
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)

    # Pulse Start signal
    dut.uio_in.value = 0b010
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)

    # Check Done Flag
    assert (int(dut.uio_out.value) >> 7) & 1 == 1, "Case 2 done flag not set"

    # Read low byte
    dut.uio_in.value = 0b000
    await ClockCycles(dut.clk, 2)
    low_byte = int(dut.uo_out.value)

    # Read high byte
    dut.uio_in.value = 0b100
    await ClockCycles(dut.clk, 2)
    high_byte = int(dut.uo_out.value)
    
    # Clear control pins and verify total calculated value
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 2)
    
    got_2 = (high_byte << 8) | low_byte
    assert got_2 == 50, f"Case 2 failed: got {got_2}, expected 50"

    dut._log.info("All manual template tests passed successfully!")
