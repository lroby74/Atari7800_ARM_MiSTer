`default_nettype none

module bup_stream #(
	parameter int SYS_HZ = 14318181,
	parameter int SND_HZ = 48000
) (
	input  wire        clk,
	input  wire        reset,

	input  wire        mounted,
	input  wire [63:0] img_size,

	input  wire  [7:0] cmd,
	input  wire        cmd_strobe,

	output reg  [31:0] sd_lba,
	output reg         sd_rd,
	input  wire        sd_ack,
	input  wire  [8:0] sd_buff_addr,
	input  wire  [7:0] sd_buff_dout,
	input  wire        sd_buff_wr,

	output wire [15:0] audio_l,
	output wire [15:0] audio_r,
	output wire        playing,
	output wire        ready
);

	reg  [7:0]  buf0 [0:511];
	reg  [7:0]  buf1 [0:511];
	reg  [31:0] first_blk [0:31];
	reg  [31:0] track_len [0:31];

	reg         have_index;
	reg   [1:0] hdr_ok;

	reg   [4:0] track_nx;
	reg         seek;
	reg  [31:0] seek_pos;
	reg         seek_fresh;

	reg  [31:0] end_pos, loop_pos;
	reg  [15:0] loop_sl, loop_sr;
	reg   [6:0] loop_il, loop_ir;
	reg         grab_hdr, hdr_done;

	reg         run;
	reg         fill_half, play_half;
	reg   [1:0] half_full;
	reg         set_full, clr_full, set_idx, clr_idx;

	assign ready   = have_index;
	assign playing = run;

	reg   [8:0] rd_ptr;
	wire  [7:0] rd_byte = play_half ? buf1[rd_ptr] : buf0[rd_ptr];

	always @(posedge clk)
		if (sd_buff_wr && sd_ack) begin
			if (fill_half) buf1[sd_buff_addr] <= sd_buff_dout;
			else           buf0[sd_buff_addr] <= sd_buff_dout;
		end

	localparam [1:0] R_IDLE = 2'd0, R_INDEX = 2'd1, R_WAIT = 2'd2;
	reg  [1:0]  rst_;
	reg  [23:0] acc;
	reg  [4:0]  ent;
	reg  [31:0] fetch_blk, last_blk;
	reg         want_index;
	reg         have_pack = 1'b0;
	always @(posedge clk) if (mounted && img_size != 64'd0) have_pack <= 1'b1;

	always @(posedge clk) begin
		if (reset) begin
			hdr_ok <= 2'd0;
			ent    <= 5'd0;
		end else if (rst_ != R_INDEX) begin

			ent <= 5'd0;
		end else if (sd_buff_wr && sd_ack) begin
			if (sd_buff_addr == 9'd0) hdr_ok[0] <= (sd_buff_dout == 8'h42);
			if (sd_buff_addr == 9'd1) hdr_ok[1] <= (sd_buff_dout == 8'h55);
			if (sd_buff_addr >= 9'd16 && sd_buff_addr < 9'd272) begin
				acc <= {sd_buff_dout, acc[23:8]};
				if (sd_buff_addr[1:0] == 2'd3) begin
					if (sd_buff_addr[2]) track_len[ent] <= {sd_buff_dout, acc};
					else                 first_blk[ent] <= {sd_buff_dout, acc};
				end
				if (sd_buff_addr[2:0] == 3'd7) ent <= ent + 5'd1;
			end
		end
	end

	always @(posedge clk) begin
		if (reset) begin
			end_pos <= 32'd0; loop_pos <= 32'd0;
			loop_sl <= 16'd0; loop_sr <= 16'd0;
			loop_il <= 7'd0;  loop_ir <= 7'd0;
		end else if (grab_hdr && sd_buff_wr && sd_ack) begin
			case (sd_buff_addr)
				9'd4:  end_pos[7:0]    <= sd_buff_dout;
				9'd5:  end_pos[15:8]   <= sd_buff_dout;
				9'd6:  end_pos[23:16]  <= sd_buff_dout;
				9'd7:  end_pos[31:24]  <= sd_buff_dout;
				9'd8:  loop_pos[7:0]   <= sd_buff_dout;
				9'd9:  loop_pos[15:8]  <= sd_buff_dout;
				9'd10: loop_pos[23:16] <= sd_buff_dout;
				9'd11: loop_pos[31:24] <= sd_buff_dout;
				9'd12: loop_sl[7:0]    <= sd_buff_dout;
				9'd13: loop_sl[15:8]   <= sd_buff_dout;
				9'd14: loop_il         <= sd_buff_dout[6:0];
				9'd15: loop_sr[7:0]    <= sd_buff_dout;
				9'd16: loop_sr[15:8]   <= sd_buff_dout;
				9'd17: loop_ir         <= sd_buff_dout[6:0];
				default: ;
			endcase
		end
	end

	always @(posedge clk) begin
		set_full <= 1'b0;
		if (reset) begin
			rst_ <= R_IDLE; sd_rd <= 1'b0; have_index <= 1'b0;
			fill_half <= 1'b0; sd_lba <= 32'd0; want_index <= have_pack;
			fetch_blk <= 32'd0; last_blk <= 32'd0;
			grab_hdr <= 1'b0; hdr_done <= 1'b0;
		end else if (seek) begin
			fetch_blk <= first_blk[track_nx] + {9'd0, seek_pos[31:9]};
			last_blk  <= first_blk[track_nx] + {9'd0, track_len[track_nx][31:9]};
			grab_hdr  <= seek_fresh;
			hdr_done  <= ~seek_fresh;
			fill_half <= 1'b0;
			sd_rd     <= 1'b0;
			rst_      <= R_IDLE;
		end else begin
			if (mounted && img_size != 64'd0) want_index <= 1'b1;

			case (rst_)
				R_IDLE:
					if (want_index) begin
						want_index <= 1'b0; have_index <= 1'b0;
						sd_lba <= 32'd0; sd_rd <= 1'b1; rst_ <= R_INDEX;
					end else if (run && !half_full[fill_half] && fetch_blk <= last_blk) begin
						sd_lba <= fetch_blk; sd_rd <= 1'b1; rst_ <= R_WAIT;
					end
				R_INDEX:
					if (sd_ack) sd_rd <= 1'b0;
					else if (!sd_rd) begin
						have_index <= (hdr_ok == 2'b11);
						rst_ <= R_IDLE;
					end
				R_WAIT:
					if (sd_ack) sd_rd <= 1'b0;
					else if (!sd_rd) begin
						set_full  <= 1'b1;
						set_idx   <= fill_half;
						fill_half <= ~fill_half;
						fetch_blk <= fetch_blk + 32'd1;
						if (grab_hdr) begin
							grab_hdr <= 1'b0;
							hdr_done <= 1'b1;
						end
						rst_ <= R_IDLE;
					end
				default: rst_ <= R_IDLE;
			endcase
		end
	end

	reg [26:0] tick_acc;
	wire       tick = (tick_acc >= SYS_HZ[26:0]);

	always @(posedge clk)
		if (reset) tick_acc <= 27'd0;
		else       tick_acc <= tick ? (tick_acc - SYS_HZ[26:0] + SND_HZ[26:0])
		                            : (tick_acc + SND_HZ[26:0]);

	reg         byte_valid;
	reg   [7:0] byte_out;
	reg         st_set;
	reg  [15:0] st_sl, st_sr;
	reg   [6:0] st_il, st_ir;

	bup_adpcm u_dec (
		.clk(clk), .reset(reset),
		.state_set(st_set),
		.state_smp_l(st_sl), .state_idx_l(st_il),
		.state_smp_r(st_sr), .state_idx_r(st_ir),
		.byte_valid(byte_valid), .byte_in(byte_out),
		.pcm_l(audio_l), .pcm_r(audio_r), .pcm_valid(), .busy());

	reg [31:0] play_left;
	reg        armed;

	always @(posedge clk) begin
		byte_valid <= 1'b0;
		clr_full   <= 1'b0;
		seek       <= 1'b0;
		st_set     <= 1'b0;
		if (reset) begin
			run <= 1'b0; play_half <= 1'b0; rd_ptr <= 9'd0;
			play_left <= 32'd0; armed <= 1'b0;
		end else if (cmd_strobe && have_index) begin

			if ((cmd > 8'd31) || track_len[cmd[4:0]] == 32'd0) begin
				run <= 1'b0; armed <= 1'b0;
			end else begin
				track_nx   <= cmd[4:0];
				seek       <= 1'b1;
				seek_pos   <= 32'd0;
				seek_fresh <= 1'b1;
				play_half  <= 1'b0;
				rd_ptr     <= 9'd18;
				run        <= 1'b1;
				armed      <= 1'b1;
				st_set     <= 1'b1;
				st_sl      <= 16'd0; st_il <= 7'd0;
				st_sr      <= 16'd0; st_ir <= 7'd0;
			end
		end else if (armed && hdr_done) begin
			play_left <= end_pos - 32'd18;
			armed     <= 1'b0;
		end else if (run && !armed && tick && half_full[play_half]) begin
			if (play_left == 32'd0) begin
				if (loop_pos != 32'd0) begin
					seek       <= 1'b1;
					seek_pos   <= loop_pos;
					seek_fresh <= 1'b0;
					play_half  <= 1'b0;
					rd_ptr     <= loop_pos[8:0];
					play_left  <= end_pos - loop_pos;
					st_set     <= 1'b1;
					st_sl      <= loop_sl; st_il <= loop_il;
					st_sr      <= loop_sr; st_ir <= loop_ir;
				end else
					run <= 1'b0;
			end else begin
				byte_valid <= 1'b1;
				byte_out   <= rd_byte;
				play_left  <= play_left - 32'd1;
				if (rd_ptr == 9'd511) begin
					rd_ptr    <= 9'd0;
					clr_full  <= 1'b1;
					clr_idx   <= play_half;
					play_half <= ~play_half;
				end else
					rd_ptr <= rd_ptr + 9'd1;
			end
		end
	end

	always @(posedge clk)
		if (reset || seek) half_full <= 2'b00;
		else begin
			if (set_full) half_full[set_idx] <= 1'b1;
			if (clr_full) half_full[clr_idx] <= 1'b0;
		end

endmodule

`default_nettype wire

