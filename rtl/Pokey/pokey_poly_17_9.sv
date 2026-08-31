// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from pokey_poly_17_9.vhdl to SystemVerilog-2005.
module pokey_poly_17_9
(
	input        CLK,
	input        RESET_N,
	input        ENABLE,
	input        SELECT_9_17,
	input        INIT,

	output       BIT_OUT,

	output [7:0] RAND_OUT
);

reg [16:0] shift_reg;
reg [16:0] shift_next;

reg        cycle_delay_reg;
reg        cycle_delay_next;

reg        select_9_17_del_reg;
reg        select_9_17_del_next;

wire       feedback;

always @(posedge CLK or negedge RESET_N) begin
	if (!RESET_N) begin
		shift_reg           <= 17'b01010101010101010;
		cycle_delay_reg     <= 1'b0;
		select_9_17_del_reg <= 1'b0;
	end
	else begin
		shift_reg           <= shift_next;
		cycle_delay_reg     <= cycle_delay_next;
		select_9_17_del_reg <= select_9_17_del_next;
	end
end

assign feedback = ~^{shift_reg[13], shift_reg[8]};

always @* begin
	shift_next           = shift_reg;
	cycle_delay_next     = cycle_delay_reg;
	select_9_17_del_next = select_9_17_del_reg;

	if (ENABLE) begin
		select_9_17_del_next = SELECT_9_17;
		shift_next[15:8]     = shift_reg[16:9];
		shift_next[7]        = feedback;
		shift_next[6:0]      = shift_reg[7:1];

		shift_next[16]       = ((feedback & select_9_17_del_reg) | (shift_reg[0] & ~SELECT_9_17)) & ~INIT;

		cycle_delay_next     = shift_reg[9];
	end
end

assign BIT_OUT  = cycle_delay_reg;
assign RAND_OUT = ~shift_reg[15:8];

endmodule

