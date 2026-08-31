// k7800 (c) by Jamie Blanks

// k7800 is licensed under a
// Creative Commons Attribution-NonCommercial 4.0 International License.

// You should have received a copy of the license along with this
// work. If not, see http://creativecommons.org/licenses/by-nc/4.0/.


// Covers the bank switching, ram, and audio hardware from carts
module cart
(
	input  logic        clk_sys,
	input  logic        pclk0,
	input  logic        pclk1,
	input  logic [15:0] address_in,
	input  logic [7:0]  din,
	input  logic        halt_n,
	input  logic [7:0]  rom_din,
	input  logic [15:0] cart_flags,
	input  logic [31:0] cart_size,
	input  logic [7:0]  cart_save,
	input  logic        cart_cs,
	input  logic        rw,
	input  logic        reset,
	input  logic        hsc_en,
	input  logic  [7:0] hsc_ram_din,
	input  logic  [7:0] cart_xm,
	input  logic  [7:0] open_bus,
	input  logic [10:0] ps2_key,
	input  logic        pokey_irq_en,
	input  logic        minnie_en,
	input  logic [7:0]  cartram_data,

	output logic        IRQ_n,
	output logic [7:0]  dout,
	output logic        hsc_ram_cs,
	output logic        cart_read,
	output logic [15:0] pokey_audio_r,
	output logic [15:0] pokey_audio_l,
	output logic [15:0] minnie_audio,
	output logic [15:0] ym_audio_r,
	output logic [15:0] ym_audio_l,
	output logic [15:0] covox_r,
	output logic [15:0] covox_l,
	output logic [15:0] arm_audio,
	output logic        external_audio,
	output logic [24:0] rom_address,
	output logic [17:0] cartram_addr,
	output logic        cartram_wr,
	output logic        cartram_rd,
	output logic [7:0]  cartram_wrdata,

	output logic  [7:0] bup_cmd,
	output logic        bup_strobe,
	output logic        bup_en
);

logic [7:0] bank_reg;
logic [7:0] ram_dout;
logic [7:0] ym_dout;
logic [7:0] hsc_rom_dout;
logic [7:0] hsc_ram_dout;
logic [7:0] pokey4k_dout, pokey2_dout;
logic [7:0] minnie_dout;
logic       minnie_active;

logic rom_cs, ram_cs, pokey_cs, ym_cs;
logic [2:0] hardware_map[16];
logic [7:0] bank_map[16];
logic [2:0] bank_type;
logic [31:0] address_offset;
logic [2:0] cart_cs_reg, cart_cs_reg_m;
logic [7:0] bank_mask;
logic [16:0] ram_mask;
logic [7:0] XCTRL1, XCTRL2, XCTRL3, XCTRL4, XCTRL5;
logic souper_ram_cs;
logic [24:0] souper_addr;
wire souper_en = cart_flags[12];
logic [11:0] souper_bank;
logic [2:0] ram_bank;
logic [8:0] bs_map;
logic [1:0] bankset_count;
logic souper_wr;
logic pokey_irq_n, ym_irq_n;

logic [31:0] cart_size_bs;

wire XCTRL1_cs = (cart_xm[0] && address_in[15:4] == 8'h47) && cart_cs;

wire ym_en = cart_flags[11] || XCTRL1[7];
logic [24:0] ext_addr;
logic        ext_req;
logic  [7:0] ext_data;
logic        ext_ack;

logic [24:0] ext_addr_held;
logic  [3:0] ext_cnt;
logic        ext_busy;

wire ext_apri = souper_en && ext_req && !cart_cs && !ext_busy;
wire ext_hold = souper_en && (ext_apri || ext_busy);

assign cart_read = (rw && cart_cs && ~cartram_cs) || ext_hold;
always @(posedge clk_sys) begin
	if (reset) begin
		XCTRL1 <= 0;
	end else if (pclk0) begin
		if (XCTRL1_cs && ~rw)
		case (address_in[3:0])
			4'h0: XCTRL1 <= din;

		endcase
	end
end

wire is_9b = cart_flags[3];
wire is_bankset = cart_flags[13];
wire is_bankset_mem = cart_flags[14];
wire bankset_banks = is_bankset & bankset_count[1];
assign cart_size_bs = is_bankset ? (cart_size >> 1'd1) : cart_size;

wire [7:0] num_banks = (cart_size_bs >> 14);
wire [7:0] highest_bank = num_banks ? num_banks - 1'd1 : is_9b;
wire [7:0] second_highest_bank = is_9b ? 8'd0 : (highest_bank ? highest_bank - 1'd1 : 8'd0);
wire [7:0] sg_bank = (bank_reg & bank_mask) + is_9b;
wire is_bankset_52k = (is_bankset && cart_size_bs == 32'hD000);

always_ff @(posedge clk_sys) if (pclk1) begin
	hardware_map <= '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0};
	bank_map <= '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
	bank_type <= 3'd0;
	address_offset <= 32'd0;
	bank_mask <= 8'b11111111;
	ram_mask <= '1;
	bs_map <= 9'd0;
	if (~halt_n) begin
		if (is_bankset && ~bankset_count[1])
			bankset_count <= bankset_count + 1'd1;
	end else begin
		bankset_count <= 2'd0;
	end

	if (cart_flags[8]) begin
		hardware_map <= '{3'd0, 3'd0, 3'd0, 3'd0, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4};
		bank_map <= '{8'd0, 8'd0, 8'd0, 8'd0, 8'd13, 8'd13, 8'd12, 8'd12, 8'd15, 8'd15, 8'd0, 8'd0, 8'd0, 8'd0, 8'd14, 8'd14};
		bank_map[10] <= {bank_reg[2:0], 1'b0};
		bank_map[11] <= {bank_reg[2:0], 1'b0};
		bank_map[12] <= {bank_reg[2:0], 1'b1};
		bank_map[13] <= {bank_reg[2:0], 1'b1};
		bank_type <= 3'd1;
	end else if (cart_flags[9]) begin
		hardware_map <= '{3'd0, 3'd0, 3'd0, 3'd0, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4};
		bank_map <= '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd0, 8'd2, 8'd2, 8'd2, 8'd2, 8'd3, 8'd3, 8'd3, 8'd3};
		bank_map[4] <= {3'b000, bank_reg[1]};
		bank_map[5] <= {3'b000, bank_reg[1]};
		bank_map[6] <= {3'b000, bank_reg[1]};
		bank_map[7] <= {3'b000, bank_reg[1]};
		bank_type <= 3'd3;
	end else if (cart_flags[12]) begin
		hardware_map <= '{3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4};
		bank_type <= 3'd4;
	end else if (cart_flags[13] || cart_flags[14] || cart_flags[1] || cart_size_bs >= 32'h10000) begin
		hardware_map <= '{3'd0, 3'd0, 3'd0, 3'd0, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4, 3'd4};
		bank_map <= '{8'd0, 8'd0, 8'd0, 8'd0, second_highest_bank, second_highest_bank, second_highest_bank, second_highest_bank, 8'd0, 8'd0, 8'd0, 8'd0, highest_bank, highest_bank, highest_bank, highest_bank};
		bank_map[8] <= sg_bank;
		bank_map[9] <= sg_bank;
		bank_map[10] <= sg_bank;
		bank_map[11] <= sg_bank;
		if (is_bankset && cart_size_bs == 32'h8000) begin
			bank_mask <= 8'b00000001;
			bs_map <= 9'b0_0000_0010;
			bank_map[8] <= 8'd0;
			bank_map[9] <= 8'd0;
			bank_map[10] <= 8'd0;
			bank_map[11] <= 8'd0;
		end else if (is_bankset && cart_size_bs == 32'hC000) begin
			bank_mask <= 8'b00000011;
			bs_map <= 9'b0_0000_0011;
			bank_map[4] <= 8'd0;
			bank_map[5] <= 8'd0;
			bank_map[6] <= 8'd0;
			bank_map[7] <= 8'd0;
			bank_map[8] <= 8'd1;
			bank_map[9] <= 8'd1;
			bank_map[10] <= 8'd1;
			bank_map[11] <= 8'd1;
		end else if (is_bankset_52k) begin
			hardware_map[3] <= 3'd4;
			bank_map[3] <= 8'd0;
			bank_map[4] <= 8'd1;
			bank_map[5] <= 8'd1;
			bank_map[6] <= 8'd1;
			bank_map[7] <= 8'd1;
			bank_map[8] <= 8'd2;
			bank_map[9] <= 8'd2;
			bank_map[10] <= 8'd2;
			bank_map[11] <= 8'd2;
			bank_map[12] <= 8'd3;
			bank_map[13] <= 8'd3;
			bank_map[14] <= 8'd3;
			bank_map[15] <= 8'd3;
		end else if (cart_size_bs[22]) begin
			bank_mask <= 8'b11111111;
			bs_map <= 9'b1_0000_0000;
		end else if (cart_size_bs[21]) begin
			bank_mask <= 8'b01111111;
			bs_map <= 9'b0_1000_0000;
		end else if (cart_size_bs[20]) begin
			bank_mask <= 8'b00111111;
			bs_map <= 9'b0_0100_0000;
		end else if (cart_size_bs[19]) begin
			bank_mask <= 8'b00011111;
			bs_map <= 9'b0_0010_0000;
		end else if (cart_size_bs[18]) begin
			bank_mask <= 8'b00001111;
			bs_map <= 9'b0_0001_0000;
		end else if (cart_size_bs[17]) begin
			bank_mask <= 8'b00000111;
			bs_map <= 9'b0_0000_1000;
		end else if (cart_size_bs[16]) begin
			bank_mask <= 8'b00000011;
			bs_map <= 9'b0_0000_0100;
		end else if (cart_size_bs[15]) begin
			bank_mask <= 8'b00000001;
			bs_map <= 9'b0_0000_0010;
		end else begin
			bank_mask <= 8'b00000000;
			bs_map <= 9'b0_0000_0001;
		end
		bank_type <= 3'd0;
	end else begin
		if (cart_size <= 32'h2000)
			hardware_map <= '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd1, 3'd1};
		else if (cart_size <= 32'h4000)
			hardware_map <= '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd1, 3'd1, 3'd1, 3'd1};
		else if (cart_size <= 32'h8000)
			hardware_map <= '{3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd0, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1};
		else if (cart_size <= 32'hC000)
			hardware_map <= '{3'd0, 3'd0, 3'd0, 3'd0, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1, 3'd1};
		address_offset <= cart_size <= 32'h10000 ? 32'h10000 - cart_size : 32'd0;
		bank_type <= 3'd2;
	end

	if (cart_flags[2] || cart_flags[14]) begin
		hardware_map[4] <= 3'd3;
		hardware_map[5] <= 3'd3;
		hardware_map[6] <= 3'd3;
		hardware_map[7] <= 3'd3;
	end else if (cart_flags[5]) begin
		hardware_map[4] <= 3'd3;
		hardware_map[5] <= 3'd3;
		hardware_map[6] <= 3'd3;
		hardware_map[7] <= 3'd3;
	end else if (cart_flags[7]) begin
		hardware_map[4] <= 3'd3;
		hardware_map[5] <= 3'd3;
		hardware_map[6] <= 3'd3;
		hardware_map[7] <= 3'd3;
		ram_mask[8] <= 0;
		ram_mask[13:12] <= 2'b00;
	end else if (cart_flags[4]) begin
		hardware_map[4] <= 3'd4;
		hardware_map[5] <= 3'd4;
		hardware_map[6] <= 3'd4;
		hardware_map[7] <= 3'd4;
		bank_map[4] <= 4'd6;
		bank_map[5] <= 4'd6;
		bank_map[6] <= 4'd6;
		bank_map[7] <= 4'd6;
	end

	if (XCTRL1[5]) begin
		hardware_map[4] <= 3'd3;
		hardware_map[5] <= 3'd3;
	end
	if (XCTRL1[6]) begin
		hardware_map[6] <= 3'd3;
		hardware_map[7] <= 3'd3;
	end

end

assign IRQ_n = (pokey_irq_en ? pokey_irq_n : 1'b1) & (ym_en ? ym_irq_n : 1'b1);

wire is_pokey_450 = (((cart_flags[6] || XCTRL1[4]) && address_in[15:4] == 12'h45) && cart_cs);
wire is_pokey_440 = (((cart_flags[10] || XCTRL1[4]) && address_in[15:4] == 8'h44) && cart_cs);
wire is_pokey_4k = ((cart_flags[0] && address_in[15:14] == 2'b01) && cart_cs);
wire is_pokey_800 = ((cart_flags[15] && address_in[15:11] == 5'h1) && cart_cs);
wire pokey4k_wo = cart_flags[0] && (cart_flags[3] || is_bankset);
wire is_covox = address_in[15:4] == 12'h43;

wire is_ym = ((ym_en && address_in[15:1] == 15'h230) && cart_cs);

wire is_minnie = (minnie_en && !is_ym && !XCTRL1_cs &&
                  address_in[15:5] == 11'b0000_0100_011 && cart_cs);

assign external_audio = cart_flags[6] || cart_flags[10] || cart_flags[0] || is_covox || cart_flags[11] || cart_flags[15] || minnie_active;

logic [3:0] address_index;
assign address_index = address_in[15:12];

always_comb begin
	pokey_cs = 0;
	pokey2_cs = 0;
	ram_cs = 0;
	ym_cs = 0;
	rom_address = 25'd0;
	if (is_pokey_450 || is_pokey_800)
		pokey_cs = 1;
	else if (is_pokey_440)
		pokey2_cs = 1;
	else if (is_pokey_4k && (~pokey4k_wo || ~rw))
		pokey_cs = 1;
	else if (is_ym)
		ym_cs = 1;
	else if (is_bankset_mem & ~rw & &address_in[15:14])
		ram_cs = 1;
	else if (cart_cs) case (hardware_map[address_index])
		3'd1: begin
			rom_address = {1'b0, address_in - address_offset[15:0]};
		end
		3'd2: pokey_cs = 1'b1;
		3'd3: ram_cs = 1'b1;
		3'd4: begin
			case (bank_type)
				3'd0:
					if (is_bankset_52k) begin
						case (bank_map[address_index])
							8'd0: rom_address = (bankset_banks ? 17'h0D000 : 17'h0000) + address_in[11:0];
							8'd1: rom_address = (bankset_banks ? 17'h0E000 : 17'h1000) + address_in[13:0];
							8'd2: rom_address = (bankset_banks ? 17'h12000 : 17'h5000) + address_in[13:0];
							8'd3: rom_address = (bankset_banks ? 17'h16000 : 17'h9000) + address_in[13:0];
							default: ;
						endcase
					end else begin
						rom_address = {bank_map[address_index], address_in[13:0]} + {(bankset_banks ? bs_map : 9'd0), 14'd0};
					end
				3'd1:
					rom_address = {1'b0, bank_map[address_index], address_in[12:0]};
				3'd2:
					rom_address = {3'b000, address_in - address_offset[15:0]};
				3'd3:
					rom_address = {bank_map[address_index], address_in[13:0]};
				3'd4:
					rom_address = souper_addr;
				default: ;
			endcase
		end
		default: ;
	endcase

	if (ext_hold)
		rom_address = ext_apri ? ext_addr : ext_addr_held;
end

logic [7:0] covox_reg[4];

always_comb begin
	covox_r = {{1'b0, covox_reg[0]} + covox_reg[2], 7'd0};
	covox_l = {{1'b0, covox_reg[1]} + covox_reg[3], 7'd0};
end

always_ff @(posedge clk_sys) begin
	if (reset) begin
		bank_reg <= 8'd0;
		ram_bank <= 3'd0;
		covox_reg <= '{8'd0, 8'd0, 8'd0, 8'd0};
	end else if (~rw & cart_cs & pclk0) begin
		if (is_covox) begin
			covox_reg[address_in[1:0]] <= din;
		end
		if (bank_type == 3'd0 && address_in[15:14] == 2'b10) begin
			if (cart_flags[5]) begin
				ram_bank <= din[7:5];
				bank_reg <= din[4:0];
			end else begin
				bank_reg <= din;
			end
		end else if (bank_type == 3'd1 && (address_in[15:4]) == 12'hFF8)
			bank_reg <= address_in[2:0];
		else if (bank_type == 3'd3 && address_in[15])
			bank_reg <= din[1:0];
	end
end

wire [14:0] bankset_ram_addr = {bankset_banks | (~rw & &address_in[15:14]), address_in[13:0]};
assign cartram_addr = is_bankset_mem ? bankset_ram_addr : (souper_en ? souper_addr[17:0] : ({ram_bank, address_in[13:0]} & ram_mask));
wire   cartram_cs = (ram_cs || (~souper_ram_cs && souper_en));
assign cartram_wr = cartram_cs && ~rw;
assign cartram_rd = cartram_cs &&  rw;
assign cartram_wrdata = din;
assign ram_dout = cartram_data;

always_comb begin
	case(hardware_map[address_index])
		3'd0: dout = open_bus;
		3'd1, 3'd4: dout = rom_din;
		3'd2: dout = pokey4k_dout;
		3'd3: dout = ram_dout;
		default: dout = open_bus;
	endcase

	if (is_ym)
		dout = ym_dout;
	if (hsc_rom_cs)
		dout = hsc_rom_dout;
	if (hsc_ram_cs)
		dout = hsc_ram_dout;
	if (is_pokey_450 || is_pokey_800 || (is_pokey_4k && ~pokey4k_wo))
		dout = pokey4k_dout;
	if (is_pokey_440)
		dout = pokey2_dout;
	if (is_minnie)
		dout = minnie_dout;
	if (souper_en) begin
		if (~souper_ram_cs)
			dout = ram_dout;
		else
			dout = rom_din;
	end
	if (arm_cs)
		dout = arm_dout;

end

logic [3:0] ch0, ch1, ch2, ch3, ch0_2, ch1_2, ch2_2, ch3_2;
logic [5:0] pokey_mux, pokey2_mux;
logic [3:0] pokey2_cs;
logic using_two_pokey;

always @(posedge clk_sys) begin
	if (reset)
		using_two_pokey <= 0;
	if (is_pokey_440)
		using_two_pokey <= 1;

	pokey_mux <= ch0 + ch1 + ch2 + ch3;
	pokey2_mux <= ch0_2 + ch1_2 + ch2_2 + ch3_2;
end

assign pokey_audio_r = (cart_flags[0] || cart_flags[6] || cart_flags[10] || cart_flags[15]) ? {pokey_mux, 10'd0} : 16'd0;
assign pokey_audio_l = ~using_two_pokey ? pokey_audio_r : {pokey2_mux, 10'd0};

logic minnie_ph1;
always_ff @(posedge clk_sys)
	minnie_ph1 <= pclk0;

wire [15:0] minnie_aud;

minnie the_mouse (
	.clk       (clk_sys),
	.ph1_en    (minnie_ph1),
	.ph2_en    (pclk0),
	.reset     (reset),
	.a         (address_in[4:0]),
	.cs        (is_minnie),
	.rw        (rw),
	.d_in      (din),
	.d_out     (minnie_dout),
	.d_oe      (),
	.sample    (),
	.sample_en (),
	.aud       (minnie_aud)
);

always_ff @(posedge clk_sys) begin
	if (reset || ~minnie_en)
		minnie_active <= 1'b0;
	else if (is_minnie && ~rw)
		minnie_active <= 1'b1;
end

assign minnie_audio = minnie_active ? minnie_aud : 16'd0;

logic [5:0] keyboard_scan;
logic [1:0] keyboard_response;
logic old_ps2_10;
always @(posedge clk_sys)
	old_ps2_10 <= ps2_key[10];

ps2_to_atari800 ps2_to_pokey (
	.CLK               (clk_sys),
	.RESET_N           (~reset),
	.INPUT             ({12'h000, 3'b000, ps2_key[9], 3'b000, ps2_key[8], 4'h0, ps2_key[7:0]}),
	.KEYBOARD_SCAN     (keyboard_scan),
	.KEYBOARD_RESPONSE (keyboard_response)
);

pokey the_penguin (
	.CLK                  (clk_sys),
	.ENABLE_179           (pclk0),
	.ADDR                 (address_in[3:0]),
	.DATA_IN              (din),
	.WR_EN                (~rw & pokey_cs),
	.RESET_N              (~reset),
	.keyboard_scan_enable (old_ps2_10 != ps2_key[10]),
	.keyboard_scan        (keyboard_scan),
	.keyboard_response    (keyboard_response),

	.POT_IN               (),
	.SIO_IN1              (),
	.SIO_IN2              (),
	.SIO_IN3              (),
	.DATA_OUT             (pokey4k_dout),
	.CHANNEL_0_OUT        (ch0),
	.CHANNEL_1_OUT        (ch1),
	.CHANNEL_2_OUT        (ch2),
	.CHANNEL_3_OUT        (ch3),

	.IRQ_N_OUT            (pokey_irq_n),
	.SIO_OUT1             (),
	.SIO_OUT2             (),
	.SIO_OUT3             (),
	.SIO_CLOCKIN_IN       (1'b1),
	.SIO_CLOCKIN_OUT      (),
	.SIO_CLOCKIN_OE       (),
	.SIO_CLOCKOUT         (),
	.POT_RESET            ()
);

pokey return_of_pokey (
	.CLK                  (clk_sys),
	.ENABLE_179           (pclk0),
	.ADDR                 (address_in[3:0]),
	.DATA_IN              (din),
	.WR_EN                (~rw & pokey2_cs),
	.RESET_N              (~reset),
	.keyboard_scan_enable (1'b0),
	.keyboard_scan        (),
	.keyboard_response    (),

	.POT_IN               (),
	.SIO_IN1              (),
	.SIO_IN2              (),
	.SIO_IN3              (),
	.DATA_OUT             (pokey2_dout),
	.CHANNEL_0_OUT        (ch0_2),
	.CHANNEL_1_OUT        (ch1_2),
	.CHANNEL_2_OUT        (ch2_2),
	.CHANNEL_3_OUT        (ch3_2),

	.IRQ_N_OUT            (),
	.SIO_OUT1             (),
	.SIO_OUT2             (),
	.SIO_OUT3             (),
	.SIO_CLOCKIN_IN       (1'b1),
	.SIO_CLOCKIN_OUT      (),
	.SIO_CLOCKIN_OE       (),
	.SIO_CLOCKOUT         (),
	.POT_RESET            ()
);

wire [15:0] ym_audio_lo, ym_audio_ro;

jt51 ym2151 (
	.rst      (reset),
	.clk      (clk_sys),
	.cen      (pclk1 || pclk0),
	.cen_p1   (pclk0),
	.cs_n     (~ym_cs),
	.wr_n     (rw),
	.a0       (address_in[0]),
	.din      (din),
	.dout     (ym_dout),
	.ct1      (),
	.ct2      (),
	.irq_n    (ym_irq_n),
	.sample   (),
	.left     (),
	.right    (),
	.xleft    (),
	.xright   (),
	.dacleft  (ym_audio_lo),
	.dacright (ym_audio_ro)
);

always @(posedge clk_sys) begin
	if (cart_flags[11] || XCTRL1[7]) begin
		ym_audio_r <= ym_audio_ro;
		ym_audio_l <= ym_audio_lo;
	end else begin
		ym_audio_r <= 0;
		ym_audio_l <= 0;
	end
end

assign hsc_ram_cs = address_in[15:11] == 5'd2 && hsc_en;
wire hsc_rom_cs = address_in[15:12] == 4'd3 && hsc_en;

spram #(
	.addr_width(12),
	.mem_name("HSC"),
	.mem_init_file("mem4.mif"),
	.sim_init_file("rtl/mem4.hex")
) hsc_rom
(
	.address (address_in[11:0]),
	.clock   (clk_sys),
	.data    (8'd0),
	.wren    (1'b0),
	.cs      (1'b1),
	.q       (hsc_rom_dout)
);

assign hsc_ram_dout = hsc_ram_din;

logic souper_rom_cs;
assign souper_addr = {souper_bank, address_in[6:0]};

souper soup_soup (
	.clk        (clk_sys),
	.pclk1      (pclk0),
	.reset      (reset),
	.halt_n     (halt_n),
	.data       (din),
	.rw         (rw),
	.addr_15    (address_in[15]),
	.addr_14    (address_in[14]),
	.addr_13    (address_in[13]),
	.addr_12    (address_in[12]),
	.addr_11    (address_in[11]),
	.addr_10    (address_in[10]),
	.addr_9     (address_in[9]),
	.addr_8     (address_in[8]),
	.addr_7     (address_in[7]),
	.addr_2     (address_in[2]),
	.addr_1     (address_in[1]),
	.addr_0     (address_in[0]),
	.romSel_n   (souper_rom_cs),
	.ramSel_n   (souper_ram_cs),
	.oe_n       (),
	.wr_n       (souper_wr),
	.mapAddr_7p (souper_bank),
	.audCom     (aud_com),
	.audReq_n   (aud_req_n)
);

logic [7:0] aud_com;
logic       aud_req_n, aud_req_d;
logic [7:0] arm_dout;
logic       arm_busy;

wire arm_cs = souper_en && cart_cs && (address_in[15:3] == 13'h008A);
wire arm_wr = arm_cs && ~rw && pclk0;
wire arm_rd = arm_cs &&  rw && pclk0;

always_ff @(posedge clk_sys) aud_req_d <= aud_req_n;
wire aud_req_edge = (aud_req_n != aud_req_d);

assign bup_cmd    = aud_com;
assign bup_strobe = aud_req_edge;
assign bup_en     = souper_en;

always_ff @(posedge clk_sys) begin
	ext_ack <= 1'b0;
	if (reset) begin
		ext_busy <= 1'b0;
		ext_cnt  <= 4'd0;
	end else if (ext_apri) begin
		ext_busy      <= 1'b1;
		ext_cnt       <= 4'd0;
		ext_addr_held <= ext_addr;
	end else if (ext_busy) begin
		if (cart_cs) begin

			ext_busy <= 1'b0;
		end else begin
			ext_cnt <= ext_cnt + 1'd1;
			if (ext_cnt == 4'd9) begin
				ext_data <= rom_din;
				ext_ack  <= 1'b1;
				ext_busy <= 1'b0;
			end
		end
	end
end

wire [15:0] copro_audio;
assign arm_audio = 16'd0;

arm_copro arm (
	.clk      (clk_sys),
	.reset    (reset || ~souper_en),
	.reg_a    (address_in[2:0]),
	.reg_din  (din),
	.reg_wr   (arm_wr),
	.reg_rd   (arm_rd),
	.reg_dout (arm_dout),
	.aud_com  (aud_com),
	.aud_req  (aud_req_edge),
	.auto_start (souper_en),
	.ext_addr (ext_addr),
	.ext_req  (ext_req),
	.ext_data (ext_data),
	.ext_ack  (ext_ack),
	.audio    (copro_audio),
	.busy     (arm_busy)
);

endmodule: cart

