`timescale 1ns / 1ps

module jt51_fir_ram
#(parameter data_width=8, parameter addr_width=7)
(
	input [(data_width-1):0] data,
	input [(addr_width-1):0] addr,
	input we, clk,
	output [(data_width-1):0] q
);

(* ramstyle = "no_rw_check" *) reg [data_width-1:0] ram[2**addr_width-1:0];

	reg [addr_width-1:0] addr_reg;

	always @ (posedge clk) begin
		if (we)
			ram[addr] <= data;
		addr_reg <= addr;
	end

	assign q = ram[addr_reg];
endmodule

