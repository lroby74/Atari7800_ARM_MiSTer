`default_nettype none


module arm_copro #(
	parameter int RAM_KB    = 88,
	parameter int PCM_DEPTH = 4096,
	parameter int CMD_DEPTH = 32,
	parameter int CLK_HZ    = 57272728,
	parameter int PCM_HZ    = 48000,
	parameter     FW_FILE   = "copro_m_"
)
(
	input  wire        clk,
	input  wire        reset,

	input  wire        auto_start,

	input  wire        cmd_valid,
	input  wire  [7:0] cmd_data,

	output wire [24:0] ext_addr,
	output wire        ext_req,
	input  wire [31:0] ext_data,
	input  wire        ext_ack,
	input  wire [31:0] asset_size,

	input  wire        pause,

	output reg  [15:0] audio_l,
	output reg  [15:0] audio_r,
	output reg         audio_tog,
	output wire        busy
);

	localparam int LANE_W    = (RAM_KB * 1024) / 8;      // parole per corsia
	localparam int RAM_AW    = $clog2(RAM_KB * 1024);    // bit di indirizzo
	localparam int LANE_AW   = $clog2(LANE_W);
	localparam int PCM_AW    = $clog2(PCM_DEPTH);
	localparam int CMD_AW    = $clog2(CMD_DEPTH);
	localparam int POP_DIV   = CLK_HZ / PCM_HZ;
	localparam int POP_AW    = $clog2(POP_DIV);

	localparam [31:0] IDENT_VALUE = 32'h42555001;        // "BUP" + revisione 1

	wire [31:0] i_addr;
	wire        i_req;
	reg         i_ack;
	reg  [63:0] i_data;

	wire [31:0] d_addr, d_wdata;
	wire  [3:0] d_be;
	wire        d_req, d_we;
	reg  [31:0] d_rdata;
	reg         d_ack;   // combinatorio, dallo stato

	reg         arm_start, auto_done;
	wire        arm_halted;

	localparam S_IDLE = 2'd0, S_RAM = 2'd1, S_MM = 2'd2, S_EXT = 2'd3;
	reg [1:0]  st;
	reg [22:0] r_a;
	reg [22:0] ext_last;
	reg        ext_val;

	wire d_ext  = d_addr[25];
	wire d_mm   = d_addr[28];
	wire d_ram  = !d_ext && !d_mm;

	wire idle   = (st == S_IDLE);
	wire take_d = idle && d_req;
	wire d_free = idle;

	wire ext_hit = ext_val && (ext_last == d_addr[24:2]);

	wire ram_go = take_d && d_ram;
	wire mm_go  = take_d && d_mm;
	wire ext_go = take_d && d_ext && !d_we && !ext_hit;

	wire p_i    = i_req && !i_ack && !ram_go;
	wire ext_take = (st == S_EXT) && ext_ack;

	thumb3_core #(.WATCHDOG(0)) cpu (
		.clk(clk), .rst(reset),
		.start(arm_start), .start_pc(32'h00000000),
		.start_sp(32'h00000000), .start_lr(32'hFFFFFFFF),
		.start_keep(1'b0), .start_r2(32'd0), .start_r2_we(1'b0),
		.running(), .halted(arm_halted), .bx_pc(),
		.i_addr(i_addr), .i_req(i_req), .i_ack(i_ack), .i_data(i_data),
		.d_addr(d_addr), .d_req(d_req), .d_we(d_we), .d_sz(), .d_blk(),
		.d_wdata(d_wdata), .d_be(d_be),
		.d_free(d_free),
		.d_gnt(take_d),
		.d_ack(d_ack), .d_rdata(d_rdata),
		.inv_addr(32'd0), .inv_en(1'b0),
		.dbg_r0(), .dbg_r2(), .dbg_r3(), .dbg_lr(),
		.dbg_pc(), .dbg_retire(), .dbg_flags()
	);

	assign busy = ~arm_halted;

	wire [RAM_AW-1:0] p_addr  = ram_go ? d_addr[RAM_AW-1:0] : i_addr[RAM_AW-1:0];
	wire [31:0]       p_wdata = d_wdata;
	wire  [3:0]       p_be    = d_be;
	wire              p_we    = ram_go && d_we;

	wire [LANE_AW-1:0] ridx = p_addr[RAM_AW-1:3];
	wire               rodd = p_addr[2];

	wire we_e = p_we && ~rodd;
	wire we_o = p_we &&  rodd;

	reg [7:0] m_e0 [0:LANE_W-1];  reg [7:0] q_e0;
	reg [7:0] m_e1 [0:LANE_W-1];  reg [7:0] q_e1;
	reg [7:0] m_e2 [0:LANE_W-1];  reg [7:0] q_e2;
	reg [7:0] m_e3 [0:LANE_W-1];  reg [7:0] q_e3;
	reg [7:0] m_o0 [0:LANE_W-1];  reg [7:0] q_o0;
	reg [7:0] m_o1 [0:LANE_W-1];  reg [7:0] q_o1;
	reg [7:0] m_o2 [0:LANE_W-1];  reg [7:0] q_o2;
	reg [7:0] m_o3 [0:LANE_W-1];  reg [7:0] q_o3;

	initial begin
		if (FW_FILE != "") begin
			$readmemh({FW_FILE, "e0.hex"}, m_e0);
			$readmemh({FW_FILE, "e1.hex"}, m_e1);
			$readmemh({FW_FILE, "e2.hex"}, m_e2);
			$readmemh({FW_FILE, "e3.hex"}, m_e3);
			$readmemh({FW_FILE, "o0.hex"}, m_o0);
			$readmemh({FW_FILE, "o1.hex"}, m_o1);
			$readmemh({FW_FILE, "o2.hex"}, m_o2);
			$readmemh({FW_FILE, "o3.hex"}, m_o3);
		end
	end

	always @(posedge clk) begin
		if (we_e && p_be[0]) m_e0[ridx] <= p_wdata[7:0];
		q_e0 <= m_e0[ridx];
	end
	always @(posedge clk) begin
		if (we_e && p_be[1]) m_e1[ridx] <= p_wdata[15:8];
		q_e1 <= m_e1[ridx];
	end
	always @(posedge clk) begin
		if (we_e && p_be[2]) m_e2[ridx] <= p_wdata[23:16];
		q_e2 <= m_e2[ridx];
	end
	always @(posedge clk) begin
		if (we_e && p_be[3]) m_e3[ridx] <= p_wdata[31:24];
		q_e3 <= m_e3[ridx];
	end
	always @(posedge clk) begin
		if (we_o && p_be[0]) m_o0[ridx] <= p_wdata[7:0];
		q_o0 <= m_o0[ridx];
	end
	always @(posedge clk) begin
		if (we_o && p_be[1]) m_o1[ridx] <= p_wdata[15:8];
		q_o1 <= m_o1[ridx];
	end
	always @(posedge clk) begin
		if (we_o && p_be[2]) m_o2[ridx] <= p_wdata[23:16];
		q_o2 <= m_o2[ridx];
	end
	always @(posedge clk) begin
		if (we_o && p_be[3]) m_o3[ridx] <= p_wdata[31:24];
		q_o3 <= m_o3[ridx];
	end

	wire [31:0] q_even = {q_e3, q_e2, q_e1, q_e0};
	wire [31:0] q_odd  = {q_o3, q_o2, q_o1, q_o0};

	always @(posedge clk) begin
		i_ack <= p_i;
		if (reset) i_ack <= 1'b0;
	end
	always @* i_data = {q_odd, q_even};

	assign ext_addr = {r_a, 2'b00};
	assign ext_req  = (st == S_EXT);

	reg [31:0] ext_lat;
	always @(posedge clk) begin
		if (reset) begin
			ext_lat  <= 32'd0;
			ext_val  <= 1'b0;
			ext_last <= 23'd0;
		end else if (ext_take) begin
			ext_lat  <= ext_data;
			ext_last <= r_a;
			ext_val  <= 1'b1;
		end
	end

	always @(posedge clk) begin
		if (reset) begin
			st  <= S_IDLE;
			r_a <= 23'd0;
		end else case (st)
			S_IDLE: if (d_req) begin
				r_a <= d_addr[24:2];
				if (d_ram)       st <= S_RAM;
				else if (d_mm)   st <= S_MM;
				else if (ext_go) st <= S_EXT;
				else             st <= S_MM;   // finestra gia' in mano, o scrittura
			end
			S_RAM: st <= S_IDLE;
			S_MM:  st <= S_IDLE;
			S_EXT: if (ext_ack) st <= S_IDLE;
			default: st <= S_IDLE;
		endcase
	end

	reg [7:0]  cmd_mem [0:CMD_DEPTH-1];
	reg [CMD_AW:0] cmd_wr, cmd_rd;
	reg        cmd_overflow;

	wire [CMD_AW:0] cmd_level = cmd_wr - cmd_rd;
	wire cmd_empty = (cmd_level == 0);
	wire cmd_full  = (cmd_level == CMD_DEPTH[CMD_AW:0]);

	reg [31:0] pcm_head;
	reg [PCM_AW:0] pcm_wr, pcm_rd;
	reg        pcm_underflow, pcm_overflow, pcm_enable, muted;
	reg [7:0]  fault_code;
	reg [31:0] dbg;

	wire [PCM_AW:0] pcm_level = pcm_wr - pcm_rd;
	wire pcm_empty = (pcm_level == 0);
	wire pcm_full  = (pcm_level == PCM_DEPTH[PCM_AW:0]);

	wire [7:0] mm_a = d_addr[7:0];

	wire cmd_pop  = mm_go && !d_we && mm_a == 8'h04 && !cmd_empty;
	wire pcm_push = mm_go &&  d_we && mm_a == 8'h10;

	reg [31:0] mm_q;
	always @* begin
		case (mm_a)
			8'h00: mm_q = IDENT_VALUE;
			8'h04: mm_q = cmd_empty ? 32'd0
			                        : {23'd0, 1'b1, cmd_mem[cmd_rd[CMD_AW-1:0]]};
			8'h08: mm_q = {15'd0, cmd_overflow, 6'd0, cmd_full, cmd_empty, 8'd0}
			            | {{(32-CMD_AW-1){1'b0}}, cmd_level};
			8'h14: mm_q = {6'd0, pcm_overflow, pcm_underflow, 6'd0,
			               pcm_full, pcm_empty, 16'd0}
			            | {{(32-PCM_AW-1){1'b0}}, pcm_level};
			8'h20: mm_q = asset_size;
			default: mm_q = 32'd0;
		endcase
	end

	reg [31:0] pcm_mem [0:PCM_DEPTH-1];
	always @(posedge clk) begin
		if (pcm_push && !pcm_full) pcm_mem[pcm_wr[PCM_AW-1:0]] <= d_wdata;
		pcm_head <= pcm_mem[pcm_rd[PCM_AW-1:0]];
	end

	localparam [31:0]       POP_MAX32 = POP_DIV - 1;
	localparam [POP_AW-1:0] POP_MAX   = POP_MAX32[POP_AW-1:0];

	reg [POP_AW-1:0] pop_count;
	reg              pcm_pop;
	wire             pcm_acceso = pcm_enable && !muted;
	wire             pcm_vivo   = pcm_acceso && !pcm_empty;

	always @(posedge clk) begin
		pcm_pop <= 1'b0;
		if (reset) begin
			pop_count <= 0;
			audio_l   <= 16'd0;
			audio_r   <= 16'd0;
			audio_tog <= 1'b0;
		end else if (!pause) begin
			pop_count <= pop_count + 1'b1;
			if (pop_count == POP_MAX) begin
				pop_count <= 0;
				pcm_pop <= pcm_enable;
				audio_l   <= pcm_vivo ? pcm_head[15:0]  : 16'd0;
				audio_r   <= pcm_vivo ? pcm_head[31:16] : 16'd0;
				audio_tog <= ~audio_tog;
			end
		end
	end

	always @(posedge clk) begin
		if (reset) begin
			cmd_wr <= 0; cmd_rd <= 0; cmd_overflow <= 1'b0;
			pcm_wr <= 0; pcm_rd <= 0;
			pcm_underflow <= 1'b0; pcm_overflow <= 1'b0;
			pcm_enable <= 1'b0; muted <= 1'b0; fault_code <= 8'd0; dbg <= 32'd0;
			arm_start <= 1'b0; auto_done <= 1'b0;
		end else begin
			arm_start <= 1'b0;
			if (auto_start && !auto_done) begin
				arm_start <= 1'b1;
				auto_done <= 1'b1;
			end

			if (cmd_valid) begin
				if (cmd_full) cmd_overflow <= 1'b1;
				else begin
					cmd_mem[cmd_wr[CMD_AW-1:0]] <= cmd_data;
					cmd_wr <= cmd_wr + 1'b1;
				end
			end
			if (cmd_pop) cmd_rd <= cmd_rd + 1'b1;

			if (pcm_push) begin
				if (pcm_full) pcm_overflow <= 1'b1;
				else pcm_wr <= pcm_wr + 1'b1;
			end
			if (pcm_pop) begin
				if (pcm_empty) pcm_underflow <= 1'b1;
				else pcm_rd <= pcm_rd + 1'b1;
			end

			if (mm_go && d_we) begin
				case (mm_a)
					8'h0C: begin
						if (d_wdata[0]) cmd_overflow <= 1'b0;
						if (d_wdata[1]) cmd_rd <= cmd_wr;
					end
					8'h18: begin
						pcm_enable <= d_wdata[0];
						if (d_wdata[1]) begin
							pcm_underflow <= 1'b0;
							pcm_overflow  <= 1'b0;
						end
					end
					8'h1C: begin
						muted <= 1'b1;
						fault_code <= d_wdata[7:0];
					end
					8'h24: dbg <= d_wdata;
					default: ;
				endcase
			end
		end
	end

	reg src_ext, src_mm, src_off;
	always @(posedge clk) begin
		if (reset) begin
			src_ext <= 1'b0;
			src_mm  <= 1'b0;
		end else if (take_d) begin
			src_ext <= d_ext;
			src_mm  <= d_mm;
			src_off <= d_addr[2];
		end
	end

	always @* d_ack = (st == S_RAM) || (st == S_MM) || ((st == S_EXT) && ext_ack);

	reg [31:0] mm_lat;
	always @(posedge clk) if (mm_go) mm_lat <= mm_q;

	always @* begin
		if (src_ext)     d_rdata = (st == S_EXT) ? ext_data : ext_lat;
		else if (src_mm) d_rdata = mm_lat;
		else             d_rdata = src_off ? q_odd : q_even;
	end

endmodule

`default_nettype wire
