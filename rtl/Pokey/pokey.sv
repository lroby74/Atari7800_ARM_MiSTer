// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from pokey.vhdl to SystemVerilog-2005.
module pokey
#(
	parameter CUSTOM_KEYBOARD_SCAN = 0
)
(
	input             CLK,
	input             ENABLE_179,
	input       [3:0] ADDR,
	input       [7:0] DATA_IN,
	input             WR_EN,

	input             RESET_N,

	input             keyboard_scan_enable,
	output      [5:0] keyboard_scan,
	input       [1:0] keyboard_response,

	input       [7:0] POT_IN,

	input             SIO_IN1,
	input             SIO_IN2,
	input             SIO_IN3,

	output reg  [7:0] DATA_OUT,

	output      [3:0] CHANNEL_0_OUT,
	output      [3:0] CHANNEL_1_OUT,
	output      [3:0] CHANNEL_2_OUT,
	output      [3:0] CHANNEL_3_OUT,

	output            IRQ_N_OUT,

	output            SIO_OUT1,
	output            SIO_OUT2,
	output            SIO_OUT3,

	input             SIO_CLOCKIN_IN,
	output            SIO_CLOCKIN_OUT,
	output            SIO_CLOCKIN_OE,
	output            SIO_CLOCKOUT,

	output            POT_RESET
);

wire       enable_64;
wire       enable_15;

reg  [7:0] audf0_reg;
reg  [7:0] audc0_reg;
reg  [7:0] audf1_reg;
reg  [7:0] audc1_reg;
reg  [7:0] audf2_reg;
reg  [7:0] audc2_reg;
reg  [7:0] audf3_reg;
reg  [7:0] audc3_reg;
reg  [7:0] audctl_reg;
reg  [7:0] audf0_next;
reg  [7:0] audc0_next;
reg  [7:0] audf1_next;
reg  [7:0] audc1_next;
reg  [7:0] audf2_next;
reg  [7:0] audc2_next;
reg  [7:0] audf3_next;
reg  [7:0] audc3_next;
reg  [7:0] audctl_next;

wire       audf0_pulse;
wire       audf1_pulse;
wire       audf2_pulse;
wire       audf3_pulse;

reg        audf0_reload;
reg        audf1_reload;
reg        audf2_reload;
reg        audf3_reload;

reg        stimer_write;
wire       stimer_write_delayed;

wire       audf0_pulse_noise;
wire       audf1_pulse_noise;
wire       audf2_pulse_noise;
wire       audf3_pulse_noise;

reg        audf0_enable;
reg        audf1_enable;
reg        audf2_enable;
reg        audf3_enable;

wire       chan0_output_next;
wire       chan1_output_next;
wire       chan2_output_next;
wire       chan3_output_next;
reg        chan0_output_reg;
reg        chan1_output_reg;
reg        chan2_output_reg;
reg        chan3_output_reg;

reg        chan0_output_del_next;
reg        chan1_output_del_next;
reg        chan0_output_del_reg;
reg        chan1_output_del_reg;

reg        highpass0_next;
reg        highpass1_next;
reg        highpass0_reg;
reg        highpass1_reg;

reg  [3:0] volume_channel_0_next;
reg  [3:0] volume_channel_1_next;
reg  [3:0] volume_channel_2_next;
reg  [3:0] volume_channel_3_next;
reg  [3:0] volume_channel_0_reg;
reg  [3:0] volume_channel_1_reg;
reg  [3:0] volume_channel_2_reg;
reg  [3:0] volume_channel_3_reg;

wire [15:0] addr_decoded;

wire       noise_4;
wire       noise_5;
wire       noise_large;
reg  [2:0] noise_4_next;
reg  [2:0] noise_4_reg;
reg  [2:0] noise_5_next;
reg  [2:0] noise_5_reg;
reg  [2:0] noise_large_next;
reg  [2:0] noise_large_reg;

wire [7:0] rand_out;

wire       initmode;

reg  [7:0] irqen_next;
reg  [7:0] irqen_reg;

reg  [7:0] irqst_next;
reg  [7:0] irqst_reg;

reg        irq_n_next;
reg        irq_n_reg;

reg        serial_ip_ready_interrupt;
reg        serial_ip_framing_next;
reg        serial_ip_framing_reg;
reg        serial_ip_overrun_next;
reg        serial_ip_overrun_reg;
reg        serial_op_needed_interrupt;

reg  [7:0] skctl_next;
reg  [7:0] skctl_reg;

reg  [9:0] serin_shift_next;
reg  [9:0] serin_shift_reg;
reg  [7:0] serin_next;
reg  [7:0] serin_reg;
reg  [3:0] serin_bitcount_next;
reg  [3:0] serin_bitcount_reg;

wire       sio_in1_reg;
wire       sio_in2_reg;
wire       sio_in3_reg;
wire       sio_in_next;
reg        sio_in_reg;

reg        sio_out_next;
reg        sio_out_reg;
reg        serial_out_next;
reg        serial_out_reg;

reg  [9:0] serout_shift_next;
reg  [9:0] serout_shift_reg;

reg        serout_holding_full_next;
reg        serout_holding_full_reg;
reg  [7:0] serout_holding_next;
reg  [7:0] serout_holding_reg;
reg        serout_holding_load;

reg  [3:0] serout_bitcount_next;
reg  [3:0] serout_bitcount_reg;

reg        serout_active_next;
reg        serout_active_reg;

reg        serial_reset;
wire       serout_sync_reset;
reg        skrest_write;

reg        serout_enable;
wire       serout_enable_delayed;
reg        serin_enable;

reg        async_serial_reset;
wire       waiting_for_start_bit;

reg        serin_clock_next;
reg        serin_clock_reg;
reg        serin_clock_last_next;
reg        serin_clock_last_reg;

reg        serout_clock_next;
reg        serout_clock_reg;
reg        serout_clock_last_next;
reg        serout_clock_last_reg;

reg        twotone_reset;
wire       twotone_reset_delayed;
reg        twotone_next;
reg        twotone_reg;

reg        clock_next;
reg        clock_reg;
reg        clock_sync_next;
reg        clock_sync_reg;
reg        clock_input;

reg        keyboard_overrun_next;
reg        keyboard_overrun_reg;

wire       shift_held;
wire       break_irq;
wire       key_held;
wire       other_key_irq;

wire [7:0] kbcode;

reg  [7:0] pot0_next;
reg  [7:0] pot0_reg;
reg  [7:0] pot1_next;
reg  [7:0] pot1_reg;
reg  [7:0] pot2_next;
reg  [7:0] pot2_reg;
reg  [7:0] pot3_next;
reg  [7:0] pot3_reg;
reg  [7:0] pot4_next;
reg  [7:0] pot4_reg;
reg  [7:0] pot5_next;
reg  [7:0] pot5_reg;
reg  [7:0] pot6_next;
reg  [7:0] pot6_reg;
reg  [7:0] pot7_next;
reg  [7:0] pot7_reg;

reg  [7:0] allpot_next;
reg  [7:0] allpot_reg;

reg  [7:0] pot_counter_next;
reg  [7:0] pot_counter_reg;

reg        potgo_write;

reg        pot_reset_next;
reg        pot_reset_reg;

always @(posedge CLK or negedge RESET_N) begin
	if (!RESET_N) begin

		audf0_reg <= 8'h00;
		audc0_reg <= 8'h00;
		audf1_reg <= 8'h00;
		audc1_reg <= 8'h00;
		audf2_reg <= 8'h00;
		audc2_reg <= 8'h00;
		audf3_reg <= 8'h00;
		audc3_reg <= 8'h00;
		audctl_reg <= 8'h00;

		irqen_reg <= 8'h00;
		irqst_reg <= 8'hFF;
		irq_n_reg <= 1'b1;

		skctl_reg <= 8'h00;

		highpass0_reg <= 1'b0;
		highpass1_reg <= 1'b0;

		chan0_output_reg <= 1'b0;
		chan1_output_reg <= 1'b0;
		chan2_output_reg <= 1'b0;
		chan3_output_reg <= 1'b0;

		chan0_output_del_reg <= 1'b0;
		chan1_output_del_reg <= 1'b0;

		volume_channel_0_reg <= 4'b0000;
		volume_channel_1_reg <= 4'b0000;
		volume_channel_2_reg <= 4'b0000;
		volume_channel_3_reg <= 4'b0000;

		serin_reg <= 8'h00;
		serin_shift_reg <= 10'b0;
		serin_bitcount_reg <= 4'b0000;
		serout_shift_reg <= 10'b0;
		serout_holding_reg <= 8'h00;
		serout_holding_full_reg <= 1'b0;
		serout_active_reg <= 1'b0;
		sio_out_reg <= 1'b1;
		serial_out_reg <= 1'b1;

		serial_ip_framing_reg <= 1'b0;
		serial_ip_overrun_reg <= 1'b0;

		clock_reg <= 1'b0;
		clock_sync_reg <= 1'b0;

		keyboard_overrun_reg <= 1'b0;

		serin_clock_reg <= 1'b0;
		serin_clock_last_reg <= 1'b0;
		serout_clock_reg <= 1'b0;
		serout_clock_last_reg <= 1'b0;

		twotone_reg <= 1'b0;

		sio_in_reg <= 1'b0;

		pot0_reg <= 8'h00;
		pot1_reg <= 8'h00;
		pot2_reg <= 8'h00;
		pot3_reg <= 8'h00;
		pot4_reg <= 8'h00;
		pot5_reg <= 8'h00;
		pot6_reg <= 8'h00;
		pot7_reg <= 8'h00;

		allpot_reg <= 8'hFF;

		pot_counter_reg <= 8'h00;

		pot_reset_reg <= 1'b1;

		noise_4_reg <= 3'b000;
		noise_5_reg <= 3'b000;
		noise_large_reg <= 3'b000;
	end
	else begin
		audf0_reg <= audf0_next;
		audc0_reg <= audc0_next;
		audf1_reg <= audf1_next;
		audc1_reg <= audc1_next;
		audf2_reg <= audf2_next;
		audc2_reg <= audc2_next;
		audf3_reg <= audf3_next;
		audc3_reg <= audc3_next;
		audctl_reg <= audctl_next;

		irqen_reg <= irqen_next;
		irqst_reg <= irqst_next;
		irq_n_reg <= irq_n_next;

		skctl_reg <= skctl_next;

		highpass0_reg <= highpass0_next;
		highpass1_reg <= highpass1_next;

		chan0_output_reg <= chan0_output_next;
		chan1_output_reg <= chan1_output_next;
		chan2_output_reg <= chan2_output_next;
		chan3_output_reg <= chan3_output_next;

		chan0_output_del_reg <= chan0_output_del_next;
		chan1_output_del_reg <= chan1_output_del_next;

		volume_channel_0_reg <= volume_channel_0_next;
		volume_channel_1_reg <= volume_channel_1_next;
		volume_channel_2_reg <= volume_channel_2_next;
		volume_channel_3_reg <= volume_channel_3_next;

		serin_reg <= serin_next;
		serin_shift_reg <= serin_shift_next;
		serin_bitcount_reg <= serin_bitcount_next;
		serout_shift_reg <= serout_shift_next;
		serout_bitcount_reg <= serout_bitcount_next;

		serout_holding_reg <= serout_holding_next;
		serout_holding_full_reg <= serout_holding_full_next;
		serout_active_reg <= serout_active_next;

		sio_out_reg <= sio_out_next;
		serial_out_reg <= serial_out_next;

		serial_ip_framing_reg <= serial_ip_framing_next;
		serial_ip_overrun_reg <= serial_ip_overrun_next;

		clock_reg <= clock_next;
		clock_sync_reg <= clock_sync_next;

		keyboard_overrun_reg <= keyboard_overrun_next;

		serin_clock_reg <= serin_clock_next;
		serin_clock_last_reg <= serin_clock_last_next;
		serout_clock_reg <= serout_clock_next;
		serout_clock_last_reg <= serout_clock_last_next;

		twotone_reg <= twotone_next;

		sio_in_reg <= sio_in_next;

		pot0_reg <= pot0_next;
		pot1_reg <= pot1_next;
		pot2_reg <= pot2_next;
		pot3_reg <= pot3_next;
		pot4_reg <= pot4_next;
		pot5_reg <= pot5_next;
		pot6_reg <= pot6_next;
		pot7_reg <= pot7_next;

		allpot_reg <= allpot_next;

		pot_counter_reg <= pot_counter_next;

		pot_reset_reg <= pot_reset_next;

		noise_4_reg <= noise_4_next;
		noise_5_reg <= noise_5_next;
		noise_large_reg <= noise_large_next;
	end
end

complete_address_decoder #(.width(4)) decode_addr1
(
	.addr_in(ADDR),
	.addr_decoded(addr_decoded)
);

always @* begin
	audf0_enable = enable_64;
	audf1_enable = enable_64;
	audf2_enable = enable_64;
	audf3_enable = enable_64;

	if (audctl_reg[0]) begin
		audf0_enable = enable_15;
		audf1_enable = enable_15;
		audf2_enable = enable_15;
		audf3_enable = enable_15;
	end

	if (audctl_reg[6]) audf0_enable = ENABLE_179;

	if (audctl_reg[5]) audf2_enable = ENABLE_179;

	if (audctl_reg[4]) audf1_enable = audf0_pulse;

	if (audctl_reg[3]) audf3_enable = audf2_pulse;
end

pokey_countdown_timer #(.UNDERFLOW_DELAY(3)) timer0
(
	.CLK(CLK), .ENABLE(audf0_enable), .ENABLE_UNDERFLOW(ENABLE_179), .RESET_N(RESET_N),
	.WR_EN(audf0_reload), .DATA_IN(audf0_next), .DATA_OUT(audf0_pulse)
);
pokey_countdown_timer #(.UNDERFLOW_DELAY(3)) timer1
(
	.CLK(CLK), .ENABLE(audf1_enable), .ENABLE_UNDERFLOW(ENABLE_179), .RESET_N(RESET_N),
	.WR_EN(audf1_reload), .DATA_IN(audf1_next), .DATA_OUT(audf1_pulse)
);
pokey_countdown_timer #(.UNDERFLOW_DELAY(3)) timer2
(
	.CLK(CLK), .ENABLE(audf2_enable), .ENABLE_UNDERFLOW(ENABLE_179), .RESET_N(RESET_N),
	.WR_EN(audf2_reload), .DATA_IN(audf2_next), .DATA_OUT(audf2_pulse)
);
pokey_countdown_timer #(.UNDERFLOW_DELAY(3)) timer3
(
	.CLK(CLK), .ENABLE(audf3_enable), .ENABLE_UNDERFLOW(ENABLE_179), .RESET_N(RESET_N),
	.WR_EN(audf3_reload), .DATA_IN(audf3_next), .DATA_OUT(audf3_pulse)
);

always @* begin
	audf0_reload = ((~audctl_reg[4] & audf0_pulse)) | (audctl_reg[4] & audf1_pulse) | stimer_write_delayed | twotone_reset_delayed;
	audf1_reload = audf1_pulse | stimer_write_delayed | twotone_reset_delayed;
	audf2_reload = ((~audctl_reg[3] & audf2_pulse)) | (audctl_reg[3] & audf3_pulse) | stimer_write_delayed | async_serial_reset;
	audf3_reload = audf3_pulse | stimer_write_delayed | async_serial_reset;
end

latch_delay_line #(.COUNT(2)) twotone_del
(
	.CLK(CLK), .SYNC_RESET(1'b0), .DATA_IN(twotone_reset), .ENABLE(ENABLE_179), .RESET_N(RESET_N), .DATA_OUT(twotone_reset_delayed)
);

always @* begin
	audf0_next = audf0_reg;
	audc0_next = audc0_reg;
	audf1_next = audf1_reg;
	audc1_next = audc1_reg;
	audf2_next = audf2_reg;
	audc2_next = audc2_reg;
	audf3_next = audf3_reg;
	audc3_next = audc3_reg;
	audctl_next = audctl_reg;

	irqen_next = irqen_reg;
	skctl_next = skctl_reg;

	stimer_write = 1'b0;

	serout_holding_load = 1'b0;
	serout_holding_next = serout_holding_reg;

	serial_reset = 1'b0;
	skrest_write = 1'b0;
	potgo_write = 1'b0;

	if (WR_EN) begin
		if (addr_decoded[0]) audf0_next = DATA_IN;

		if (addr_decoded[1]) audc0_next = DATA_IN;

		if (addr_decoded[2]) audf1_next = DATA_IN;

		if (addr_decoded[3]) audc1_next = DATA_IN;

		if (addr_decoded[4]) audf2_next = DATA_IN;

		if (addr_decoded[5]) audc2_next = DATA_IN;

		if (addr_decoded[6]) audf3_next = DATA_IN;

		if (addr_decoded[7]) audc3_next = DATA_IN;

		if (addr_decoded[8]) audctl_next = DATA_IN;

		if (addr_decoded[9]) stimer_write = 1'b1;

		if (addr_decoded[10]) skrest_write = 1'b1;

		if (addr_decoded[11]) potgo_write = 1'b1;

		if (addr_decoded[13]) begin
			serout_holding_next = DATA_IN;
			serout_holding_load = 1'b1;
		end

		if (addr_decoded[14]) irqen_next = DATA_IN;

		if (addr_decoded[15]) begin
			skctl_next = DATA_IN;

			if (DATA_IN[6:4] == 3'b000) serial_reset = 1'b1;
		end
	end
end

always @* begin
	DATA_OUT = 8'hFF;

	if (addr_decoded[0]) DATA_OUT = pot0_reg;

	if (addr_decoded[1]) DATA_OUT = pot1_reg;

	if (addr_decoded[2]) DATA_OUT = pot2_reg;

	if (addr_decoded[3]) DATA_OUT = pot3_reg;

	if (addr_decoded[4]) DATA_OUT = pot4_reg;

	if (addr_decoded[5]) DATA_OUT = pot5_reg;

	if (addr_decoded[6]) DATA_OUT = pot6_reg;

	if (addr_decoded[7]) DATA_OUT = pot7_reg;

	if (addr_decoded[8]) DATA_OUT = allpot_reg;

	if (addr_decoded[9]) DATA_OUT = kbcode;

	if (addr_decoded[10]) DATA_OUT = rand_out;

	if (addr_decoded[13]) DATA_OUT = serin_reg;

	if (addr_decoded[14]) DATA_OUT = irqst_reg;

	if (addr_decoded[15])
		DATA_OUT = {~serial_ip_framing_reg, ~keyboard_overrun_reg, ~serial_ip_overrun_reg, sio_in_reg, ~shift_held, ~key_held, waiting_for_start_bit, 1'b1};
end

always @* begin

	irqst_next = irqst_reg | ~irqen_reg;

	irq_n_next = 1'b0;

	if ((irqst_reg | {4'b0000, ~irqen_reg[3], 3'b000}) == 8'hFF) irq_n_next = 1'b1;

	if (audf0_pulse) irqst_next[0] = ~irqen_reg[0];

	if (audf1_pulse) irqst_next[1] = ~irqen_reg[1];

	if (audf3_pulse) irqst_next[2] = ~irqen_reg[2];

	if (other_key_irq) irqst_next[6] = ~irqen_reg[6];

	if (break_irq) irqst_next[7] = ~irqen_reg[7];

	if (serial_ip_ready_interrupt) irqst_next[5] = ~irqen_reg[5];

	irqst_next[3] = serout_active_reg;

	if (serial_op_needed_interrupt) irqst_next[4] = ~irqen_reg[4];
end

latch_delay_line #(.COUNT(3)) stimer_delay
(
	.CLK(CLK), .SYNC_RESET(1'b0), .DATA_IN(stimer_write), .ENABLE(ENABLE_179), .RESET_N(RESET_N), .DATA_OUT(stimer_write_delayed)
);

pokey_noise_filter pokey_noise_filter0
(
	.CLK(CLK), .RESET_N(RESET_N), .NOISE_SELECT(audc0_reg[7:5]), .PULSE_IN(audf0_pulse), .PULSE_OUT(audf0_pulse_noise),
	.NOISE_4(noise_4), .NOISE_5(noise_5), .NOISE_LARGE(noise_large), .SYNC_RESET(stimer_write_delayed)
);
pokey_noise_filter pokey_noise_filter1
(
	.CLK(CLK), .RESET_N(RESET_N), .NOISE_SELECT(audc1_reg[7:5]), .PULSE_IN(audf1_pulse), .PULSE_OUT(audf1_pulse_noise),
	.NOISE_4(noise_4_reg[0]), .NOISE_5(noise_5_reg[0]), .NOISE_LARGE(noise_large_reg[0]), .SYNC_RESET(stimer_write_delayed)
);
pokey_noise_filter pokey_noise_filter2
(
	.CLK(CLK), .RESET_N(RESET_N), .NOISE_SELECT(audc2_reg[7:5]), .PULSE_IN(audf2_pulse), .PULSE_OUT(audf2_pulse_noise),
	.NOISE_4(noise_4_reg[1]), .NOISE_5(noise_5_reg[1]), .NOISE_LARGE(noise_large_reg[1]), .SYNC_RESET(stimer_write_delayed)
);
pokey_noise_filter pokey_noise_filter3
(
	.CLK(CLK), .RESET_N(RESET_N), .NOISE_SELECT(audc3_reg[7:5]), .PULSE_IN(audf3_pulse), .PULSE_OUT(audf3_pulse_noise),
	.NOISE_4(noise_4_reg[2]), .NOISE_5(noise_5_reg[2]), .NOISE_LARGE(noise_large_reg[2]), .SYNC_RESET(stimer_write_delayed)
);

assign chan0_output_next = audf0_pulse_noise;
assign chan1_output_next = audf1_pulse_noise;
assign chan2_output_next = audf2_pulse_noise;
assign chan3_output_next = audf3_pulse_noise;

always @* begin
	highpass0_next = highpass0_reg;
	highpass1_next = highpass1_reg;

	if (audctl_reg[2]) begin
		if (audf2_pulse) highpass0_next = chan0_output_reg;
	end
	else highpass0_next = 1'b1;

	if (audctl_reg[1]) begin
		if (audf3_pulse) highpass1_next = chan1_output_reg;
	end
	else highpass1_next = 1'b1;
end

always @* begin
	chan0_output_del_next = chan0_output_del_reg;
	chan1_output_del_next = chan1_output_del_reg;

	if (ENABLE_179) begin
		chan0_output_del_next = chan0_output_reg;
		chan1_output_del_next = chan1_output_reg;
	end
end

syncreset_enable_divider #(.COUNT(28), .RESETCOUNT(6)) enable_64_div
(
	.CLK(CLK), .SYNCRESET(initmode), .RESET_N(RESET_N), .ENABLE_IN(ENABLE_179), .ENABLE_OUT(enable_64)
);

syncreset_enable_divider #(.COUNT(114), .RESETCOUNT(33)) enable_15_div
(
	.CLK(CLK), .SYNCRESET(initmode), .RESET_N(RESET_N), .ENABLE_IN(ENABLE_179), .ENABLE_OUT(enable_15)
);

assign initmode = ~(skctl_next[1] | skctl_next[0]);

pokey_poly_17_9 poly_17_19_lfsr
(
	.CLK(CLK),
	.RESET_N(RESET_N),
	.INIT(initmode),
	.ENABLE(ENABLE_179),
	.SELECT_9_17(audctl_reg[7]),
	.BIT_OUT(noise_large),
	.RAND_OUT(rand_out)
);

pokey_poly_5 poly_5_lfsr
(
	.CLK(CLK), .RESET_N(RESET_N), .INIT(initmode), .ENABLE(ENABLE_179), .BIT_OUT(noise_5)
);

pokey_poly_4 poly_4_lfsr
(
	.CLK(CLK), .RESET_N(RESET_N), .INIT(initmode), .ENABLE(ENABLE_179), .BIT_OUT(noise_4)
);

always @* begin
	noise_large_next = noise_large_reg;
	noise_5_next = noise_5_reg;
	noise_4_next = noise_4_reg;

	if (ENABLE_179) begin
		noise_large_next = {noise_large_reg[1:0], noise_large};
		noise_5_next = {noise_5_reg[1:0], noise_5};
		noise_4_next = {noise_4_reg[1:0], noise_4};
	end
end

always @* begin
	volume_channel_0_next = 4'b0000;
	volume_channel_1_next = 4'b0000;
	volume_channel_2_next = 4'b0000;
	volume_channel_3_next = 4'b0000;

	if (((chan0_output_del_reg ^ highpass0_reg) | audc0_reg[4])) volume_channel_0_next = audc0_reg[3:0];

	if (((chan1_output_del_reg ^ highpass1_reg) | audc1_reg[4])) volume_channel_1_next = audc1_reg[3:0];

	if ((chan2_output_reg | audc2_reg[4])) volume_channel_2_next = audc2_reg[3:0];

	if ((chan3_output_reg | audc3_reg[4])) volume_channel_3_next = audc3_reg[3:0];
end

assign serout_sync_reset = serial_reset | stimer_write_delayed;

delay_line #(.COUNT(2)) serout_clock_delay
(
	.CLK(CLK), .SYNC_RESET(serout_sync_reset), .DATA_IN(serout_enable), .ENABLE(ENABLE_179), .RESET_N(RESET_N), .DATA_OUT(serout_enable_delayed)
);

always @* begin
	serout_clock_next = serout_clock_reg;
	serout_clock_last_next = serout_clock_reg;

	serout_shift_next = serout_shift_reg;
	serout_bitcount_next = serout_bitcount_reg;
	serout_holding_full_next = serout_holding_full_reg;
	serout_active_next = serout_active_reg;

	serial_out_next = serial_out_reg;
	sio_out_next = serial_out_reg;

	twotone_next = twotone_reg;
	twotone_reset = 1'b0;

	if ((audf1_pulse | (audf0_pulse & serial_out_reg))) begin
		twotone_next = ~twotone_reg;
		twotone_reset = skctl_reg[3];
	end

	if (skctl_reg[3]) sio_out_next = twotone_reg;

	serial_op_needed_interrupt = 1'b0;

	if (serout_enable_delayed) serout_clock_next = ~serout_clock_reg;

	if (serout_clock_last_reg == 1'b0 && serout_clock_reg == 1'b1) begin
		serout_shift_next = {1'b0, serout_shift_reg[9:1]};
		serial_out_next = serout_shift_reg[1] | ~serout_active_reg;

		if (serout_bitcount_reg == 4'h0) begin
			if (serout_holding_full_reg) begin
				serout_bitcount_next = 4'h9;
				serout_shift_next = {1'b1, serout_holding_reg, 1'b0};
				serial_out_next = 1'b0;
				serout_holding_full_next = 1'b0;
				serial_op_needed_interrupt = 1'b1;
				serout_active_next = 1'b1;
			end
			else begin
				serout_active_next = 1'b0;
				serial_out_next = 1'b1;
			end
		end
		else serout_bitcount_next = serout_bitcount_reg - 1'b1;
	end

	if (skctl_reg[7]) serial_out_next = 1'b0;

	if (serout_holding_load) serout_holding_full_next = 1'b1;

	if (serial_reset) begin
		twotone_next = 1'b0;
		serout_bitcount_next = 4'b0000;
		serout_shift_next = 10'b0;
		serout_holding_full_next = 1'b0;
		serout_clock_next = 1'b0;
		serout_clock_last_next = 1'b0;
		serout_active_next = 1'b0;
	end
end

synchronizer sio_in1_synchronizer (.CLK(CLK), .RAW(SIO_IN1), .SYNC(sio_in1_reg));
synchronizer sio_in2_synchronizer (.CLK(CLK), .RAW(SIO_IN2), .SYNC(sio_in2_reg));
synchronizer sio_in3_synchronizer (.CLK(CLK), .RAW(SIO_IN3), .SYNC(sio_in3_reg));
assign sio_in_next = sio_in1_reg & sio_in2_reg & sio_in3_reg;

assign waiting_for_start_bit = (serin_bitcount_reg == 4'h9) ? 1'b1 : 1'b0;

always @* begin
	serin_clock_next = serin_clock_reg;
	serin_clock_last_next = serin_clock_reg;

	serin_shift_next = serin_shift_reg;
	serin_bitcount_next = serin_bitcount_reg;
	serin_next = serin_reg;

	serial_ip_overrun_next = serial_ip_overrun_reg;
	serial_ip_framing_next = serial_ip_framing_reg;
	serial_ip_ready_interrupt = 1'b0;

	async_serial_reset = 1'b0;

	if (serin_enable) serin_clock_next = ~serin_clock_reg;

	if ((skctl_reg[4] & sio_in_reg & waiting_for_start_bit)) begin
		async_serial_reset = 1'b1;
		serin_clock_next = 1'b1;
	end

	if (serin_clock_last_reg == 1'b1 && serin_clock_reg == 1'b0) begin
		if (((waiting_for_start_bit & ~sio_in_reg) | ~waiting_for_start_bit)) begin
			serin_shift_next = {sio_in_reg, serin_shift_reg[9:1]};

			if (serin_bitcount_reg == 4'h0) begin
				serin_next = serin_shift_reg[9:2];

				serin_bitcount_next = 4'h9;

				serial_ip_ready_interrupt = 1'b1;

				if (irqst_reg[5] == 1'b0) serial_ip_overrun_next = 1'b1;

				if (sio_in_reg == 1'b0) serial_ip_framing_next = 1'b1;
			end
			else serin_bitcount_next = serin_bitcount_reg - 1'b1;
		end
	end

	if (skrest_write) begin
		serial_ip_overrun_next = 1'b0;
		serial_ip_framing_next = 1'b0;
	end

	if (serial_reset) begin
		serin_clock_next = 1'b0;
		serin_bitcount_next = 4'h9;
		serin_shift_next = 10'b0;
	end
end

always @* begin
	clock_next = SIO_CLOCKIN_IN;
	clock_sync_next = clock_reg;

	serout_enable = 1'b0;
	serin_enable = 1'b0;
	clock_input = 1'b1;

	case (skctl_reg[6:4])
		3'b000: begin
			serin_enable = ~clock_sync_reg & clock_reg;
			serout_enable = ~clock_sync_reg & clock_reg;
		end
		3'b001: begin
			serin_enable = audf3_pulse;
			serout_enable = ~clock_sync_reg & clock_reg;
		end
		3'b010: begin
			serin_enable = audf3_pulse;
			serout_enable = audf3_pulse;
			clock_input = 1'b0;
		end
		3'b011: begin
			serin_enable = audf3_pulse;
			serout_enable = audf3_pulse;
		end
		3'b100: begin
			serin_enable = ~clock_sync_reg & clock_reg;
			serout_enable = audf3_pulse;
		end
		3'b101: begin
			serin_enable = audf3_pulse;
			serout_enable = audf3_pulse;
		end
		3'b110: begin
			serin_enable = audf3_pulse;
			serout_enable = audf1_pulse;
			clock_input = 1'b0;
		end
		3'b111: begin
			serin_enable = audf3_pulse;
			serout_enable = audf1_pulse;
		end
		default: ;
	endcase
end

always @* begin
	keyboard_overrun_next = keyboard_overrun_reg;

	if (other_key_irq == 1'b1 && irqst_reg[6] == 1'b0) keyboard_overrun_next = 1'b1;

	if (skrest_write) keyboard_overrun_next = 1'b0;
end

generate
if (CUSTOM_KEYBOARD_SCAN == 1) begin : gen_custom_scan
	pokey_keyboard_scanner pokey_keyboard_scanner1
	(
		.clk(CLK), .reset_n(RESET_N), .enable(keyboard_scan_enable), .keyboard_response(keyboard_response), .debounce_disable(~skctl_reg[0]), .scan_enable(skctl_reg[1]),
		.keyboard_scan(keyboard_scan), .key_held(key_held), .shift_held(shift_held), .keycode(kbcode), .other_key_irq(other_key_irq), .break_irq(break_irq)
	);
end
endgenerate

generate
if (CUSTOM_KEYBOARD_SCAN == 0) begin : gen_normal_scan
	pokey_keyboard_scanner pokey_keyboard_scanner1
	(
		.clk(CLK), .reset_n(RESET_N), .enable(enable_15), .keyboard_response(keyboard_response), .debounce_disable(~skctl_reg[0]), .scan_enable(skctl_reg[1]),
		.keyboard_scan(keyboard_scan), .key_held(key_held), .shift_held(shift_held), .keycode(kbcode), .other_key_irq(other_key_irq), .break_irq(break_irq)
	);
end
endgenerate

always @* begin
	pot0_next = pot0_reg;
	pot1_next = pot1_reg;
	pot2_next = pot2_reg;
	pot3_next = pot3_reg;
	pot4_next = pot4_reg;
	pot5_next = pot5_reg;
	pot6_next = pot6_reg;
	pot7_next = pot7_reg;

	allpot_next = allpot_reg;

	pot_reset_next = pot_reset_reg;

	pot_counter_next = pot_counter_reg;

	if (((enable_15 & ~skctl_reg[2]) | (ENABLE_179 & skctl_reg[2]))) begin
		pot_counter_next = pot_counter_reg + 1'b1;
		if (pot_counter_reg == 8'hE4) begin
			pot_reset_next = 1'b1;
			allpot_next = 8'h00;
		end

		if (pot_reset_reg == 1'b0) begin
			if (POT_IN[0] == 1'b0) pot0_next = pot_counter_reg;
			if (POT_IN[1] == 1'b0) pot1_next = pot_counter_reg;
			if (POT_IN[2] == 1'b0) pot2_next = pot_counter_reg;
			if (POT_IN[3] == 1'b0) pot3_next = pot_counter_reg;
			if (POT_IN[4] == 1'b0) pot4_next = pot_counter_reg;
			if (POT_IN[5] == 1'b0) pot5_next = pot_counter_reg;
			if (POT_IN[6] == 1'b0) pot6_next = pot_counter_reg;
			if (POT_IN[7] == 1'b0) pot7_next = pot_counter_reg;

			allpot_next = allpot_reg & ~POT_IN;
		end
	end

	if (potgo_write) begin
		pot_counter_next = 8'h00;
		pot_reset_next = 1'b0;
		allpot_next = 8'hFF;
	end
end

assign IRQ_N_OUT = irq_n_reg;

assign CHANNEL_0_OUT = volume_channel_0_reg;
assign CHANNEL_1_OUT = volume_channel_1_reg;
assign CHANNEL_2_OUT = volume_channel_2_reg;
assign CHANNEL_3_OUT = volume_channel_3_reg;

assign SIO_OUT1 = sio_out_reg;
assign SIO_OUT2 = sio_out_reg;
assign SIO_OUT3 = sio_out_reg;

assign SIO_CLOCKOUT = serout_clock_reg;
assign SIO_CLOCKIN_OE = ~clock_input;
assign SIO_CLOCKIN_OUT = serin_clock_reg;

assign POT_RESET = pot_reset_reg;

endmodule

