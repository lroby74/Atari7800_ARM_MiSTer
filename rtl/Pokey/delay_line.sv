// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from delay_line.vhdl to SystemVerilog-2005.
module delay_line #(
	parameter COUNT = 1
) (
	input  wire CLK,
	input  wire SYNC_RESET,
	input  wire DATA_IN,
	input  wire ENABLE,
	input  wire RESET_N,

	output wire DATA_OUT
);

reg [COUNT-1:0] shift_reg;
reg [COUNT-1:0] shift_next;

always @(posedge CLK or negedge RESET_N) begin
	if (!RESET_N) shift_reg <= {COUNT{1'b0}};
	else          shift_reg <= shift_next;
end

always @* begin
	shift_next = shift_reg;

	if (ENABLE) begin
		shift_next            = shift_reg >> 1;
		shift_next[COUNT-1]   = DATA_IN;
	end

	if (SYNC_RESET) shift_next = {COUNT{1'b0}};
end

assign DATA_OUT = shift_reg[0] & ENABLE;

endmodule

