# TRIP Sparse Dot-Product Accelerator (1x1 tile)

A sparse dot-product accelerator written in Verilog for the
[Tiny Tapeout](https://tinytapeout.com) SKY130 shuttle, sized for a single 1x1 tile.

It takes two 4-lane, 4-bit vectors with a mask each and computes the sum of
A[i] x B[i] over the lanes where both masks are 1.
Example: A = [5, 0, 7, 0], B = [2, 0, 3, 0] gives 31.

The core is combinational: mask intersection and packing (`mfiu`, `prefix_sum`,
`shift_unit`), parallel multipliers (`multiplier_array`) and an adder tree
(`reduction_tree`). A wrapper loads 5 bytes, captures the 10-bit result on
start and returns it in two bytes.

See `docs/info.md` for the pin list and the step-by-step test procedure.

## Files

| File | Contents |
|---|---|
| `src/tt_um_trip_accelerator.v` | Tiny Tapeout wrapper (byte-wise load and read) |
| `src/trip_core.v` | Core top level |
| `src/mfiu.v`, `prefix_sum.v`, `shift_unit.v` | Matching and packing |
| `src/multiplier_array.v`, `reduction_tree.v` | Multiply and add |
| `test/test.py` | cocotb test |
| `info.yaml` | Tiny Tapeout project settings |

## License

Apache-2.0
