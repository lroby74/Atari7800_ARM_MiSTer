// k7800 (c) by Jamie Blanks

// k7800 is licensed under a
// Creative Commons Attribution-NonCommercial 4.0 International License.

// You should have received a copy of the license along with this
// work. If not, see http://creativecommons.org/licenses/by-nc/4.0/.
module paddle_select
(
	input       clk,
	input [7:0] value,
	output      select
);
	logic [7:0] last_value;
	always_ff @(posedge clk) begin
		last_value <= value;
		if (last_value != value && (&value[7:6] || ~|value[7:6]))
			select <= 1;
		else
			select <= 0;
	end
endmodule

module paddle_chooser
(
	input   logic                   clk,
	input   logic                   reset,
	input   logic   [3:0]           mask,
	input   logic                   enable0,
	input   logic                   enable1,
	input   logic                   use_multi,

	input   logic   [24:0]          mouse,
	input   logic   [3:0][15:0]     analog,
	input   logic   [3:0][7:0]      paddle,
	input   logic   [3:0]           buttons_in,
	input   logic   [3:0]           alt_b_in,

	output  logic   [3:0]           assigned,
	output  logic   [3:0][7:0]      pd_out,
	output  logic   [3:0][3:0]      paddle_type,
	output  logic   [3:0]           paddle_but
);

	logic [3:0] xs_assigned, ys_assigned, pdi_assigned, paddle_assigned, output_assigned;
	logic mouse_assigned;
	logic [1:0] types[4];
	logic [1:0] index[4];
	logic [3:0] analog_axis;
	logic mouse_button;
	logic [3:0][7:0] xs_unsigned;
	logic [3:0][7:0] ys_unsigned;
	logic [3:0] xs_select, ys_select, p_select;

	assign xs_unsigned[0] = {~analog[0][7], analog[0][6:0]};
	assign xs_unsigned[1] = {~analog[1][7], analog[1][6:0]};
	assign xs_unsigned[2] = {~analog[2][7], analog[2][6:0]};
	assign xs_unsigned[3] = {~analog[3][7], analog[3][6:0]};

	assign ys_unsigned[0] = {~analog[0][15], analog[0][14:8]};
	assign ys_unsigned[1] = {~analog[1][15], analog[1][14:8]};
	assign ys_unsigned[2] = {~analog[2][15], analog[2][14:8]};
	assign ys_unsigned[3] = {~analog[3][15], analog[3][14:8]};

	paddle_select pdjx0(clk, xs_unsigned[0], xs_select[0]);
	paddle_select pdjx1(clk, xs_unsigned[1], xs_select[1]);
	paddle_select pdjx2(clk, xs_unsigned[2], xs_select[2]);
	paddle_select pdjx3(clk, xs_unsigned[3], xs_select[3]);

	paddle_select pdjy0(clk, ys_unsigned[0], ys_select[0]);
	paddle_select pdjy1(clk, ys_unsigned[1], ys_select[1]);
	paddle_select pdjy2(clk, ys_unsigned[2], ys_select[2]);
	paddle_select pdjy3(clk, ys_unsigned[3], ys_select[3]);

	paddle_select pdp0(clk, paddle[0], p_select[0]);
	paddle_select pdp1(clk, paddle[1], p_select[1]);
	paddle_select pdp2(clk, paddle[2], p_select[2]);
	paddle_select pdp3(clk, paddle[3], p_select[3]);

	logic [3:0][15:0] old_analog;
	logic [3:0][7:0] old_paddle;
	logic [3:0] use_alt_buttons;
	logic old_stb;
	reg  signed [8:0] mx = 0;
	wire signed [8:0] mdx = {mouse[4],mouse[15:8]};
	wire signed [8:0] mdx2 = (mdx > 64) || (mouse[6] && ~mouse[4]) ? 9'd64 : (mdx < -64) || (mouse[6] && mouse[4]) ? -8'd64 : mdx;
	wire signed [8:0] nmx = mx + mdx2;

	assign mouse_button = mouse[0];

	always_comb begin
		paddle_but = 4'b0000;
		for (logic [2:0] x = 0; x < 3'd4; x = x + 2'd1) begin
			pd_out[x] = 8'd0;
			if (output_assigned[x]) begin
				case (paddle_type[x])
					0: begin pd_out[x] = ~paddle[index[x]]; paddle_but[x] = buttons_in[index[x]]; end
					1: begin pd_out[x] = ~(analog_axis[x] ? xs_unsigned[index[x]][7:0] : ys_unsigned[index[x]][7:0]); paddle_but[x] = ~use_alt_buttons[x] ? buttons_in[index[x]] : alt_b_in[index[x]]; end
					2: begin pd_out[x] = ~{~mx[7], mx[6:0]}; paddle_but[x] = mouse_button | ((~xs_assigned[0] & ~ys_assigned[0]) ? buttons_in[0] : 1'b0); end
					default: ;
				endcase
			end
		end
	end

	always @(posedge clk) begin
		reg current_assign;
		assigned <= '0;
		current_assign = 0;
		for (logic [2:0] y = 0; y < 3'd4; y = y + 2'd1) begin
			if (~output_assigned[y] && ((y==0 || ~mask[y[1:0]-1'd1]) ? 1'b1 : output_assigned[y[1:0]-1'd1]) && mask[y] && ~current_assign) begin
				for (logic [2:0] x = 0; x < 3'd4; x = x + 2'd1) begin
					if (xs_select[x] && ~xs_assigned[x]) begin
						assigned[y] <= 1;
						xs_assigned[x] <= 1;
						current_assign = 1;
						ys_assigned[x] <= ~use_multi | ys_assigned[x];
						output_assigned[y] <= 1;
						paddle_type[y] <= 1;
						index[y] <= x[1:0];
						analog_axis[y] <= 1;
					end
				end
				for (logic [2:0] x = 0; x < 3'd4; x = x + 2'd1) begin
					if (ys_select[x] && ~ys_assigned[x]) begin
						assigned[y] <= 1;
						ys_assigned[x] <= 1;
						xs_assigned[x] <= ~use_multi | xs_assigned[x];
						current_assign = 1;
						output_assigned[y] <= 1;
						use_alt_buttons[y] <= use_multi;
						paddle_type[y] <= 1;
						analog_axis[y] <= 0;
						index[y] <= x[1:0];
					end
				end
				for (logic [2:0] x = 0; x < 3'd4; x = x + 2'd1) begin
					if (p_select[x] && ~pdi_assigned[x]) begin
						assigned[y] <= 1;
						pdi_assigned[x] <= 1;
						current_assign = 1;
						output_assigned[y] <= 1;
						paddle_type[y] <= 0;
						index[y] <= x[1:0];
					end
				end
				if (~mouse_assigned && mouse_button) begin
					assigned[y] <= 1;
					mouse_assigned <= 1;
					current_assign = 1;
					output_assigned[y] <= 1;
					paddle_type[y] <= 2;
					index[y] <= 0;
				end
			end
		end
		old_stb <= mouse[24];
		if(old_stb != mouse[24]) begin
			mx <= (nmx < -128) ? -9'd128 : (nmx > 127) ? 9'd127 : nmx;
		end

		if (reset) begin
			mouse_assigned <= 0;
			assigned <= '0;
			index <= '{2'd0, 2'd0, 2'd0, 2'd0};
			pdi_assigned <= '0;
			xs_assigned <= '0;
			ys_assigned <= '0;
			output_assigned <= '0;
			use_alt_buttons <= '0;
			paddle_type <= '0;
		end
	end
endmodule

module paddle_timer (
	input clk,
	input ce,
	input reset,
	input [9:0] kohms,
	input clear,
	input read,
	output charged,
	output logic [33:0] difference
);

parameter NS_PER_TICK = 33'd6984;

localparam CLEAR_NS = 33'd3352320;

logic [32:0] clear_count, high_count, lowest, highest;

logic [1:0] read_count;
logic old_read;
wire read_measured = &read_count;
logic [32:0] width = 0;
logic cleared = 0;

always @(posedge clk) if (ce) begin
	old_read <= clear;
	if (~read_measured && (clear && ~old_read))
		read_count <= read_count + 1'd1;

	if (clear) begin
		if (clear_count < CLEAR_NS)
			clear_count <= clear_count + NS_PER_TICK;
		else begin
			cleared <= 1;
			high_count <= 0;
			charged <= 0;
		end
	end else begin
		clear_count <= 0;
		if (high_count < difference ) begin
			high_count <= high_count + NS_PER_TICK;
		end else begin
			charged <= 1;
		end

		if (cleared) begin
			if (read && highest < high_count)
				highest <= high_count;
			if (read && high_count < lowest) begin
				lowest <= high_count;
				highest <= '0;
				read_count <= 2'b00;
			end
			if (lowest < highest)
				width <= (highest - lowest);
		end
		difference <= ((lowest > highest) | ~read_measured ? 33'h114B6C376 : (lowest + (((width + {NS_PER_TICK, 1'b0}) >> 4'd8) * kohms[7:0])));

	end
	if (reset) begin
		cleared <= 0;
		width <= 0;
		read_count <= 0;
		lowest <= {33{1'b1}};
		highest <= '0;
		difference <= '0;
	end
end

endmodule
