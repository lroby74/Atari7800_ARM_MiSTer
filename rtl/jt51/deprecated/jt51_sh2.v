`timescale 1ns / 1ps

module jt51_sh2 #(parameter width=5, stages=32 )
(
	input 							clk,
	input							en,
	input							ld,
	input		[width-1:0]			din,
   	output		[width-1:0]			drop
);

genvar i;
generate
	for( i=0; i<width; i=i+1) begin: shifter
		jt51_sh1 #(.stages(stages)) u_sh1(
			.clk	( clk 	 ),
			.en		( en  	 ),
			.ld		( ld	 ),
			.din	( din[i] ),
			.drop	( drop[i])
		);
	end
endgenerate

endmodule

module jt51_sh1 #(parameter stages=32)
(
	input 	clk,
	input	en,
	input	ld,
	input	din,
   	output	drop
);

reg	[stages-1:0] shift;
assign drop = shift[0];
wire next = ld ? din : drop;

always @(posedge clk )
	if( en )
		shift <= {next, shift[stages-1:1]};

endmodule

