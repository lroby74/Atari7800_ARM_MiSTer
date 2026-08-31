`default_nettype none

module bup_adpcm (
	input  wire        clk,
	input  wire        reset,

	input  wire        state_set,
	input  wire [15:0] state_smp_l,
	input  wire  [6:0] state_idx_l,
	input  wire [15:0] state_smp_r,
	input  wire  [6:0] state_idx_r,

	input  wire        byte_valid,
	input  wire  [7:0] byte_in,

	output reg  [15:0] pcm_l,
	output reg  [15:0] pcm_r,
	output reg         pcm_valid,
	output wire        busy
);

	function automatic [15:0] step_of;
		input [6:0] i;
		case (i)
			7'd0: step_of=16'd7;      7'd1: step_of=16'd8;      7'd2: step_of=16'd9;
			7'd3: step_of=16'd10;     7'd4: step_of=16'd11;     7'd5: step_of=16'd12;
			7'd6: step_of=16'd13;     7'd7: step_of=16'd14;     7'd8: step_of=16'd16;
			7'd9: step_of=16'd17;     7'd10: step_of=16'd19;    7'd11: step_of=16'd21;
			7'd12: step_of=16'd23;    7'd13: step_of=16'd25;    7'd14: step_of=16'd28;
			7'd15: step_of=16'd31;    7'd16: step_of=16'd34;    7'd17: step_of=16'd37;
			7'd18: step_of=16'd41;    7'd19: step_of=16'd45;    7'd20: step_of=16'd50;
			7'd21: step_of=16'd55;    7'd22: step_of=16'd60;    7'd23: step_of=16'd66;
			7'd24: step_of=16'd73;    7'd25: step_of=16'd80;    7'd26: step_of=16'd88;
			7'd27: step_of=16'd97;    7'd28: step_of=16'd107;   7'd29: step_of=16'd118;
			7'd30: step_of=16'd130;   7'd31: step_of=16'd143;   7'd32: step_of=16'd157;
			7'd33: step_of=16'd173;   7'd34: step_of=16'd190;   7'd35: step_of=16'd209;
			7'd36: step_of=16'd230;   7'd37: step_of=16'd253;   7'd38: step_of=16'd279;
			7'd39: step_of=16'd307;   7'd40: step_of=16'd337;   7'd41: step_of=16'd371;
			7'd42: step_of=16'd408;   7'd43: step_of=16'd449;   7'd44: step_of=16'd494;
			7'd45: step_of=16'd544;   7'd46: step_of=16'd598;   7'd47: step_of=16'd658;
			7'd48: step_of=16'd724;   7'd49: step_of=16'd796;   7'd50: step_of=16'd876;
			7'd51: step_of=16'd963;   7'd52: step_of=16'd1060;  7'd53: step_of=16'd1166;
			7'd54: step_of=16'd1282;  7'd55: step_of=16'd1411;  7'd56: step_of=16'd1552;
			7'd57: step_of=16'd1707;  7'd58: step_of=16'd1878;  7'd59: step_of=16'd2066;
			7'd60: step_of=16'd2272;  7'd61: step_of=16'd2499;  7'd62: step_of=16'd2749;
			7'd63: step_of=16'd3024;  7'd64: step_of=16'd3327;  7'd65: step_of=16'd3660;
			7'd66: step_of=16'd4026;  7'd67: step_of=16'd4428;  7'd68: step_of=16'd4871;
			7'd69: step_of=16'd5358;  7'd70: step_of=16'd5894;  7'd71: step_of=16'd6484;
			7'd72: step_of=16'd7132;  7'd73: step_of=16'd7845;  7'd74: step_of=16'd8630;
			7'd75: step_of=16'd9493;  7'd76: step_of=16'd10442; 7'd77: step_of=16'd11487;
			7'd78: step_of=16'd12635; 7'd79: step_of=16'd13899; 7'd80: step_of=16'd15289;
			7'd81: step_of=16'd16818; 7'd82: step_of=16'd18500; 7'd83: step_of=16'd20350;
			7'd84: step_of=16'd22385; 7'd85: step_of=16'd24623; 7'd86: step_of=16'd27086;
			7'd87: step_of=16'd29794; default: step_of=16'd32767;
		endcase
	endfunction

	function automatic signed [4:0] idx_of;
		input [2:0] d;
		case (d)
			3'd0, 3'd1, 3'd2, 3'd3: idx_of = -5'sd1;
			3'd4: idx_of =  5'sd2;
			3'd5: idx_of =  5'sd4;
			3'd6: idx_of =  5'sd6;
			default: idx_of = 5'sd8;
		endcase
	endfunction

	reg signed [15:0] smp_l, smp_r;
	reg        [6:0]  idx_l, idx_r;
	reg        [1:0]  st;
	reg        [7:0]  hold;

	assign busy = (st != 2'd0);

	wire       [3:0]  nib   = (st == 2'd1) ? hold[7:4] : hold[3:0];
	wire signed [15:0] cur_s = (st == 2'd1) ? smp_l : smp_r;
	wire        [6:0]  cur_i = (st == 2'd1) ? idx_l : idx_r;
	wire        [15:0] step  = step_of(cur_i);

	wire [17:0] vpdiff = {5'd0, step[15:3]}
	                   + (nib[2] ? {2'd0, step}        : 18'd0)
	                   + (nib[1] ? {3'd0, step[15:1]}  : 18'd0)
	                   + (nib[0] ? {4'd0, step[15:2]}  : 18'd0);

	wire signed [18:0] sum = nib[3] ? ($signed({{3{cur_s[15]}}, cur_s}) - $signed({1'b0, vpdiff}))
	                                : ($signed({{3{cur_s[15]}}, cur_s}) + $signed({1'b0, vpdiff}));

	wire signed [15:0] clamped = (sum >  19'sd32767) ?  16'sd32767 :
	                             (sum < -19'sd32768) ? -16'sd32768 : sum[15:0];

	wire signed  [4:0] idelta = idx_of(nib[2:0]);
	wire signed [11:0] inext  = $signed({5'd0, cur_i}) + $signed({{7{idelta[4]}}, idelta});
	wire        [6:0]  iclamp = inext[11] ? 7'd0 : (inext > 12'sd88) ? 7'd88 : inext[6:0];

	always @(posedge clk) begin
		pcm_valid <= 1'b0;
		if (reset) begin
			smp_l <= 16'sd0; smp_r <= 16'sd0;
			idx_l <= 7'd0;   idx_r <= 7'd0;
			st    <= 2'd0;
			pcm_l <= 16'd0;  pcm_r <= 16'd0;
		end else if (state_set) begin
			smp_l <= state_smp_l; idx_l <= (state_idx_l > 7'd88) ? 7'd88 : state_idx_l;
			smp_r <= state_smp_r; idx_r <= (state_idx_r > 7'd88) ? 7'd88 : state_idx_r;
			st    <= 2'd0;
		end else case (st)
			2'd0: if (byte_valid) begin hold <= byte_in; st <= 2'd1; end
			2'd1: begin smp_l <= clamped; idx_l <= iclamp; pcm_l <= clamped; st <= 2'd2; end
			2'd2: begin smp_r <= clamped; idx_r <= iclamp; pcm_r <= clamped;
			            pcm_valid <= 1'b1; st <= 2'd0; end
			default: st <= 2'd0;
		endcase
	end

endmodule

`default_nettype wire

