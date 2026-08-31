// k7800 (c) by Jamie Blanks
//
// Copyright (c) 2021-2026 Jamie Blanks
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
module line_ram(
	input  logic               clk_sys,
	input  logic               RESET,
	output logic [7:0]         PLAYBACK,

	input  logic [2:0]         PALETTE,
	input  logic [7:0]         d_in,
	input  logic               WM,
	input  logic               border,

	input  logic               latch_byte,
	input  logic               latch_hpos,

	input  logic [24:0][7:0]   COLOR_MAP,
	input  logic [1:0]         RM,
	input  logic               KANGAROO_MODE,
	input  logic               BORDER_CONTROL,
	input  logic               COLOR_KILL,
	input  logic               lrc,

	input  logic [8:0]         LRAM_OUT_COL,
	input  logic               mclk0,
	input  logic               mclk1,
	input  logic               cram_write
);

logic [159:0][4:0] lram_in, lram_out;

logic [2:0] playback_palette;
logic [1:0] playback_color;
logic [4:0] playback_cell;
logic [8:0] playback_ix;
logic [7:0] lram_ix;
logic [7:0] hpos;

logic [5:0] pb_map_index[8];
assign pb_map_index = '{5'd0, 5'd3, 5'd6, 5'd9, 5'd12, 5'd15, 5'd18, 5'd21};

always @(posedge clk_sys) begin
	if (mclk0) begin
		if (~border)
			playback_ix <= playback_ix + 1'd1;
		else
			playback_ix <= 0;
	end

	if (mclk0 ) begin
		if (playback_color == 2'b0 || border) begin
			PLAYBACK <= (border & ~BORDER_CONTROL) ? 8'd0 : COLOR_MAP[0];
		end else begin
			PLAYBACK <= COLOR_MAP[pb_map_index[playback_palette] + playback_color];
		end
	end

end

always_comb begin
	lram_ix = playback_ix[8:1];
	playback_cell = lram_out[lram_ix];
	playback_palette = playback_cell[4:2];
	playback_color = playback_cell[1:0];
	casex (RM)
		2'b0x: begin

			playback_palette = playback_cell[4:2];
			playback_color = playback_cell[1:0];
		end
		2'b10: begin

			playback_palette = {playback_cell[4], 2'b0};
			if (playback_ix[0]) begin

				playback_color = {playback_cell[0], playback_cell[2]};
			end else begin

				playback_color = {playback_cell[1], playback_cell[3]};
			end
		end
		2'b11: begin

			playback_palette = playback_cell[4:2];
			if (playback_ix[0]) begin

				playback_color = {playback_cell[0], 1'b0};
			end else begin

				playback_color = {playback_cell[1], 1'b0};
			end
		end
	endcase
end

always_ff @(posedge clk_sys) begin
	if (RESET) begin
		hpos <= 0;
	end else if (mclk0) begin

		if (lrc) begin
			lram_in <= 800'd0;
			lram_out <= lram_in;
		end

		if (latch_hpos) begin
			hpos <= d_in;
		end

		if (latch_byte) begin

			case (WM)
			1'b0: begin

				hpos <= hpos + 3'd4;
				if (|d_in[7:6] || KANGAROO_MODE)
					lram_in[hpos + 8'd0] <= {PALETTE, d_in[7:6]};
				if (|d_in[5:4] || KANGAROO_MODE)
					lram_in[hpos + 8'd1] <= {PALETTE, d_in[5:4]};
				if (|d_in[3:2] || KANGAROO_MODE)
					lram_in[hpos + 8'd2] <= {PALETTE, d_in[3:2]};
				if (|d_in[1:0] || KANGAROO_MODE)
					lram_in[hpos + 8'd3] <= {PALETTE, d_in[1:0]};
			end
			1'b1: begin

				hpos <= hpos + 2'd2;
				if (|d_in[7:6] || KANGAROO_MODE)
					lram_in[hpos + 8'd0] <= {PALETTE[2], d_in[3:2], d_in[7:6]};
				if (|d_in[5:4] || KANGAROO_MODE)
					lram_in[hpos + 8'd1] <= {PALETTE[2], d_in[1:0], d_in[5:4]};
			end
			endcase
		end
	end
end

endmodule

