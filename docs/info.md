<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

TRIP is a sparse dot-product accelerator. It takes two vectors, A and B, each with 4 lanes of 4 bits and a 4-bit
mask (1 = the entry is non-zero). It computes the sum of A[i] x B[i] over the lanes where both masks are 1.
Zero entries are skipped.

Example: A = [5, 0, 7, 0] and B = [2, 0, 3, 0] gives 5x2 + 7x3 = 31.

The core is purely combinational:

1. **MFIU** ANDs the two masks to find the lanes that match, then packs the matching operand pairs to the low
   lanes (using a prefix sum for each lane's position and a shift unit to move the data).
2. **Multiplier array** multiplies each packed pair. Unused lanes are zero, so they add nothing.
3. **Reduction tree** adds the four products into one 10-bit result (the largest possible sum is 4 x 15 x 15 = 900).

A small wrapper loads the operands one byte at a time, captures the result when you press start, and returns
the result one byte at a time.

| Pin | Direction | Function |
|---|---|---|
| `ui_in[7:0]` | in | Data byte to load |
| `uio[0]` | in | Load strobe |
| `uio[1]` | in | Start |
| `uio[2]` | in | Result byte select (0 = bits 7:0, 1 = bits 9:8) |
| `uio[7]` | out | Done flag |
| `uo_out[7:0]` | out | Selected byte of the 10-bit result |

`uio[3]` to `uio[6]` are unused.

## How to test

1. Reset the chip: hold `rst_n` low, then release it.
2. Load 5 bytes, one at a time. For each byte, put it on `ui_in`, raise `uio[0]` (load strobe), keep the byte
   stable for at least 4 clock cycles, then lower the strobe.

   | Byte | Content |
   |---|---|
   | 0 | `{b_mask[3:0], a_mask[3:0]}` |
   | 1 | `{A1, A0}` |
   | 2 | `{A3, A2}` |
   | 3 | `{B1, B0}` |
   | 4 | `{B3, B2}` |

3. Pulse `uio[1]` (start) for at least one clock cycle, after the last byte is loaded.
4. `uio[7]` (done) goes high. Done clears again when you load a new byte.
5. Set `uio[2]` to 0 and read the low byte from `uo_out`. Set it to 1 and read bits 9:8 (the value is 0 to 3).

Example (expected result 31): load `0x55`, `0x05`, `0x07`, `0x02`, `0x03`. After start, the low byte reads
`0x1F` and the high byte reads `0x00`.

Another example: all masks 1 and all values 15 gives 900, so the low byte reads `0x84` and the high byte `0x03`.

## External hardware

None required. To drive the design you need switches or a microcontroller (such as the one on the Tiny Tapeout
demo board) for the data, strobe, start and select pins. To read the result, use LEDs on `uo_out` and `uio[7]`,
or the microcontroller.
