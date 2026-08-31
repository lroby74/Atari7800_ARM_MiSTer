module ps2
(
	input 		  clk,
	input         ce,
	input 		  reset,

	input  [10:0] ps2_key,
	output reg [7:0] matrix[14:0],

	input  [24:0] ps2_mouse,
	input   [7:0] ps2_mouse_ext,
	output  [6:0] mouse_atari,

	output reg joy_port_toggle
);

wire [7:0] kbd_sr = ps2_key[7:0];
wire       kbd_release = ~ps2_key[9];
wire       kbd_ext = ps2_key[8];
reg        mouse_z_up_d, mouse_z_down_d;

always @(posedge clk) if (ce) begin
	reg old_stb;

	old_stb <= ps2_key[10];

   if (reset) begin
      joy_port_toggle <= 1'b0;

      mouse_z_up_d <= 1'b0;
      mouse_z_down_d <= 1'b0;

      matrix[ 0] <= 8'hff; matrix[ 1] <= 8'hff; matrix[ 2] <= 8'hff; matrix[ 3] <= 8'hff;
      matrix[ 4] <= 8'hff; matrix[ 5] <= 8'hff; matrix[ 6] <= 8'hff; matrix[ 7] <= 8'hff;
      matrix[ 8] <= 8'hff; matrix[ 9] <= 8'hff; matrix[10] <= 8'hff; matrix[11] <= 8'hff;
      matrix[12] <= 8'hff; matrix[13] <= 8'hff; matrix[14] <= 8'hff;
   end
	else begin

		mouse_z_up_d <= mouse_z_up;
		mouse_z_down_d <= mouse_z_down;

		if (mouse_z_up ^ mouse_z_up_d)     matrix[12][1] <= ~mouse_z_up;
		if (mouse_z_down ^ mouse_z_down_d) matrix[12][4] <= ~mouse_z_down;

		if(old_stb != ps2_key[10]) begin

			if(!kbd_ext) begin

				if(kbd_sr[7:0] == 8'h1c) matrix[ 4][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h32) matrix[ 7][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h21) matrix[ 6][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h23) matrix[ 5][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h24) matrix[ 5][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h2b) matrix[ 6][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h34) matrix[ 7][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h33) matrix[ 7][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h43) matrix[ 8][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h3b) matrix[ 8][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h42) matrix[ 8][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h4b) matrix[ 9][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h3a) matrix[ 8][7] <= kbd_release;
				if(kbd_sr[7:0] == 8'h31) matrix[ 7][7] <= kbd_release;
				if(kbd_sr[7:0] == 8'h44) matrix[ 9][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h4d) matrix[ 9][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h15) matrix[ 4][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h2d) matrix[ 6][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h1b) matrix[ 5][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h2c) matrix[ 6][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h3c) matrix[ 8][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h2a) matrix[ 6][7] <= kbd_release;
				if(kbd_sr[7:0] == 8'h1d) matrix[ 5][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h22) matrix[ 5][7] <= kbd_release;
				if(kbd_sr[7:0] == 8'h35) matrix[ 7][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h1a) matrix[ 4][7] <= kbd_release;

				if(kbd_sr[7:0] == 8'h16) matrix[ 4][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h1e) matrix[ 5][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h26) matrix[ 5][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h25) matrix[ 6][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h2e) matrix[ 6][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h36) matrix[ 7][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h3d) matrix[ 7][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h3e) matrix[ 8][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h46) matrix[ 8][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h45) matrix[ 9][1] <= kbd_release;

				if(kbd_sr[7:0] == 8'h05) matrix[ 1][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h06) matrix[ 2][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h04) matrix[ 3][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h0c) matrix[ 4][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h03) matrix[ 5][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h0b) matrix[ 6][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h83) matrix[ 7][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h0a) matrix[ 8][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h01) matrix[ 9][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h09) matrix[10][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h78 && kbd_release) joy_port_toggle <= ~joy_port_toggle;

				if(kbd_sr[7:0] == 8'h5a) matrix[11][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h29) matrix[ 9][7] <= kbd_release;
				if(kbd_sr[7:0] == 8'h76) matrix[ 4][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h66) matrix[11][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h0d) matrix[ 4][3] <= kbd_release;

				if(kbd_sr[7:0] == 8'h7c) matrix[14][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h7b) matrix[14][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h79) matrix[14][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h70) matrix[12][7] <= kbd_release;
				if(kbd_sr[7:0] == 8'h69) matrix[12][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h72) matrix[13][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h7a) matrix[14][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h6b) matrix[13][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h73) matrix[13][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h74) matrix[14][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h6c) matrix[13][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h75) matrix[13][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h7d) matrix[14][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h71) matrix[13][7] <= kbd_release;

				if(kbd_sr[7:0] == 8'h0e) matrix[10][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h4e) matrix[ 9][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h55) matrix[10][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h54) matrix[10][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h5b) matrix[10][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h5d) matrix[11][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h4c) matrix[10][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h52) matrix[11][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h41) matrix[ 9][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h49) matrix[10][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h4a) matrix[11][7] <= kbd_release;
				if(kbd_sr[7:0] == 8'h61) matrix[ 4][6] <= kbd_release;

				if(kbd_sr[7:0] == 8'h12) matrix[ 1][5] <= kbd_release;
				if(kbd_sr[7:0] == 8'h59) matrix[ 3][7] <= kbd_release;
				if(kbd_sr[7:0] == 8'h11) matrix[ 2][6] <= kbd_release;
				if(kbd_sr[7:0] == 8'h14) matrix[ 0][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h58) matrix[10][7] <= kbd_release;

			end else begin

				if(kbd_sr[7:0] == 8'h14) matrix[ 0][4] <= kbd_release;

				if(kbd_sr[7:0] == 8'h75) matrix[12][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h72) matrix[12][4] <= kbd_release;
				if(kbd_sr[7:0] == 8'h6b) matrix[12][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h74) matrix[12][5] <= kbd_release;

				if(kbd_sr[7:0] == 8'h4a) matrix[14][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h5a) matrix[14][7] <= kbd_release;

				if(kbd_sr[7:0] == 8'h70) matrix[11][3] <= kbd_release;
				if(kbd_sr[7:0] == 8'h6c) matrix[12][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h7d) matrix[11][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h71) matrix[11][2] <= kbd_release;
				if(kbd_sr[7:0] == 8'h7c) matrix[13][0] <= kbd_release;
				if(kbd_sr[7:0] == 8'h69) matrix[13][1] <= kbd_release;
				if(kbd_sr[7:0] == 8'h7a) matrix[12][0] <= kbd_release;
			end
		end
	end
end

reg [8:0] mouse_x;
reg [8:0] mouse_y;
reg[15:0] mouse_z;
reg [1:0] mouse_x_cnt;
reg [1:0] mouse_y_cnt;
reg [9:0] mouse_ev_cnt;
reg       mouse_z_up;
reg       mouse_z_down;

assign mouse_atari = { ps2_mouse[2:0], mouse_y_cnt, mouse_x_cnt };

always @(posedge clk) if (ce) begin
	reg old_stb;

	old_stb <= ps2_mouse[24];

	if (reset) begin
		mouse_x <= 0;
		mouse_y <= 0;
		mouse_z <= 0;

		mouse_x_cnt <= 0;
		mouse_y_cnt <= 0;
		mouse_ev_cnt <= 0;
	end else begin

		mouse_ev_cnt <= mouse_ev_cnt + 1'd1;
		if(!mouse_ev_cnt) begin

			if(mouse_x[8]) begin

				mouse_x <= mouse_x + 1'd1;

				mouse_x_cnt[0] <= ~mouse_x_cnt[1];
				mouse_x_cnt[1] <=  mouse_x_cnt[0];
			end
			else if(mouse_x[7:0]) begin

				mouse_x <= mouse_x - 1'd1;

				mouse_x_cnt[0] <=  mouse_x_cnt[1];
				mouse_x_cnt[1] <= ~mouse_x_cnt[0];
			end

			if(mouse_y[8]) begin

				mouse_y <= mouse_y + 1'd1;

				mouse_y_cnt[0] <= ~mouse_y_cnt[1];
				mouse_y_cnt[1] <=  mouse_y_cnt[0];
			end
			else if(mouse_y[7:0]) begin

				mouse_y <= mouse_y - 1'd1;

				mouse_y_cnt[0] <=  mouse_y_cnt[1];
				mouse_y_cnt[1] <= ~mouse_y_cnt[0];
			end

			if(mouse_z[15]) begin

				mouse_z <= mouse_z + 1'd1;
				mouse_z_up <= ~mouse_z[7];
			end else if(mouse_z) begin

				mouse_z <= mouse_z - 1'd1;
				mouse_z_down <= mouse_z[7];
			end else begin
				mouse_z_up <= 0;
				mouse_z_down <= 0;
			end
      end

		if(old_stb != ps2_mouse[24]) begin
			mouse_x <=  { ps2_mouse[4], ps2_mouse[15:8] };
			mouse_y <= ~{ ps2_mouse[5], ps2_mouse[23:16]} + 1'd1;
			if(ps2_mouse_ext) mouse_z <= {ps2_mouse_ext, 8'd0};
		end
	end
end

endmodule

