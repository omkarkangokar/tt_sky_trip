`timescale 1ns/1ps

module trip_top
#(
    parameter int DW    = 16,
    parameter int LANES = 16
)
(
    input  logic clk,
    input  logic rst,
    input  logic start,

    //--------------------------------------------------
    // Sparse input masks
    //--------------------------------------------------

    input  logic [LANES-1:0] a_mask,
    input  logic [LANES-1:0] b_mask,

    //--------------------------------------------------
    // Operand vectors
    //--------------------------------------------------

    input  logic [LANES-1:0][DW-1:0] a_values,
    input  logic [LANES-1:0][DW-1:0] b_values,

    //--------------------------------------------------
    // Output
    //--------------------------------------------------

    output logic [39:0] result,
    output logic done
);

////////////////////////////////////////////////////////
// Controller Signals
////////////////////////////////////////////////////////

logic decode_en;
logic mfiu_en;
logic route_en;
logic mult_en;
logic reduce_en;
logic write_en;

////////////////////////////////////////////////////////
// MFIU Outputs
////////////////////////////////////////////////////////

logic [LANES-1:0] packed_valid;

logic [LANES-1:0][DW-1:0] packed_a;
logic [LANES-1:0][DW-1:0] packed_b;

////////////////////////////////////////////////////////
// Routing Outputs
////////////////////////////////////////////////////////

logic [LANES-1:0] route_valid;

logic [LANES-1:0][DW-1:0] route_a;
logic [LANES-1:0][DW-1:0] route_b;

////////////////////////////////////////////////////////
// Multiplier Outputs
////////////////////////////////////////////////////////

logic [LANES-1:0] mult_valid;

logic [LANES-1:0][31:0] mult_products;

////////////////////////////////////////////////////////
// Reduction Outputs
////////////////////////////////////////////////////////

logic [39:0] reduction_result;
logic        reduction_valid;

////////////////////////////////////////////////////////
// Controller
////////////////////////////////////////////////////////

trip_controller CTRL
(
    .clk(clk),
    .rst(rst),
    .start(start),

    .decode_en(decode_en),
    .mfiu_en(mfiu_en),
    .route_en(route_en),
    .mult_en(mult_en),
    .reduce_en(reduce_en),
    .write_en(write_en),

    .done(done)
);

////////////////////////////////////////////////////////
// MFIU
////////////////////////////////////////////////////////

mfiu
#(
    .DW(DW),
    .LANES(LANES)
)
MFIU
(
    .clk(clk),
    .rst(rst),

    .enable(mfiu_en),

    .a_mask(a_mask),
    .b_mask(b_mask),

    .a_values(a_values),
    .b_values(b_values),

    .packed_valid(packed_valid),

    .packed_a(packed_a),
    .packed_b(packed_b)
);

////////////////////////////////////////////////////////
// Routing Network
////////////////////////////////////////////////////////

route_network
#(
    .DW(DW),
    .LANES(LANES)
)
ROUTER
(
    .clk(clk),
    .rst(rst),

    .enable(route_en),

    .valid_in(packed_valid),

    .a_in(packed_a),
    .b_in(packed_b),

    .valid_out(route_valid),

    .a_out(route_a),
    .b_out(route_b)
);

////////////////////////////////////////////////////////
// Multiplier Array
////////////////////////////////////////////////////////

multiplier_array
#(
    .DW(DW),
    .LANES(LANES)
)
MULT_ARRAY
(
    .clk(clk),
    .rst(rst),

    .valid(route_valid),

    .a_data(route_a),
    .b_data(route_b),

    .valid_out(mult_valid),

    .products(mult_products)
);

////////////////////////////////////////////////////////
// Reduction Tree
////////////////////////////////////////////////////////

reduction_tree
#(
    .DATA_W(32),
    .LANES(LANES)
)
RED_TREE
(
    .clk(clk),
    .rst(rst),

    .valid_in(mult_valid),

    .products(mult_products),

    .sum(reduction_result),

    .valid_out(reduction_valid)
);

////////////////////////////////////////////////////////
// Result Register
////////////////////////////////////////////////////////

always_ff @(posedge clk or posedge rst)
begin
    if(rst)
        result <= '0;
    else if(reduction_valid)
        result <= reduction_result;
    else
        result <= '0;
end

endmodule
