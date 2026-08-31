// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from synchronizer.vhdl to SystemVerilog-2005.
module synchronizer
(
	input  wire CLK,
	input  wire RAW,
	output wire SYNC
);

	reg  [2:0] ff_reg;
	wire [2:0] ff_next;

	always @(posedge CLK) ff_reg <= ff_next;

	assign ff_next = {RAW, ff_reg[2:1]};

	assign SYNC = ff_reg[0];

endmodule

