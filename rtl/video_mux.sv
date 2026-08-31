// k7800 (c) by Jamie Blanks

// k7800 is licensed under a
// Creative Commons Attribution-NonCommercial 4.0 International License.

// You should have received a copy of the license along with this
// work. If not, see http://creativecommons.org/licenses/by-nc/4.0/.
module video_mux
(
	input  logic       clk_sys,
	input  logic [3:0] maria_luma,
	input  logic [3:0] maria_chroma,
	input  logic       maria_hblank,
	input  logic       maria_vblank,
	input  logic       maria_hsync,
	input  logic       maria_vsync,
	input  logic       maria_pix_ce,

	input  logic [2:0] tia_luma,
	input  logic [3:0] tia_chroma,
	input  logic       tia_hblank,
	input  logic       tia_vblank,
	input  logic       tia_hsync,
	input  logic       tia_vsync,
	input  logic       tia_pix_ce,

	input  logic       pause,

	input  logic       is_maria,
	input  logic [1:0] pal_temp,
	input  logic       is_PAL,
	input  logic       pal_load,
	input  logic [7:0] pal_data,
	input  logic [9:0] pal_addr,
	input  logic       pal_wr,
	input  logic       blend,

	output logic       hblank,
	output logic       vblank,
	output logic       hsync,
	output logic       vsync,
	output logic [7:0] red,
	output logic [7:0] green,
	output logic [7:0] blue,
	output logic       pix_ce
);

logic [23:0] out_color, nwarm_color, ncool_color, nhot_color,
	pwarm_color, pcool_color, phot_color, custom_color, old_color;

wire pix_ce_normal = is_maria ? maria_pix_ce : tia_pix_ce;
logic [1:0] pix_ce_paused_tia;
logic pix_ce_paused_maria;
always @(posedge clk_sys) begin
	pix_ce_paused_maria <= ~pix_ce_paused_maria;
	pix_ce_paused_tia <= pix_ce_paused_tia + 2'd1;
end
wire pix_ce_paused = is_maria ? pix_ce_paused_maria : pix_ce_paused_tia[1];
wire pix_ce_immediate = pause ? pix_ce_paused : pix_ce_normal;
logic pix_ce_delayed;
logic [7:0] yuv_index;
logic [7:0][1:0] last_color;
logic [15:0] frame_ptr;
logic [7:0] frame_data;
logic [3:0] tia_chroma_region;

spram #(.addr_width(16), .mem_name("FBLN")) ram0
(
	.clock          (clk_sys),
	.address        (frame_ptr),
	.data           ({tia_vblank, yuv_index[7:1]}),
	.wren           (pix_ce_immediate && ~is_maria && ~pause),
	.cs             (1'b1),
	.q              (frame_data)
);

wire [3:0] pal_2600_chroma[16] = '{
	4'h0, 4'h0, 4'h2, 4'hD,
	4'h3, 4'hc, 4'h4, 4'hb,
	4'h5, 4'ha, 4'h6, 4'h9,
	4'h7, 4'h8, 4'h0, 4'h0
};

always_comb begin
	tia_chroma_region = is_PAL ? pal_2600_chroma[tia_chroma] : tia_chroma;
	out_color = nwarm_color;

	yuv_index = {maria_chroma, maria_luma};
	if (~is_maria)
		yuv_index = ~pix_ce_immediate ? {frame_data[6:0], 1'b0} : {tia_chroma_region, {tia_luma, 1'b0}};

	case ({is_PAL, pal_temp})
		0: out_color = nwarm_color;
		1: out_color = ncool_color;
		2: out_color = nhot_color;
		3: out_color = custom_color;
		4: out_color = pwarm_color;
		5: out_color = pcool_color;
		6: out_color = phot_color;
		7: out_color = custom_color;
	 default: ;
	endcase

end

logic [15:0] pal_buff;
logic [7:0] pal_mux_addr;
logic [1:0] pal_count = 0;
logic old_vblank;

wire [23:0] blend_color = {
	{1'b0, old_color[23:17]} + out_color[23:17],
	{1'b0, old_color[15:9]} + out_color[15:9],
	{1'b0, old_color[7:1]} + out_color[7:1]
};

always @(posedge clk_sys) begin
	if (pal_load) begin
		if (pal_wr) begin
			pal_count <= pal_count == 2 ? 2'd0 : pal_count + 1'd1;
			case (pal_count)
				0: pal_buff[15:8] <= pal_data;
				1: pal_buff[7:0] <= pal_data;
				2: pal_mux_addr <= pal_mux_addr + 1'd1;
			endcase
		end
	end else begin
		pal_mux_addr <= 0;
		pal_count <= 0;
	end
	if (pix_ce_immediate) begin
		if (~tia_vblank && ~pause)
			frame_ptr <= frame_ptr + 1'd1;
		old_color <= out_color;
		old_vblank <= frame_data[7];
	end

	if (tia_vsync)
		frame_ptr <= 0;

	pix_ce_delayed <= pix_ce_immediate;
	pix_ce <= pix_ce_delayed;
	if (pix_ce_delayed) begin
		last_color <= {last_color[0], yuv_index};
		{red, green, blue} <= (blend && ~is_maria && ~pause) ? blend_color : out_color;
		vsync <= is_maria ? maria_vsync : tia_vsync;
		vblank <= is_maria ? maria_vblank : ((blend && ~pause) ? (old_vblank | tia_vblank) : tia_vblank);
		hsync <= is_maria ? maria_hsync : tia_hsync;
		hblank <= is_maria ? maria_hblank : tia_hblank;
	end
end

spram #(
	.addr_width(8),
	.data_width(24),
	.mem_init_file("rtl/palettes/NWARM.mif"),
	.sim_init_file("rtl/palettes/NWARM.hex")
) nwarm
(
	.clock   (clk_sys),
	.address (yuv_index),
	.data    (24'd0),
	.wren    (1'b0),
	.cs      (1'b1),
	.q       (nwarm_color)
);

spram #(
	.addr_width(8),
	.data_width(24),
	.mem_init_file("rtl/palettes/NCOOL.mif"),
	.sim_init_file("rtl/palettes/NCOOL.hex")
) ncool
(
	.clock   (clk_sys),
	.address (yuv_index),
	.data    (24'd0),
	.wren    (1'b0),
	.cs      (1'b1),
	.q       (ncool_color)
);

spram #(
	.addr_width(8),
	.data_width(24),
	.mem_init_file("rtl/palettes/NHOT.mif"),
	.sim_init_file("rtl/palettes/NHOT.hex")
) nhot
(
	.clock   (clk_sys),
	.address (yuv_index),
	.data    (24'd0),
	.wren    (1'b0),
	.cs      (1'b1),
	.q       (nhot_color)
);

spram #(
	.addr_width(8),
	.data_width(24),
	.mem_init_file("rtl/palettes/PWARM.mif"),
	.sim_init_file("rtl/palettes/PWARM.hex")
) pwarm
(
	.clock   (clk_sys),
	.address (yuv_index),
	.data    (24'd0),
	.wren    (1'b0),
	.cs      (1'b1),
	.q       (pwarm_color)
);

spram #(
	.addr_width(8),
	.data_width(24),
	.mem_init_file("rtl/palettes/PCOOL.mif"),
	.sim_init_file("rtl/palettes/PCOOL.hex")
) pcool
(
	.clock   (clk_sys),
	.address (yuv_index),
	.data    (24'd0),
	.wren    (1'b0),
	.cs      (1'b1),
	.q       (pcool_color)
);

spram #(
	.addr_width(8),
	.data_width(24),
	.mem_init_file("rtl/palettes/PHOT.mif"),
	.sim_init_file("rtl/palettes/PHOT.hex")
) phot
(
	.clock   (clk_sys),
	.address (yuv_index),
	.data    (24'd0),
	.wren    (1'b0),
	.cs      (1'b1),
	.q       (phot_color)
);

spram #(
	.addr_width(8),
	.data_width(24),
	.mem_init_file("rtl/palettes/PHOT.mif"),
	.sim_init_file("rtl/palettes/PHOT.hex")
) custom
(
	.clock   (clk_sys),
	.data    ({pal_buff, pal_data}),
	.wren    (pal_load && pal_wr && (pal_count == 2)),
	.address (pal_load ? pal_mux_addr : yuv_index),
	.cs      (1'b1),
	.q       (custom_color)
);

endmodule

