// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from pokey_noise_filter.vhdl to SystemVerilog-2005.
module pokey_noise_filter
(
	input        CLK,
	input        RESET_N,

	input  [2:0] NOISE_SELECT,

	input        PULSE_IN,

	input        NOISE_4,
	input        NOISE_5,
	input        NOISE_LARGE,

	input        SYNC_RESET,

	output       PULSE_OUT
);

reg audclk;
reg out_next;
reg out_reg;

always @(posedge CLK or negedge RESET_N) begin
	if (!RESET_N) out_reg <= 1'b0;
	else          out_reg <= out_next;
end

assign PULSE_OUT = out_reg;

always @* begin
	audclk   = PULSE_IN;
	out_next = out_reg;

	if (NOISE_SELECT[2] == 1'b0) audclk = PULSE_IN & NOISE_5;

	if (audclk) begin
		if (NOISE_SELECT[0]) out_next = ~out_reg;
		else                 out_next = NOISE_SELECT[1] ? NOISE_4 : NOISE_LARGE;
	end

	if (SYNC_RESET) out_next = 1'b0;
end

endmodule

