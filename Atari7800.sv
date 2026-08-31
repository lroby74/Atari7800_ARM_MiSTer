`default_nettype none

module emu
(
	`include "sys/emu_ports.vh"
);

assign BUTTONS   = 0;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;

assign AUDIO_S   = 0;
assign AUDIO_MIX = status[3:2];

assign LED_USER  = cart_download | bk_state | bk_pending;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire clock_locked;
wire clk_vid;
wire clk_sys;
wire clk_tia;
wire clk_arm;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_vid),
	.outclk_2(clk_tia),
	.outclk_3(clk_arm),
	.locked(clock_locked)
);

reg        reset_req;
reg [17:0] clr_cnt = 18'h3FFFF;
wire       clr_busy = ~clr_cnt[17];
always @(posedge clk_sys) begin : spazzata_ram
	reset_req <= RESET | buttons[1] | status[0] | cart_download | bios_download
	             | status[48];
	if (reset_req)     clr_cnt <= 18'd0;
	else if (clr_busy) clr_cnt <= clr_cnt + 1'd1;
end

logic reset;
logic use_tape;
always @(posedge clk_vid) begin
	if (status[48])
		use_tape <= 1;
	if (cart_download)
		use_tape <= 0;
	reset <= reset_req | clr_busy;
end

wire cart_download = ioctl_download & (ioctl_index[5:0] == 6'd1);
wire bios_download = ioctl_download & (((ioctl_index[5:0] == 6'd0) && (ioctl_index[7:6] == 0)) || (ioctl_index[5:0] == 2));
wire pal_download  = ioctl_download & (ioctl_index[5:0] == 6'd3);

reg old_cart_download;

`include "build_id.v"
parameter CONF_STR = {
	"ATARI7800;;",
	"FS1,A78A26BIN;",
	"FC2,ROMBIN,Load BIOS;",
	"-;",
	"OFG,Region,Auto,NTSC,PAL;",
	"OC,Difficulty Right,A,B;",
	"OD,Difficulty Left,A,B;",
	"-;",
	"P1,Audio & Video;",
	"P1-;",
	"P1O23,Stereo Mix,None,25%,50%,100%;",
	"P1O4,Stereo TIA,No,Yes;",
	"d0P1OM,Vertical Crop,Disabled,216p(5x);",
	"d0P1ONQ,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P1ORS,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1oIJ,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O9B,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1OT,Show Overscan,No,Yes;",
	"P1OE,Show Border,Yes,No;",
	"P1OK,Composite Blending,No,Yes;",
	"P1OUV,Temperature Colors,Warm,Cool,Hot,Custom;",
	"H3P1FC3,PAL,Load Palette;",
	"P2,Peripherals;",
	"P2OIJ,High Score Cart,Auto,On,Off;",
	"P2O7,Swap Joysticks,No,Yes;",
	"P2-;",
	"P2o69,Port1 Input,Auto,None,Joystick,Lightgun,Paddle,Trakball,Keypad,Driving,STMouse,AmigaMouse,BoosterGrip,Robotron,SaveKey,SNAC,Gamepad;",
	"P2oAD,Port2 Input,Auto,None,Joystick,Lightgun,Paddle,Trakball,Keypad,Driving,STMouse,AmigaMouse,BoosterGrip,Robotron,SaveKey,SNAC,Gamepad;",
	"h1P2O5,SNAC Analog,Yes,No;",
	"P2oK,Allow Multi Paddles,No,Yes;",
	"h1P2O6,Sega Phaser Mode,No,Yes;",
	"P2oH,Swap Paddle A<->B,No,Yes;",
	"P2oE,Quadtari,Off,On;",
	"P2O[72:70],Gun X Tuning,0,1,2,3,4,5,6,7;",
	"P2-;",
	"P2o01,Gun Control,Joy1,Joy2,Mouse;",
	"P2o2,Gun Fire,Joy,Mouse;",
	"P2o45,Cross,Small,Medium,Big,None;",
	"P4,Atari2600;",
	"D2P4oT,Flickerblend,Off,On;",
	"D2P4oV,Stabilize Video,On,Off;",
	"D2P4oF,De-comb,Off,On;",
	"D2P4oU,Black & White,Off,On;",
	"D2P4oOS,Bankswitching,Auto,F8,F6,FE,E0,3F,F4,P2,FA,CV,2K,UA,E7,F0,32,AR,3E,SB,WD,EF,JANE;",
	"P4oN,Fix SC File Checksums,Off,On;",
	"D2P4O[77],CDF/DPC+ ARM,On,Off;",
	"D2P4-;",
	"D2P4rG,Load Tape From ADC;",
	"P3,Advanced;",
	"P3OH,Bypass Bios,Yes,No;",
	"P3O1,Clear Memory,Zero,Random;",
	"P3O8,Pokey IRQ Enabled,No,Yes;",
	"P3O[73],Minnie Sound Chip,Off,On;",
	"D2P3OL,CPU Driver,TIA,Maria;",
	"-;",
	"o3,Pause Core on OSD,Off,On;",
	"-;",
	"R0,Hard Reset;",
	"J,Fire1,Fire2,Pause/B&W,Select,Reset(Start),Paddle Button,Diff L,Diff R,Halt;",
	"jn,A,B,R,Select,Start,X|P;",
	"jp,B,Y,R,Select,Start,X|P;",
	"I,",
	"Paddle 1A Assigned,",
	"Paddle 1B Assigned,",
	"Paddle 2A Assigned,",
	"Paddle 2B Assigned,",
	"Difficulty Right: A,",
	"Difficulty Right: B,",
	"Difficulty Left: A,",
	"Difficulty Left: B,",
	"Black and White: Off,",
	"Black and White: On,",
	"Paddle Mode Enabled,",
	"Joystick Mode Enabled;",
	"V,v",`BUILD_DATE
};

wire  [1:0] buttons;
logic [127:0] status, status_in;
wire         status_set;
wire        forced_scandoubler;
wire  [1:0] img_mounted;
wire        img_readonly;
wire [63:0] img_size;
wire        ioctl_download;
wire [24:0] ioctl_addr;
wire [7:0]  ioctl_dout;
wire        ioctl_wr;
wire [7:0]  ioctl_index;
wire [21:0] gamma_bus;

wire [15:0] joy0,joy1,joy2,joy3;
wire [15:0] joya_0,joya_1,joya_2,joya_3,joyar_0,joyar_1,joyar_2,joyar_3;
wire  [7:0] pd_0,pd_1,pd_2,pd_3;
wire        ioctl_wait;

reg  [31:0] sd_lba0;
reg         sd_rd0, sd_wr0;
wire [31:0] bup_lba;
wire        bup_rd;
wire [31:0] sd_lba[2];

wire  [5:0] sd_blk_cnt[2];
assign sd_blk_cnt[0] = 6'd0;
assign sd_blk_cnt[1] = 6'd0;
wire  [1:0] sd_rd = {bup_rd, sd_rd0};
wire  [1:0] sd_wr = {1'b0,   sd_wr0};
assign sd_lba[0] = sd_lba0;
assign sd_lba[1] = bup_lba;
wire  [1:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din[2];
wire        sd_buff_wr;
reg         en216p;
wire [24:0] ps2_mouse;
logic [10:0] ps2_key;
logic [15:0] ps2_mouse_ext;
logic is_snac0, is_snac1;
logic info_req;
logic [7:0] info;
logic [1:0] last_paddle;
logic pad0_assigned, pad1_assigned, pad2_assigned, pad3_assigned;
logic old_auto_paddle, auto_paddle;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(2)) hps_io
(
	.clk_sys            (clk_sys),
	.HPS_BUS            (HPS_BUS),

	.buttons            (buttons),
	.forced_scandoubler (forced_scandoubler),
	.gamma_bus          (gamma_bus),

	.joystick_0         (joy0),
	.joystick_1         (joy1),
	.joystick_2         (joy2),
	.joystick_3         (joy3),
	.joystick_l_analog_0  (joya_0),
	.joystick_l_analog_1  (joya_1),
	.joystick_l_analog_2  (joya_2),
	.joystick_l_analog_3  (joya_3),
	.joystick_r_analog_0  (joyar_0),
	.joystick_r_analog_1  (joyar_1),
	.joystick_r_analog_2  (joyar_2),
	.joystick_r_analog_3  (joyar_3),
	.paddle_0           (pd_0),
	.paddle_1           (pd_1),
	.paddle_2           (pd_2),
	.paddle_3           (pd_3),

	.info_req           (info_req),
	.info               (info),

	.ps2_mouse          (ps2_mouse),
	.ps2_mouse_ext      (ps2_mouse_ext),
	.ps2_key            (ps2_key),
	.status             (status),
	.status_set         (status_set),
	.status_in          (status_in),
	.status_menumask    ({status[31:30] != 3,~tia_en,(is_snac0 | is_snac1),en216p}),

	.ioctl_addr         (ioctl_addr),
	.ioctl_dout         (ioctl_dout),
	.ioctl_wr           (ioctl_wr),
	.ioctl_download     (ioctl_download),
	.ioctl_index        (ioctl_index),
	.ioctl_wait         (ioctl_wait),

	.sd_lba             (sd_lba),
	.sd_rd              (sd_rd),
	.sd_wr              (sd_wr),
	.sd_blk_cnt         (sd_blk_cnt),
	.sd_ack             (sd_ack),
	.sd_buff_addr       (sd_buff_addr),
	.sd_buff_dout       (sd_buff_dout),
	.sd_buff_din        (sd_buff_din),
	.sd_buff_wr         (sd_buff_wr),

	.img_mounted        (img_mounted),
	.img_readonly       (img_readonly),
	.img_size           (img_size)
);

logic tia_en;
logic [3:0] idump;

logic [1:0] ilatch;
logic [7:0] PAin, PBin, PAout, PBout;
wire [7:0] R,G,B;
wire HSync;
wire VSync;
wire HBlank;
wire VBlank, VBlank_orig;

wire [15:0] bios_addr;
reg [7:0] cart_data, bios_data;
reg [7:0] joy0_type, joy1_type, cart_region, cart_save;

logic [15:0] cart_flags;
logic [39:0] cart_header;
logic [31:0] cart_size;
logic [24:0] cart_addr;
logic [7:0] cart_xm;
logic cart_busy;
logic cart_read;
logic [7:0] cart_data_sd;
reg cart_loaded = 0;
logic RW;

logic cart_is_7800;
logic [7:0] hsc_ram_dout, din;
logic hsc_ram_cs;
logic tia_mode;
logic ce_pix_raw;
logic [7:0] cart_din;
logic cart_rw;
wire [4:0] force_bs;
wire [1:0] cdf_family;
wire sc;
wire quadtari_det;

logic [15:0] rnd;
wire PAread;

lfsr #(.N(15)) random(rnd);

wire region_select = ~|status[16:15] ? (tia_en ? tia_pal : cart_region[0]) : status[16];
logic [3:0] iout;
logic tia_hsync;
logic tia_pal, tia_f1;
logic [7:0] rval;

always @(posedge clk_sys) begin
	rval <= rnd[7:0];
	old_cart_download <= cart_download;
end
logic tape_adc;
logic tape_adc_act;

ltc2308_tape #(.CLK_RATE(14318182)) ltc2308_tape
(
  .clk(clk_sys),
  .reset(reset),
  .ADC_BUS(ADC_BUS),
  .dout(tape_adc),
  .active(tape_adc_act)
);

wire [17:0] cartram_addr;
wire cartram_wr;
wire [7:0] cartram_wrdata;
wire cartram_rd;
wire [7:0] cartram_data;
wire cartram_busy;
logic [3:0] i_read;
logic halted;
logic use_sk;

logic core_paused;
logic freeze_sync;
logic cpu_ce;

always_ff @(posedge clk_sys) begin :core_sync
	reg old_sync;
	old_sync <= freeze_sync;
	if (old_sync ^ freeze_sync)
		core_paused <= (status[35] && OSD_STATUS) || halted;
	if (reset || cart_download)
		core_paused <= 1'b0;
end

logic tia_stab_d, vsync_d;

always_ff @(posedge clk_sys) begin
	vsync_d <= VSync;
	if (~OSD_STATUS)
		tia_stab_d <= status[63];
	else if (tia_stab_d && (~vsync_d && VSync))
		tia_stab_d <= 0;
end

logic core_paused_eff;
logic [19:0] pause_cnt;
logic old_fsync;
logic [1:0] n_edges;

always_ff @(posedge clk_sys) begin :pause_delay
    old_fsync <= freeze_sync;

    if (!core_paused) begin
        core_paused_eff <= 0;
        pause_cnt <= 0;
        n_edges <= 0;
    end else if (!core_paused_eff) begin
        if (pause_cnt < 20'd320_000) begin
            pause_cnt <= pause_cnt + 1'd1;
        end else if (~old_fsync && freeze_sync) begin

            if (n_edges < 2)
                n_edges <= n_edges + 1'd1;
            else
                core_paused_eff <= 1;
        end
    end
end

assign HDMI_FREEZE = core_paused_eff;

Atari7800 main
(
	.clk_sys      (clk_sys),
	.reset        (reset),

	.loading      (cart_download || bios_download || clr_busy),
	.pause        (core_paused_eff),

	.RED          (R),
	.GREEN        (G),
	.BLUE         (B),
	.HSync        (HSync),
	.VSync        (VSync),
	.HBlank       (HBlank),
	.VBlank       (VBlank),
	.VBlank_orig  (VBlank_orig),
	.ce_pix       (ce_pix_raw),
	.show_border  (~status[14]),
	.show_overscan(status[29]),
	.PAL          (region_select),
	.pal_temp     (status[31:30]),
	.tia_mode     (tia_mode && ~status[17]),

	.cart_is_2600 (tia_mode | ~cart_is_7800),
	.bypass_bios  (~status[17]),
	.pokey_irq    (status[8]),
	.minnie_en    (status[73]),
	.hsc_en       (~use_sk && (~|status[19:18] && (|cart_save || cart_xm[0]) ? 1'b1 : status[18])),
	.hsc_ram_dout (hsc_ram_dout),
	.hsc_ram_cs   (hsc_ram_cs),

	.AUDIO_R      (core_audio_r),
	.AUDIO_L      (core_audio_l),

	.cart_out     (cart_download ? ioctl_dout[7:0] : (cart_loaded ? cart_data_sd : cart_data)),
	.cart_read    (cart_read),
	.cart_size    (cart_size),
	.cart_addr_out(cart_addr),
	.cart_flags   (cart_is_7800 ? cart_flags[15:0] : 16'd0),
	.cart_save    (cart_save),
	.cart_din     (cart_din),
	.cart_xm      (cart_is_7800 ? cart_xm : 8'h0),
	.ps2_key      (ps2_key),

	.cartram_addr   (cartram_addr),
	.cartram_wr     (cartram_wr),
	.cartram_rd     (cartram_rd),
	.cartram_wrdata (cartram_wrdata),
	.cartram_data   (cartram_data),

	.bios_out     (bios_data),
	.AB           (bios_addr),
	.RW           (RW),
	.dout         (din),

	.idump        (idump),
	.ilatch       (ilatch),
	.i_out        (iout),
	.tia_en       (tia_en),
	.tia_hsync    (tia_hsync),
	.use_stereo   (status[4]),

	.cpu_driver   (tia_mode | ~status[21]),
	.tia_f1       (tia_f1),
	.tia_pal      (tia_pal),
	.tia_stab     (tia_stab_d),

	.PAin         (PAin),
	.PBin         (PBin),
	.PAout        (PAout),
	.PBout        (PBout),
	.PAread       (PAread),

	.force_bs     (use_tape ? BANKAR : force_bs),
	.sc           (sc),
	.clearval     (status[1] ? rval : 8'h00),
	.random       (rval),
	.decomb       (status[47]),
	.mapper       (status[60:56]),
	.tape_in      ({use_tape, tape_adc}),
	.fix_sc_cs    (status[55]),

	.pal_load     (pal_download),
	.pal_addr     (ioctl_addr[9:0]),
	.pal_wr       (ioctl_wr),
	.pal_data     (ioctl_dout[7:0]),
	.blend        (status[61]),
	.i_read       (i_read),

	.clk_vid       (clk_vid),
	.cdf_family    (cdf_family),
	.arm_enable_i  (~status[77]),
	.cart_download (cart_download),
	.ioctl_addr    (ioctl_addr[18:0]),
	.ioctl_dout    (ioctl_dout),
	.ioctl_wr      (ioctl_wr),

	.bup_cmd       (bup_cmd),
	.bup_strobe    (bup_strobe),
	.bup_en        (bup_en)
);

wire [15:0] core_audio_l, core_audio_r;
wire  [7:0] bup_cmd;
wire        bup_strobe, bup_en;
wire [15:0] bup_l, bup_r;
wire        bup_ready, bup_playing;

bup_stream u_bup
(
	.clk          (clk_sys),
	.reset        (reset),
	.mounted      (img_mounted[1]),
	.img_size     (img_size),
	.cmd          (bup_cmd),
	.cmd_strobe   (bup_strobe),
	.sd_lba       (bup_lba),
	.sd_rd        (bup_rd),
	.sd_ack       (sd_ack[1]),
	.sd_buff_addr (sd_buff_addr),
	.sd_buff_dout (sd_buff_dout),
	.sd_buff_wr   (sd_buff_wr),
	.audio_l      (bup_l),
	.audio_r      (bup_r),
	.playing      (bup_playing),
	.ready        (bup_ready)
);

assign sd_buff_din[1] = 8'd0;

wire [15:0] bup_u_l = bup_l + 16'h8000;
wire [15:0] bup_u_r = bup_r + 16'h8000;
wire        bup_on  = bup_ready & bup_en;

assign AUDIO_L = bup_on ? ({1'b0, core_audio_l[15:1]} + {1'b0, bup_u_l[15:1]})
                        : core_audio_l;
assign AUDIO_R = bup_on ? ({1'b0, core_audio_r[15:1]} + {1'b0, bup_u_r[15:1]})
                        : core_audio_r;

logic [14:0] bios_mask;

detect2600 detect2600
(
	.clk        (clk_sys),
	.addr       (ioctl_addr[24:0]),
	.reset      (~old_cart_download && cart_download),
	.cart_size  (cart_size),
	.enable     (ioctl_wr & cart_download),
	.data       (ioctl_dout),
	.force_bs   (force_bs),
	.sc         (sc),
	.cdf_family (cdf_family),
	.quadtari   (quadtari_det)
);

initial begin
	cart_header = "ATARI";
	cart_size = 32'h00008000;
	cart_flags = 0;
	cart_region = 0;
	bios_mask = 0;
	cart_save = 0;
	cart_xm = 0;
	tia_mode = 0;
end

always_ff @(posedge clk_sys) begin
	cart_is_7800 <= (cart_header == "ATARI");
	if (bios_download && ioctl_wr)
		bios_mask <= ioctl_addr[14:0];
	if (cart_download && ioctl_wr)
		cart_size <= (ioctl_addr - (cart_is_7800 ? 8'd128 : 1'b0)) + 1'd1;
	if (cart_download) begin
		tia_mode <= ioctl_index[7:6] != 0;
		cart_loaded <= 1;
		if (!tia_mode) begin
			case (ioctl_addr)
				'd01: cart_header[39:32] <= ioctl_dout;
				'd02: cart_header[31:24] <= ioctl_dout;
				'd03: cart_header[23:16] <= ioctl_dout;
				'd04: cart_header[15:8] <= ioctl_dout;
				'd05: cart_header[7:0] <= ioctl_dout;

				'd53: cart_flags[15:8] <= ioctl_dout;
				'd54: cart_flags[7:0] <= ioctl_dout;
				'd55: joy0_type <= ioctl_dout;
				'd56: joy1_type <= ioctl_dout;
				'd57: cart_region <= ioctl_dout;
				'd58: cart_save <= ioctl_dout;
				'd63: cart_xm <= ioctl_dout;
			endcase
			if (!cart_is_7800) begin
				joy0_type <= 8'd1;
				joy1_type <= 8'd1;
			end
		end else begin
			joy0_type <= 8'd1;
			joy1_type <= 8'd1;
			cart_header <= '0;
			cart_flags <= 0;
			cart_region <= 0;
			cart_save <= 0;
			cart_xm <= 0;
		end
	end
end

logic [24:0] cart_write_addr, fixed_addr;
assign cart_write_addr = (ioctl_addr >= 8'd128) && cart_is_7800 ? (ioctl_addr[24:0] - 8'd128) : ioctl_addr[24:0];

spram #(
	.addr_width(14),
	.mem_name("Cart"),
	.mem_init_file("mem0.mif"),
	.sim_init_file("rtl/mem0.hex")
) cart
(
	.address (cart_addr),
	.clock   (clk_sys),
	.data    (8'd0),
	.wren    (1'b0),
	.cs      (1'b1),
	.q       (cart_data)
);

spram #(.addr_width(15), .mem_name("BIOS")) bios
(
	.address (bios_download ? ioctl_addr : (bios_addr[14:0] & bios_mask)),
	.clock   (clk_sys),
	.data    (ioctl_dout),
	.wren    (ioctl_wr & bios_download),
	.cs      (1'b1),
	.q       (bios_data)
);

always @(posedge clk_vid)
	ioctl_wait <= cart_download && cart_busy;

sdram sdram
(
	.*,

	.clk        ( clk_vid         ),
	.init       ( !clock_locked   ),

	.ch0_addr   (cart_download ? cart_write_addr : cart_addr),
	.ch0_wr     (cart_download ? (ioctl_wr & cart_download) : 1'b0),
	.ch0_din    (cart_download ? ioctl_dout : cart_din),
	.ch0_rd     (cart_read & ~cart_download & ~reset),
	.ch0_dout   (cart_data_sd),
	.ch0_busy   (cart_busy)
);

assign info_req = pad0_assigned | pad1_assigned | pad2_assigned |
	pad3_assigned | toggle_bw | toggle_ldiff | toggle_rdiff | toggle_paddle;

always_comb begin
	info = 8'd0;
	if (pad0_assigned)
		info = 8'd1;
	if (pad1_assigned)
		info = 8'd2;
	if (pad2_assigned)
		info = 8'd3;
	if (pad3_assigned)
		info = 8'd4;
	if (toggle_rdiff)
		info = status[12] ? 8'd5: 8'd6;
	if (toggle_ldiff)
		info = status[13] ? 8'd7: 8'd8;
	if (toggle_bw)
		info = status[62] ? 8'd9: 8'd10;
	if (toggle_paddle)
		info = (auto_paddle ? 8'd11 : 8'd12);
end

assign PBin[7] = ~status[12];
assign PBin[6] = ~status[13];
assign PBin[5] = PBout[5];
assign PBin[4] = PBout[4];
assign PBin[3] = tia_en ? ~status[62] : (~joya_sw[6] & ~joyb_sw[6]);
assign PBin[2] = PBout[2];
assign PBin[1] = (~joya_sw[7] & ~joyb_sw[7] & ~keyselect);
assign PBin[0] = (~joya_sw[8] & ~joyb_sw[8] & ~keystart);

wire [7:0] porta_type, portb_type;
wire [1:0] gun_mode = status[33:32];
wire       gun_btn_mode = status[34];
wire       gun_port = (portb_type == 2) ? 1'b1 : 1'b0;
wire       gun_en = (porta_type == 2 || portb_type == 2);
wire       gun_target;
wire       gun_sensor;
wire       gun_trigger;

lightgun lightgun
(
	.CLK(clk_sys),
	.RESET(reset),

	.MOUSE(ps2_mouse),
	.MOUSE_XY(gun_mode[1]),

	.LIGHT (|R[7:4] || |G[7:4] || |B[7:4]),
	.H_WIDTH(tia_en ? 9'd160 : 9'd372),

	.JOY_X(~|gun_mode ? joya_0[7:0] : joya_1[7:0]),
	.JOY_Y(~|gun_mode ? joya_0[15:8] : joya_1[15:8]),
	.JOY_TRIG(~|gun_mode ? (joya[4] || joya[5]) :(joyb[4] || joyb[5])),

	.HDE(~HBlank),
	.VDE(~VBlank_orig),
	.CE_PIX(ce_pix_raw),

	.BTN_MODE(gun_btn_mode),
	.SIZE(status[37:36]),
	.SENSOR_DELAY((tia_en ? 8'd20 : 8'd48) + {status[72:70], 1'b0}),
	.LINE_DELAY((tia_en ? 8'd1 : 8'd20)),

	.TARGET(gun_target),
	.SENSOR(gun_sensor),
	.TRIGGER(gun_trigger)
);

logic [3:0] pad_b;
logic [7:0] pad_ax[4];
logic [3:0] pad_wire;
logic [15:0] joya_a, joya_b, joya_c, joya_d;
logic [7:0] pd_a, pd_b, pd_c, pd_d;
logic sb_a, sb_b, sb_c, sb_d;
logic pdb_a, pdb_b, pdb_c, pdb_d;

wire [3:0] paddle_mask = {(portb_type == 2'd3 ? 2'b11 : 2'b00), (porta_type == 2'd3 ? 2'b11 : 2'b00)};

paddle_chooser paddles
(
	.clk        (clk_sys),
	.reset      (reset),
	.mask       (paddle_mask),
	.enable0    (1'b1),
	.enable1    (1'b1),
	.use_multi  (status[52]),
	.mouse      (ps2_mouse),
	.analog     ({joya_3, joya_2, joya_1, joya_0}),
	.paddle     ({pd_3, pd_2, pd_1, pd_0}),
	.buttons_in ({joy3[9], joy2[9], joy1[9], joy0[9]}),
	.alt_b_in   ({joy3[5], joy2[5], joy1[5], joy0[5]}),

	.assigned   ({pad3_assigned, pad2_assigned, pad1_assigned, pad0_assigned}),
	.pd_out     ({pad_ax[3], pad_ax[2], pad_ax[1], pad_ax[0]}),
	.paddle_but (pad_b)
);

logic [31:0] difference0, difference1, difference2, difference3;

wire [3:0] pread_mux1 = status[49] ? {i_read[2], i_read[3], i_read[0], i_read[1]} : i_read;
wire [3:0] pread_mux2 = status[7] ? {pread_mux1[1:0], pread_mux1[3:2]} : pread_mux1;

paddle_timer pt0 (clk_sys, 1, reset || ~paddle_mask[0], {1'b0, pad_ax[0][7:0]}, ~iout[1], pread_mux2[0], pad_wire[0], difference0);
paddle_timer pt1 (clk_sys, 1, reset || ~paddle_mask[1], {1'b0, pad_ax[1][7:0]}, ~iout[1], pread_mux2[1], pad_wire[1], difference1);
paddle_timer pt2 (clk_sys, 1, reset || ~paddle_mask[2], {1'b0, pad_ax[2][7:0]}, ~iout[1], pread_mux2[2], pad_wire[2], difference2);
paddle_timer pt3 (clk_sys, 1, reset || ~paddle_mask[3], {1'b0, pad_ax[3][7:0]}, ~iout[1], pread_mux2[3], pad_wire[3], difference3);

logic [7:0] mouse_x, mouse_y;
logic dir_x, dir_y;
logic ep_do;

logic [3:0] trackball;
logic trackball_button;

wire pada_0, pada_1, padb_0, padb_1;

wire is_rdiff = joya_sw[11] | joyb_sw[11] | keyrdiff;
wire is_ldiff = joya_sw[10] | joyb_sw[10] | keyldiff;
wire is_halt = joya_sw[12] | joyb_sw[12] | keyhalt;
wire is_bw = (joya_sw[6] | joyb_sw[6] | keybw) && tia_en;

logic old_rdiff, old_ldiff, old_bw, old_halt;
wire toggle_rdiff = ~old_rdiff && is_rdiff;
wire toggle_ldiff = ~old_ldiff && is_ldiff;
wire toggle_bw = ~old_bw && is_bw;
wire toggle_paddle = old_auto_paddle != auto_paddle;
wire toggle_halt = old_halt && ~is_halt;

assign status_set = toggle_rdiff || toggle_ldiff || toggle_bw;
always_comb begin
	status_in = status;
	status_in[62] = tia_en && toggle_bw ? ~status[62] : status[62];
	status_in[12] = toggle_rdiff ? ~status[12] : status[12];
	status_in[13] = toggle_ldiff ? ~status[13] : status[13];
end

always @(posedge clk_sys) begin
	logic ps2_old;
	logic xtog, ytog;
	old_rdiff <= is_rdiff;
	old_ldiff <= is_ldiff;
	old_bw <= is_bw;
	old_halt <= is_halt;
	old_auto_paddle <= auto_paddle;

	if (toggle_halt)
		halted <= ~halted;
	if (reset || cart_download)
		halted <= 1'b0;
	if (joya_sw[4])
		auto_paddle <= 0;
	if (joya_sw[9] && ~|status[41:38] && tia_en)
		auto_paddle <= 1;
	if (~tia_en || reset)
		auto_paddle <= 0;

	ps2_old <= ps2_mouse[24];

	if (PAread) begin
		if (mouse_y > 0) begin
			ytog <= ~ytog;
			mouse_y <= mouse_y - 1'd1;
		end
		if (mouse_x > 0) begin
			xtog <= ~xtog;
			mouse_x <= mouse_x - 1'd1;
		end
		trackball <= {ytog, dir_y, xtog, dir_x};

	end
	if (ps2_old != ps2_mouse[24]) begin
		trackball_button <= ps2_mouse[0] | ps2_mouse[1];
		mouse_x <= ps2_mouse[4] ? ~ps2_mouse[15:8] : ps2_mouse[15:8];
		mouse_y <= ps2_mouse[5] ? ~ps2_mouse[23:16] : ps2_mouse[23:16];
		dir_x <= ~ps2_mouse[4];
		dir_y <= ps2_mouse[5];
	end
end

logic [6:0] st_mouse;
logic [3:0] st_m_cnt;

always @(posedge clk_sys)
	st_m_cnt <= st_m_cnt + 1'd1;
ps2 mouse_st (
	.clk           (clk_sys),
	.ce            (!st_m_cnt),
	.reset         (reset),
	.ps2_key       (ps2_key),
	.ps2_mouse     (ps2_mouse),
	.ps2_mouse_ext (ps2_mouse_ext),
	.mouse_atari   (st_mouse)
);

wire joya_b2 = ~PBout[2] && ~tia_en && joy0_type != 5;
wire joyb_b2 = ~PBout[4] && ~tia_en && joy1_type != 5;

logic [15:0] joya, joyb;

wire quadtari_en = status[46] & tia_en;
wire qt_second   = quadtari_en & ~iout[0];

wire portb_savekey   = (portb_type == 8'd11);
wire portb_senza_joy = portb_savekey | (portb_type == 8'd0);
wire qt_pad2 = quadtari_en & portb_senza_joy;

wire [15:0] joya_sw = status[7] ? joy1 : joy0;
wire [15:0] joyb_sw = status[7] ? joy0 : joy1;
assign joya = qt_second ? (qt_pad2 ? joy1 : joy2) : (status[7] ? joy1 : joy0);
assign joyb = qt_second ? joy3 : (status[7] ? joy0 : joy1);

logic key3, key2, key1;
logic key6, key5, key4;
logic key9, key8, key7;
logic keyh, key0, keya;

logic keystart, keyselect, keyhalt, keyrdiff, keyldiff, keybw;

logic [6:0] keypad0, keypad1;
wire [3:0] kp_out0 = PAout[7:4];
wire [3:0] kp_out1 = PAout[3:0];
logic [3:0] robor, robol;

always @(posedge clk_sys) begin
	logic last_ps2key10;
	if(last_ps2key10 != ps2_key[10]) begin
		last_ps2key10 <= ps2_key[10];
		case (ps2_key[8:0])
			9'h16: key1 <= ps2_key[9];
			9'h1E: key2 <= ps2_key[9];
			9'h26: key3 <= ps2_key[9];

			9'h25: key4 <= ps2_key[9];
			9'h2E: key5 <= ps2_key[9];
			9'h36: key6 <= ps2_key[9];
			9'h3D: key7 <= ps2_key[9];
			9'h3E: key8 <= ps2_key[9];
			9'h46: key9 <= ps2_key[9];
			9'h45: key0 <= ps2_key[9];
			9'h4E: keyh <= ps2_key[9];
			9'h55: keya <= ps2_key[9];

			9'h15: key4 <= ps2_key[9];
			9'h1d: key5 <= ps2_key[9];
			9'h24: key6 <= ps2_key[9];
			9'h1c: key7 <= ps2_key[9];
			9'h1b: key8 <= ps2_key[9];
			9'h23: key9 <= ps2_key[9];
			9'h1a: keya <= ps2_key[9];
			9'h22: key0 <= ps2_key[9];
			9'h21: keyh <= ps2_key[9];

			9'h77: key1 <= ps2_key[9];
			9'h4A: key2 <= ps2_key[9];
			9'h7C: key3 <= ps2_key[9];
			9'h6C: key4 <= ps2_key[9];
			9'h75: key5 <= ps2_key[9];
			9'h7D: key6 <= ps2_key[9];
			9'h6B: key7 <= ps2_key[9];
			9'h73: key8 <= ps2_key[9];
			9'h74: key9 <= ps2_key[9];
			9'h69: keya <= ps2_key[9];
			9'h72: key0 <= ps2_key[9];
			9'h7A: keyh <= ps2_key[9];

			9'h05: keyselect <= ps2_key[9];
			9'h06: keystart  <= ps2_key[9];
			9'h04: keybw     <= ps2_key[9];
			9'h0C: keyldiff  <= ps2_key[9];
			9'h03: keyrdiff  <= ps2_key[9];
			9'h0B: keyhalt   <= ps2_key[9];

		endcase
	end
	if (reset)
		{key1, key2, key3, key4, key5, key6, key7, key8, key9, key0, keyh, keya, keystart, keyselect, keybw, keyldiff, keyrdiff, keyhalt} <= '0;

	keypad0 <= '1;
	keypad1 <= '1;

	if (key3) begin keypad0[6] <= kp_out0[0]; keypad1[6] <= kp_out1[0]; end
	if (key2) begin keypad0[5] <= kp_out0[0]; keypad1[5] <= kp_out1[0]; end
	if (key1) begin keypad0[4] <= kp_out0[0]; keypad1[4] <= kp_out1[0]; end

	if (key6) begin keypad0[6] <= kp_out0[1]; keypad1[6] <= kp_out1[1]; end
	if (key5) begin keypad0[5] <= kp_out0[1]; keypad1[5] <= kp_out1[1]; end
	if (key4) begin keypad0[4] <= kp_out0[1]; keypad1[4] <= kp_out1[1]; end

	if (key9) begin keypad0[6] <= kp_out0[2]; keypad1[6] <= kp_out1[2]; end
	if (key8) begin keypad0[5] <= kp_out0[2]; keypad1[5] <= kp_out1[2]; end
	if (key7) begin keypad0[4] <= kp_out0[2]; keypad1[4] <= kp_out1[2]; end

	if (keyh) begin keypad0[6] <= kp_out0[3]; keypad1[6] <= kp_out1[3]; end
	if (key0) begin keypad0[5] <= kp_out0[3]; keypad1[5] <= kp_out1[3]; end
	if (keya) begin keypad0[4] <= kp_out0[3]; keypad1[4] <= kp_out1[3]; end

end

wire [7:0] snac_type = 8'd12;

wire [7:0] gamepad_type = 8'd13;
wire [3:0] snac_pa_in = {USER_IN[3], USER_IN[5], USER_IN[0], (status[6] ? ~USER_IN[2] : USER_IN[1])};
wire [1:0] snac_id_in = {USER_IN[6], USER_IN[4]} & ((~status[5] || status[6]) ? 2'b00 : 2'b11);
wire snac_il_in = (status[6] ? USER_IN[4] : USER_IN[2]);
wire [1:0] snac_fire_7800 = {~USER_IN[2], ~(USER_IN[4] & USER_IN[6])};

wire [6:0] amiga_mouse = {st_mouse[6:5], st_mouse[0], st_mouse[2:1], st_mouse[3]};
wire [3:0] pad_muxa, pad_muxb;

logic [7:0] header_type0, header_type1;
always_comb begin
	case (joy0_type)
		0: header_type0 = 8'd0;
		1: header_type0 = 8'd1;
		2: header_type0 = 8'd2;
		3: header_type0 = 8'd3;
		4: header_type0 = 8'd4;
		5: header_type0 = 8'd1;
		6: header_type0 = 8'd6;
		7: header_type0 = 8'd5;
		8: header_type0 = 8'd7;
		9: header_type0 = 8'd8;
		default: header_type0 = 8'd0;
	endcase

	case (joy1_type)
		0: header_type1 = 8'd0;
		1: header_type1 = 8'd1;
		2: header_type1 = 8'd2;
		3: header_type1 = 8'd3;
		4: header_type1 = 8'd4;
		5: header_type1 = 8'd1;
		6: header_type1 = 8'd6;
		7: header_type1 = 8'd5;
		8: header_type1 = 8'd7;
		9: header_type1 = 8'd8;
		default: header_type1 = 8'd0;
	endcase

	robor[3] = ~($signed(joyar_0[7:0]) > 63);
	robor[2] = ~($signed(joyar_0[7:0]) < -63);
	robor[1] = ~($signed(joyar_0[15:8]) > 63);
	robor[0] = ~($signed(joyar_0[15:8]) < -63);

	robol[3] = ~($signed(joya_0[7:0]) > 63);
	robol[2] = ~($signed(joya_0[7:0]) < -63);
	robol[1] = ~($signed(joya_0[15:8]) > 63);
	robol[0] = ~($signed(joya_0[15:8]) < -63);

	is_snac0 = porta_type == snac_type;
	is_snac1 = portb_type == snac_type;
	USER_OUT = '1;
	if (is_snac0) begin
		{USER_OUT[6], USER_OUT[4], USER_OUT[3], USER_OUT[5], USER_OUT[0], USER_OUT[1]} = {iout[1:0], PAout[7:4]};
	end else if (is_snac1) begin
		{USER_OUT[6], USER_OUT[4], USER_OUT[3], USER_OUT[5], USER_OUT[0], USER_OUT[1]} = {iout[3:2], PAout[3:0]};
	end
	porta_type = |status[41:38] ? {4'd0, status[41:38] - 1'd1} : (auto_paddle ? 2'd3 : header_type0);
	portb_type = |status[45:42] ? {4'd0, status[45:42] - 1'd1} : (auto_paddle ? 2'd3 : header_type1);

	idump = tia_en
		? {((portb_type <= 8'd1) ? ~joyb[5] : 1'b0), ((portb_type <= 8'd1) && !quadtari_en),
		   ((porta_type <= 8'd1) ? ~joya[5] : 1'b0), ((porta_type <= 8'd1) && !quadtari_en)}
		: {joyb[4], joyb[5], joya[4], joya[5]};
	PAin[7:4] = {~joya[0], ~joya[1], ~joya[2], ~joya[3]};
	PAin[3:0] = portb_savekey ? 4'b1111 : {~joyb[0], ~joyb[1], ~joyb[2], ~joyb[3]};
	ilatch[0] = tia_en ? ~joya[4] : ~(joya[4] || joya[5]);
	ilatch[1] = portb_savekey ? 1'b1
	                         : (tia_en ? ~joyb[4] : ~(joyb[4] || joyb[5]));
	pad_muxa = ~status[49] ? {~pad_b[0], ~pad_b[1], pad_wire[1:0]} : {~pad_b[1:0], pad_wire[0], pad_wire[1]};
	pad_muxb = ~status[49] ? {~pad_b[2], ~pad_b[3], pad_wire[3:2]} : {~pad_b[3:2], pad_wire[2], pad_wire[3]};
	case (porta_type)
		0: begin PAin[7:4] = 4'b1111; ilatch[0] = 1'b1; idump[1:0] = 2'b00; end
		2: if (~gun_port) begin PAin[7:4] = {3'b111, gun_trigger}; ilatch[0] = ~gun_sensor; idump[1:0] = 2'b00; end
		3: begin PAin[7:4] = {pad_muxa[3:2], 2'b11}; idump[1:0] = pad_muxa[1:0]; ilatch[0] = 1'b1; end
		4: begin PAin[7:4] = trackball; ilatch[0] = ~trackball_button; idump[1:0] = 2'b00; end
		5: begin PAin[7:4] = PAout[7:4]; ilatch[0] = keypad0[6]; idump[1:0] = keypad0[5:4]; end
		6: begin PAin[7:4] = {2'b11, st_mouse[1:0]}; ilatch[0] = st_mouse[5]; idump[1:0] = 2'b00; end
		7: begin PAin[7:4] = st_mouse[3:0]; ilatch[0] = ~st_mouse[5]; idump[1:0] = st_mouse[6:5]; end
		8: begin PAin[7:4] = amiga_mouse[3:0]; ilatch[0] = ~amiga_mouse[5]; idump[1:0] = amiga_mouse[6:5]; end
		9: begin idump[1:0] = {joya[5], joya[9]}; end
		10: begin PAin[7:4] = robol; end
		11: begin PAin[6] = ep_do; end
		snac_type: if (!qt_second) begin
			PAin[7:4] = snac_pa_in; ilatch[0] = snac_il_in;
			idump[1:0] = tia_en ? snac_id_in[1:0] : snac_fire_7800;
		end
		gamepad_type: idump[1:0] = {~joya[5], 1'b1};
		default: ;
	endcase

	case (portb_type)
		0: begin PAin[3:0] = 4'b1111; ilatch[1] = 1'b1; idump[3:2] = 2'b00; end
		2: if (gun_port) begin PAin[3:0] = {3'b111, gun_trigger}; ilatch[1] = ~gun_sensor; idump[3:2] = 2'b00; end
		3: begin PAin[3:0] = {pad_muxb[3:2], 2'b11}; idump[3:2] = pad_muxb[1:0]; ilatch[1] = 1'b1; end
		4: if (porta_type != 4) begin PAin[3:0] = trackball; ilatch[1] = ~trackball_button; idump[3:2] = 2'b00; end
		5: begin PAin[3:0] = PAout[3:0]; ilatch[1] = keypad1[6]; idump[3:2] = keypad1[5:4]; end
		6: begin PAin[3:0] = {2'b11, st_mouse[1:0]}; ilatch[1] = st_mouse[5]; idump[3:2] = 2'b00; end
		7: begin PAin[3:0] = st_mouse[3:0]; ilatch[1] = ~st_mouse[5]; idump[3:2] = st_mouse[6:5]; end
		8: begin PAin[3:0] = amiga_mouse[3:0]; ilatch[1] = ~amiga_mouse[5]; idump[3:2] = amiga_mouse[6:5]; end
		9: begin idump[3:2] = {joyb[5], joyb[9]}; end
		10: begin PAin[3:0] = robor; end
		11: begin PAin[2] = ep_do; end
		snac_type: if (~is_snac0 && !qt_second) begin PAin[3:0] = snac_pa_in; ilatch[1] = snac_il_in; idump[3:2] = tia_en ? snac_id_in[1:0] : snac_fire_7800; end
		gamepad_type: idump[3:2] = {~joyb[5], 1'b1};
		default: ;
	endcase

	if (joya_b2)
		ilatch[0] = 1;
	if (joyb_b2)
		ilatch[1] = 1;
end

logic hb_cofi, hs_cofi, vb_cofi, vs_cofi;
logic [7:0] r_cofi, g_cofi, b_cofi;
reg ce_pix;

cofi coffee (
	.clk        (CLK_VIDEO),
	.pix_ce     (ce_pix),
	.enable     (status[20]),
	.hblank     (HBlank),
	.vblank     (VBlank),
	.hs         (HSync),
	.vs         (VSync),
	.red        (R),
	.green      (G),
	.blue       (B),

	.hblank_out (hb_cofi),
	.vblank_out (vb_cofi),
	.hs_out     (hs_cofi),
	.vs_out     (vs_cofi),
	.red_out    (r_cofi),
	.green_out  (g_cofi),
	.blue_out   (b_cofi)
);

assign VGA_F1 = tia_f1;
assign CLK_VIDEO = clk_vid;
assign VGA_SL = sl[1:0];

wire       vcrop_en = status[22];
wire [3:0] vcopt    = status[26:23];
reg  [4:0] voff;
wire [1:0] ar = status[51:50];
wire [11:0] arx,ary;

always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

always_comb begin
	arx = 0;
	ary = 0;
	if (tia_en) begin
		arx = region_select ? 12'd80 : 12'd640;
		ary = region_select ? 12'd69 : 12'd561;
	end else if (~region_select) begin
		if (~status[14]) begin
			if (status[29]) begin
				arx = 12'd3471;
				ary = 12'd2632;
			end else begin
				arx = 12'd3720;
				ary = 12'd2611;
			end
		end else begin
			if (status[29]) begin
				arx = 12'd2979;
				ary = 12'd2626;
			end else begin
				arx = 12'd3200;
				ary = 12'd2611;
			end
		end
	end else begin
		if (~status[14]) begin
			if (status[29]) begin
				arx = 12'd3968;
				ary = 12'd2993;
			end else begin
				arx = 12'd992;
				ary = 12'd697;
			end
		end else begin
			if (status[29]) begin
				arx = 12'd1819;
				ary = 12'd1595;
			end else begin
				arx = 12'd2560;
				ary = 12'd2091;
			end
		end
	end
end

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? arx : (ar - 1'd1)),
	.ARY((!ar) ? ary : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[28:27])
);

wire [2:0] scale = status[11:9];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

reg ce_pix_old;
assign ce_pix = ce_pix_raw & ~ce_pix_old;

always @(posedge CLK_VIDEO) begin : pix_edge_gen
	ce_pix_old <= ce_pix_raw;
end

video_mixer #(.LINE_LENGTH(372), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	.*,

	.VGA_DE(vga_de),
	.hq2x(scale==1),
	.HSync(hs_cofi),
	.HBlank(hb_cofi),
	.VSync(vs_cofi),
	.VBlank(vb_cofi),

	.R((gun_en & gun_target) ? 8'd255 : r_cofi),
	.G((gun_en & gun_target) ? 8'd0 : g_cofi),
	.B((gun_en & gun_target) ? 8'd0 : b_cofi)
);

wire bk_save_write = use_sk ? sk_write : (~RW & hsc_ram_cs);

reg bk_pending;

always @(posedge clk_sys) begin
	if (bk_ena && ~OSD_STATUS && bk_save_write)
		bk_pending <= 1'b1;
	else if (bk_state)
		bk_pending <= 1'b0;
end

logic [7:0] sk_data;
logic [14:0] sk_addr;
logic sk_read, sk_write;

logic [7:0] sk_ram_do;
logic [14:0] sk_ram_addr;

assign use_sk = porta_type == 11 || portb_type == 11;

EEPROM_24LC0X
#(
	.ADDR_WIDTH (15),
	.PAGE_WIDTH (6)
) savekey (
	.clk            (clk_sys),
	.ce             (1),
	.reset          (reset || ~use_sk),
	.SCL            (portb_type == 11 ? PAout[3] : PAout[7]),
	.SDA_in         (portb_type == 11 ? PAout[2] : PAout[6]),
	.SDA_out        (ep_do),
	.E_id           (0),
	.WC_n           (0),
	.data_from_ram  (hsc_ram_dout),
	.data_to_ram    (sk_ram_do),
	.ram_addr       (sk_ram_addr),
	.ram_read       (sk_read),
	.ram_write      (sk_write),
	.ram_done       (1)
);

dpram_dc #(.widthad_a(14)) hsc_ram
(
	.clock_a   (clk_sys),
	.address_a (use_sk ? sk_ram_addr : bios_addr),
	.data_a    (use_sk ? sk_ram_do : din),
	.wren_a    (use_sk ? sk_write : (~RW & hsc_ram_cs)),
	.q_a       (hsc_ram_dout),

	.clock_b   (clk_sys),
	.address_b ({sd_lba0[5:0],sd_buff_addr}),
	.data_b    (sd_buff_dout),
	.wren_b    (sd_buff_wr & sd_ack[0]),
	.q_b       (sd_buff_din[0])
);

wire downloading = cart_download;
reg old_downloading = 0;
reg bk_ena = 0;
always @(posedge clk_sys) begin

	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	if(downloading && img_mounted[0] && !img_readonly) bk_ena <= 1;
end

wire bk_load    = 0;
wire bk_save    = (bk_pending & OSD_STATUS);
reg  bk_loading = 0;
reg  bk_state   = 0;

always @(posedge clk_sys) begin : save_block
	reg old_load = 0, old_save = 0, old_ack;

	old_load <= bk_load & bk_ena;
	old_save <= bk_save & bk_ena;
	old_ack  <= sd_ack[0];

	if(~old_ack & sd_ack[0]) {sd_rd0, sd_wr0} <= 0;

	if(!bk_state) begin
		if((~old_load & bk_load) | (~old_save & bk_save)) begin
			bk_state <= 1;
			bk_loading <= bk_load;
			sd_lba0 <= 0;
			sd_rd0 <=  bk_load;
			sd_wr0 <= ~bk_load;
		end
		if(old_downloading & ~downloading & |img_size & bk_ena) begin
			bk_state <= 1;
			bk_loading <= 1;
			sd_lba0 <= 0;
			sd_rd0 <= 1;
			sd_wr0 <= 0;
		end
	end else begin
		if(old_ack & ~sd_ack[0]) begin
			if(&sd_lba0[5:0]) begin
				bk_loading <= 0;
				bk_state <= 0;
			end else begin
				sd_lba0 <= sd_lba0 + 1'd1;
				sd_rd0  <=  bk_loading;
				sd_wr0  <= ~bk_loading;
			end
		end
	end
end

endmodule

module lfsr(
	output [N-1:0] rnd
);

parameter N = 63;

lcell lc0(~(rnd[N - 1] ^ rnd[N - 3] ^ rnd[N - 4] ^ rnd[N - 6] ^ rnd[N - 10]), rnd[0]);
generate
	genvar i;
	for (i = 0; i <= N - 2; i = i + 1) begin : lcn
		lcell lc(rnd[i], rnd[i + 1]);
	end
endgenerate

endmodule

