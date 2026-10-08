# SPDX-FileCopyrightText: © 2026 Your Name
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


def expected(a_mask, b_mask, a, b):
    return sum(a[i] * b[i] for i in range(4) if (a_mask >> i) & 1 and (b_mask >> i) & 1)


async def load_byte(dut, value):
    dut.ui_in.value = int(value) & 0xFF
    dut.uio_in.value = 0b001      # load strobe
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 3)


async def run_case(dut, a_mask, b_mask, a, b):
    # 1. Provide a quick clean slate for the control pins
    dut.uio_in.value = 0
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)

    # 2. Pack the masks into a single byte configuration
    await load_byte(dut, (b_mask << 4) | a_mask)
    
    # 3. Extract and merge individual lane elements from the arrays
    await load_byte(dut, (a[1] << 4) | a[0])
    await load_byte(dut, (a[3] << 4) | a[2])
    await load_byte(dut, (b[1] << 4) | b[0])
    await load_byte(dut, (b[3] << 4) | b[2])

    # 4. Fire the start pulse
    dut.uio_in.value = 0b010      # start pulse
    await ClockCycles(dut.clk, 5)
    dut.uio_in.value = 0
    
    # Give the accelerator a few cycles to clear any previous stale done state
    await ClockCycles(dut.clk, 5)

    # 5. Wait / Validate operation success completion flag
    assert (int(dut.uio_out.value) >> 7) & 1 == 1, "done flag not set"

    # 6. Read results out safely
    dut.uio_in.value = 0b000      # byte select 0
    await ClockCycles(dut.clk, 2)
    low = int(dut.uo_out.value)
    
    dut.uio_in.value = 0b100      # byte select 1
    await ClockCycles(dut.clk, 2)
    high = int(dut.uo_out.value)
    
    # 7. Reset control state to force the internal flag to clear for the next loop
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 2)

    return (high << 8) | low


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # 10ns cycle period configuration matches standard 100MHz operations
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    cases = [
        (0b0101, 0b0101, [5, 0, 7, 0], [2, 0, 3, 0]),      # 31
        (0b1111, 0b1111, [3, 4, 5, 6], [1, 2, 3, 4]),      # 50
        (0b1111, 0b0000, [1, 2, 3, 4], [5, 6, 7, 8]),      # 0
        (0b1111, 0b1111, [15] * 4, [15] * 4),              # 900
        (0b1011, 0b1110, [1, 2, 3, 4], [5, 6, 7, 8]),      # 44
    ]

    for a_mask, b_mask, a, b in cases:
        got = await run_case(dut, a_mask, b_mask, a, b)
        want = expected(a_mask, b_mask, a, b)
        dut._log.info(f"A={a} B={b} masks={a_mask:04b},{b_mask:04b} -> {got} (expected {want})")
        assert got == want, f"got {got}, expected {want}"
