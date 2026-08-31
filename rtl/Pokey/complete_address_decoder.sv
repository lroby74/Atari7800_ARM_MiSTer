// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from complete_address_decoder.vhdl to SystemVerilog-2005.
module complete_address_decoder
#(
	parameter width = 1
)
(
	input      [width-1:0]      addr_in,

	output reg [(2**width)-1:0] addr_decoded
);

localparam STAGE = width;

reg  [(2**STAGE)-1:0] p [0:STAGE];
wire [width-1:0]      a = addr_in;

integer s, r, i;

always @* begin
	for (s = 0; s <= STAGE; s = s + 1) p[s] = {(2**STAGE){1'b0}};

	p[STAGE][0] = 1'b1;

	for (s = STAGE; s >= 1; s = s - 1)
		for (r = 0; r <= (2**(STAGE-s))-1; r = r + 1) begin
			p[s-1][2*r]   = (~a[s-1]) & p[s][r];
			p[s-1][2*r+1] =   a[s-1]  & p[s][r];
		end

	for (i = 0; i <= (2**STAGE)-1; i = i + 1) addr_decoded[i] = p[0][i];
end

endmodule

