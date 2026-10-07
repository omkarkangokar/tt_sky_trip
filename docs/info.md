<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

TRIP is a sparse dot-product accelerator. It takes two vectors, A and B, each with a mask (1 = the entry is
non-zero), and computes the sum of A[i] x B[i] over the entries that are present in both. Zero entries are skipped.

Example: A = [5, 0, 7, 0] and B = [2, 0, 3, 0] gives 5x2 + 7x3 = 31.

The core is a pipeline run by a controller state machine:

1. **Controller** steps through decode, pack, route, multiply, reduce and write, then raises `done`.
2. **MFIU** takes the masks and values and outputs packed valid operand pairs.
3. **Routing network** sends each valid pair to a multiplier lane.
4. **Multiplier array** multiplies all lanes in parallel.
5. **Reduction tree** adds the products into one 40-bit result.

The core is parameterised by data width and number of lanes (default 16 lanes of 16 bits). Tiny Tapeout has only
8 input and 8 output pins, so this chip uses 4 lanes of 8 bits. A small wrapper loads the operands one byte at a
time and returns the 40-bit result one byte at a time.

| Pin | Direction | Function |
|---|---|---|
| `ui_in[7:0]` | in | Data byte to load |
| `uio[0]` | in | Load strobe |
| `uio[1]` | in | Start |
| `uio[4:2]` | in | Result byte select (0 = lowest byte, 4 = highest) |
| `uio[7]` | out | Done flag |
| `uo_out[7:0]` | out | Selected byte of the 40-bit result |

`uio[5]` and `uio[6]` are unused.

## How to test

1. Reset the chip: hold `rst_n` low, then release it.
2. Load 9 bytes, one at a time. For each byte, put it on `ui_in`, raise `uio[0]` (load strobe), keep the byte
   stable for at least 4 clock cycles, then lower the strobe.

   | Byte | Content |
   |---|---|
   | 0 | `{b_mask[3:0], a_mask[3:0]}` |
   | 1 to 4 | A values, lane 0 to 3 |
   | 5 to 8 | B values, lane 0 to 3 |

3. Pulse `uio[1]` (start) for at least one clock cycle, only after all 9 bytes are loaded.
4. Wait until `uio[7]` (done) goes high.
5. Set `uio[4:2]` to 0, 1, 2, 3 and 4 in turn, and read each result byte from `uo_out`.
   Byte 0 is the lowest 8 bits and byte 4 is the highest 8 bits.

Example (expected result 31): load `0x55`, `0x05 0x00 0x07 0x00`, `0x02 0x00 0x03 0x00`.
After start and done, byte 0 reads `0x1F` (31) and bytes 1 to 4 read `0x00`.

## External hardware

None required. To drive the design you need switches or a microcontroller (such as the one on the Tiny Tapeout
demo board) for the data, strobe, start and select pins. To read the result, use LEDs on `uo_out` and `uio[7]`,
or the microcontroller.
