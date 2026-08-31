// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from pokey_poly_5.vhdl to SystemVerilog-2005.
module pokey_poly_5
(
	input        CLK,
	input        RESET_N,
	input        ENABLE,
	input        INIT,

	output       BIT_OUT
);

reg [4:0] shift_reg;
reg [4:0] shift_next;

always @(posedge CLK or negedge RESET_N) begin
	if (!RESET_N) shift_reg <= 5'b01010;
	else          shift_reg <= shift_next;
end

always @* begin
	shift_next = shift_reg;
	if (ENABLE) shift_next = {~^{shift_reg[2], shift_reg[0]} & ~INIT, shift_reg[4:1]};
end

assign BIT_OUT = shift_reg[0];

endmodule

