// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from latch_delay_line.vhdl to SystemVerilog-2005.
module latch_delay_line #(parameter COUNT = 1)
(
	input             CLK,
	input             SYNC_RESET,
	input             DATA_IN,
	input             ENABLE,
	input             RESET_N,

	output            DATA_OUT
);

reg  [COUNT-1:0] shift_reg;
reg  [COUNT-1:0] shift_next;
reg              data_in_reg;
reg              data_in_next;

always @(posedge CLK or negedge RESET_N) begin
	if (!RESET_N) begin
		shift_reg   <= {COUNT{1'b0}};
		data_in_reg <= 1'b0;
	end
	else begin
		shift_reg   <= shift_next;
		data_in_reg <= data_in_next;
	end
end

always @* begin
	shift_next   = shift_reg;
	data_in_next = DATA_IN | data_in_reg;

	if (ENABLE) begin
		shift_next   = {(DATA_IN | data_in_reg), shift_reg} >> 1;
		data_in_next = 1'b0;
	end

	if (SYNC_RESET) begin
		shift_next   = {COUNT{1'b0}};
		data_in_next = 1'b0;
	end
end

assign DATA_OUT = shift_reg[0] & ENABLE;

endmodule

