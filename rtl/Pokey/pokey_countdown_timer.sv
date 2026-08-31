// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from pokey_countdown_timer.vhdl to SystemVerilog-2005.
module pokey_countdown_timer #(
	parameter UNDERFLOW_DELAY = 3
) (
	input             CLK,
	input             ENABLE,
	input             ENABLE_UNDERFLOW,
	input             RESET_N,

	input             WR_EN,
	input       [7:0] DATA_IN,

	output            DATA_OUT
);

reg  [7:0] count_reg;
reg  [7:0] count_next;

reg        underflow;

reg  [1:0] count_command;
reg  [1:0] underflow_command;

delay_line #(.COUNT(UNDERFLOW_DELAY)) underflow0_delay (
	.CLK        (CLK),
	.SYNC_RESET (WR_EN),
	.DATA_IN    (underflow),
	.ENABLE     (ENABLE_UNDERFLOW),
	.RESET_N    (RESET_N),
	.DATA_OUT   (DATA_OUT)
);

always @(posedge CLK or negedge RESET_N) begin
	if (!RESET_N) count_reg <= 8'h00;
	else          count_reg <= count_next;
end

always @* begin
	count_command = {ENABLE, WR_EN};
	case (count_command)
		2'b10       : count_next = count_reg - 8'd1;
		2'b01,2'b11 : count_next = DATA_IN;
		default     : count_next = count_reg;
	endcase
end

always @* begin
	underflow_command = {ENABLE, (count_reg == 8'h00)};
	case (underflow_command)
		2'b11   : underflow = 1'b1;
		default : underflow = 1'b0;
	endcase
end

endmodule

