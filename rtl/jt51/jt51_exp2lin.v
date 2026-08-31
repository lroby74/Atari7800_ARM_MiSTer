module jt51_exp2lin(
  output	reg signed 	[15:0] 	lin,
  input 		signed	[9:0] 	man,
  input			[2:0] 	exp
);

always @(*) begin
	case( exp )
		3'd7: lin = { man, 6'b0 };
		3'd6: lin = { {1{man[9]}}, man, 5'b0 };
		3'd5: lin = { {2{man[9]}}, man, 4'b0 };
		3'd4: lin = { {3{man[9]}}, man, 3'b0 };
		3'd3: lin = { {4{man[9]}}, man, 2'b0 };
		3'd2: lin = { {5{man[9]}}, man, 1'b0 };
		3'd1: lin = { {6{man[9]}}, man };
		3'd0: lin = 16'd0;
	endcase
end

endmodule

