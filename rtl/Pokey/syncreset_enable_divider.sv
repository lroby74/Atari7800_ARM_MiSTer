// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from syncreset_enable_divider.vhd to SystemVerilog-2005.
module syncreset_enable_divider
#(
	parameter COUNT      = 1,
	parameter RESETCOUNT = 0
)
(
	input      CLK,
	input      SYNCRESET,
	input      RESET_N,
	input      ENABLE_IN,

	output     ENABLE_OUT
);

	function integer log2c(input integer n);
		integer m, p;
		begin
			m = 0;
			p = 1;
			while (p < n) begin
				m = m + 1;
				p = p * 2;
			end
			log2c = m;
		end
	endfunction

	localparam WIDTH = (log2c(COUNT) > 0) ? log2c(COUNT) : 1;
localparam [WIDTH-1:0] ULTIMO     = COUNT - 1;
localparam [WIDTH-1:0] RIPARTENZA = RESETCOUNT;

	reg [WIDTH-1:0] count_reg;
	reg [WIDTH-1:0] count_next;
	reg             enabled_out_reg;
	reg             enabled_out_next;

	always @(posedge CLK or negedge RESET_N) begin
		if (!RESET_N) begin
			count_reg       <= {WIDTH{1'b0}};
			enabled_out_reg <= 1'b0;
		end
		else begin
			count_reg       <= count_next;
			enabled_out_reg <= enabled_out_next;
		end
	end

	always @* begin
		count_next       = count_reg;
		enabled_out_next = enabled_out_reg;

		if (ENABLE_IN) begin
			count_next       = count_reg + 1'b1;
			enabled_out_next = 1'b0;

			if (count_reg == ULTIMO) begin
				count_next       = {WIDTH{1'b0}};
				enabled_out_next = 1'b1;
			end
		end

		if (SYNCRESET) count_next = RIPARTENZA;
	end

	assign ENABLE_OUT = enabled_out_reg & ENABLE_IN;

endmodule

