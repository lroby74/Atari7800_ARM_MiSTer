// (c) 2013 mark watson - non-commercial use.
// If used commercially or otherwise sold, contact scrameta (gmail) for
// explicit permission. Applies to source and binary form and derived works.
// Converted from pokey_keyboard_scanner.vhdl to SystemVerilog-2005.
module pokey_keyboard_scanner
(
	input             clk,
	input             reset_n,

	input             enable,
	input       [1:0] keyboard_response,
	input             debounce_disable,
	input             scan_enable,

	output      [5:0] keyboard_scan,

	output            key_held,
	output            shift_held,
	output      [7:0] keycode,
	output            other_key_irq,
	output            break_irq
);

localparam [1:0] STATE_WAIT_KEY     = 2'b00;
localparam [1:0] STATE_KEY_BOUNCE   = 2'b01;
localparam [1:0] STATE_VALID_KEY    = 2'b10;
localparam [1:0] STATE_KEY_DEBOUNCE = 2'b11;

reg  [5:0] bincnt_next, bincnt_reg;
reg        break_pressed_next, break_pressed_reg;
reg        shift_pressed_next, shift_pressed_reg;
reg        control_pressed_next, control_pressed_reg;
reg  [5:0] compare_latch_next, compare_latch_reg;
reg  [7:0] keycode_latch_next, keycode_latch_reg;
reg        irq_next, irq_reg;
reg        break_irq_next, break_irq_reg;
reg        key_held_next, key_held_reg;
reg        my_key;
reg  [1:0] state_next, state_reg;

always @(posedge clk or negedge reset_n) begin
	if(!reset_n) begin
		bincnt_reg          <= 6'b000000;
		break_pressed_reg   <= 1'b0;
		shift_pressed_reg   <= 1'b0;
		control_pressed_reg <= 1'b0;
		compare_latch_reg   <= 6'b000000;
		keycode_latch_reg   <= 8'b11111111;
		key_held_reg        <= 1'b0;
		state_reg           <= STATE_WAIT_KEY;
		irq_reg             <= 1'b0;
		break_irq_reg       <= 1'b0;
	end
	else begin
		bincnt_reg          <= bincnt_next;
		state_reg           <= state_next;
		break_pressed_reg   <= break_pressed_next;
		shift_pressed_reg   <= shift_pressed_next;
		control_pressed_reg <= control_pressed_next;
		compare_latch_reg   <= compare_latch_next;
		keycode_latch_reg   <= keycode_latch_next;
		key_held_reg        <= key_held_next;
		state_reg           <= state_next;
		irq_reg             <= irq_next;
		break_irq_reg       <= break_irq_next;
	end
end

always @* begin
	bincnt_next          = bincnt_reg;
	state_next           = state_reg;
	compare_latch_next   = compare_latch_reg;
	irq_next             = 1'b0;
	break_irq_next       = 1'b0;
	break_pressed_next   = break_pressed_reg;
	shift_pressed_next   = shift_pressed_reg;
	control_pressed_next = control_pressed_reg;
	keycode_latch_next   = keycode_latch_reg;
	key_held_next        = key_held_reg;

	my_key = 1'b0;
	if(bincnt_reg == compare_latch_reg || debounce_disable) my_key = 1'b1;

	if(enable && scan_enable) begin
		bincnt_next   = bincnt_reg + 1'd1;
		key_held_next = 1'b0;

		case(state_reg)
		STATE_WAIT_KEY:
			if(!keyboard_response[0]) begin
				if(debounce_disable) begin
					keycode_latch_next = {control_pressed_reg,shift_pressed_reg,bincnt_reg};
					irq_next           = 1'b1;
					key_held_next      = 1'b1;
				end
				else begin
					state_next         = STATE_KEY_BOUNCE;
					compare_latch_next = bincnt_reg;
				end
			end

		STATE_KEY_BOUNCE:
			if(!keyboard_response[0]) begin
				if(my_key) begin
					keycode_latch_next = {control_pressed_reg,shift_pressed_reg,compare_latch_reg};
					irq_next           = 1'b1;
					key_held_next      = 1'b1;
					state_next         = STATE_VALID_KEY;
				end
				else state_next = STATE_WAIT_KEY;
			end
			else begin
				if(my_key) state_next = STATE_WAIT_KEY;
			end

		STATE_VALID_KEY: begin
			key_held_next = 1'b1;
			if(my_key) begin
				if(keyboard_response[0]) state_next = STATE_KEY_DEBOUNCE;
			end
		end

		STATE_KEY_DEBOUNCE: begin
			key_held_next = 1'b1;
			if(my_key) begin
				if(keyboard_response[0]) begin
					key_held_next = 1'b0;
					state_next    = STATE_WAIT_KEY;
				end
				else state_next = STATE_VALID_KEY;
			end
		end

		default: state_next = STATE_WAIT_KEY;
		endcase

		if(bincnt_reg[3:0] == 4'b0000) begin
			case(bincnt_reg[5:4])
			2'b11: break_pressed_next   = ~keyboard_response[1];
			2'b01: shift_pressed_next   = ~keyboard_response[1];
			2'b00: control_pressed_next = ~keyboard_response[1];
			default: ;
			endcase
		end
	end

	if(break_pressed_next && !break_pressed_reg) break_irq_next = 1'b1;
end

assign keyboard_scan = ~bincnt_reg;
assign key_held      = key_held_reg;
assign shift_held    = shift_pressed_reg;
assign keycode       = keycode_latch_reg;
assign other_key_irq = irq_reg;
assign break_irq     = break_irq_reg;

endmodule

