// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from pokey_poly_4.vhdl to SystemVerilog-2005.
module pokey_poly_4
(
	input        CLK,
	input        RESET_N,
	input        ENABLE,
	input        INIT,

	output       BIT_OUT
);

reg  [3:0] shift_reg;
reg  [3:0] shift_next;

always @(posedge CLK or negedge RESET_N) begin
	if (!RESET_N) shift_reg <= 4'b1010;
	else          shift_reg <= shift_next;
end

always @* begin
	shift_next = shift_reg;
	if (ENABLE) shift_next = {(~^shift_reg[1:0]) & ~INIT, shift_reg[3:1]};
end

assign BIT_OUT = shift_reg[0];

endmodule

