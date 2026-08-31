`include "thumb3_defs.vh"

module thumb3_alu
(
	input       [5:0] uop,
	input      [31:0] a,
	input      [31:0] b,
	input             c_in,

	input             shift_reg,

	input      [31:0] mul_in,

	output reg [31:0] q,
	output reg        n_out,
	output reg        z_out,
	output reg        c_out,
	output reg        v_out
);

	reg  [31:0] add_b;
	reg         add_c;
	wire [32:0] sum = {1'b0, a} + {1'b0, add_b} + {32'd0, add_c};

	wire ovf = (a[31] == add_b[31]) && (sum[31] != a[31]);

	wire [31:0] amt  = shift_reg ? b : {27'd0, b[4:0]};
	wire  [5:0] amt6 = (amt > 32'd63) ? 6'd63 : amt[5:0];

	reg [31:0] sh_q;
	reg        sh_c;

	always @* begin
		sh_q = a;
		sh_c = c_in;
		case (uop)
			`U_LSL: begin
				if (amt == 32'd0) begin

					sh_q = a; sh_c = c_in;
				end else if (amt < 32'd32) begin
					sh_c = a[32 - amt6];
					sh_q = a << amt6;
				end else if (amt == 32'd32) begin
					sh_c = a[0];  sh_q = 32'd0;
				end else begin
					sh_c = 1'b0;  sh_q = 32'd0;
				end
			end
			`U_LSR: begin

				if (amt == 32'd0 && shift_reg) begin
					sh_q = a; sh_c = c_in;
				end else if (amt == 32'd0 || amt == 32'd32) begin
					sh_c = a[31]; sh_q = 32'd0;
				end else if (amt < 32'd32) begin
					sh_c = a[amt6[4:0] - 5'd1];
					sh_q = a >> amt6;
				end else begin
					sh_c = 1'b0;  sh_q = 32'd0;
				end
			end
			`U_ASR: begin

				if (amt == 32'd0 && shift_reg) begin
					sh_q = a; sh_c = c_in;
				end else if (amt == 32'd0 || amt >= 32'd32) begin
					sh_c = a[31];
					sh_q = a[31] ? 32'hFFFFFFFF : 32'd0;
				end else begin
					sh_c = a[amt6[4:0] - 5'd1];
					sh_q = $signed(a) >>> amt6;
				end
			end
			`U_ROR: begin

				if (amt[7:0] == 8'd0) begin
					sh_q = a; sh_c = c_in;
				end else if (amt[4:0] == 5'd0) begin

					sh_q = a; sh_c = a[31];
				end else begin
					sh_q = (a >> amt[4:0]) | (a << (6'd32 - {1'b0, amt[4:0]}));
					sh_c = a[amt[4:0] - 5'd1];
				end
			end
			default: begin sh_q = a; sh_c = c_in; end
		endcase
	end

	always @* begin
		add_b = b;
		add_c = 1'b0;
		q     = 32'd0;
		c_out = c_in;
		v_out = 1'b0;

		case (uop)
			`U_MOV:  q = b;
			`U_MVN:  q = ~b;
			`U_AND, `U_TST: q = a & b;
			`U_ORR:  q = a | b;
			`U_EOR:  q = a ^ b;
			`U_BIC:  q = a & ~b;
			`U_MUL:  q = mul_in;

			`U_ADD, `U_CMN, `U_LOAD, `U_STORE, `U_BLOCK, `U_BLPFX, `U_BX: begin
				add_b = b; add_c = 1'b0;
				q = sum[31:0]; c_out = sum[32]; v_out = ovf;
			end
			`U_ADC: begin
				add_b = b; add_c = c_in;
				q = sum[31:0]; c_out = sum[32]; v_out = ovf;
			end
			`U_SUB, `U_CMP: begin
				add_b = ~b; add_c = 1'b1;
				q = sum[31:0]; c_out = sum[32]; v_out = ovf;
			end
			`U_SBC: begin
				add_b = ~b; add_c = c_in;
				q = sum[31:0]; c_out = sum[32]; v_out = ovf;
			end
			`U_NEG: begin

				add_b = ~b; add_c = 1'b1;
				q = sum[31:0]; c_out = sum[32]; v_out = ovf;
			end

			`U_LSL, `U_LSR, `U_ASR, `U_ROR: begin
				q = sh_q; c_out = sh_c;
			end

			`U_SXTB:  q = {{24{b[7]}},  b[7:0]};
			`U_SXTH:  q = {{16{b[15]}}, b[15:0]};
			`U_UXTB:  q = {24'd0, b[7:0]};
			`U_UXTH:  q = {16'd0, b[15:0]};
			`U_REV:   q = {b[7:0], b[15:8], b[23:16], b[31:24]};
			`U_REV16: q = {b[23:16], b[31:24], b[7:0], b[15:8]};
			`U_REVSH: q = {{16{b[7]}}, b[7:0], b[15:8]};

			default: q = b;
		endcase

		n_out = q[31];
		z_out = (q == 32'd0);
	end

endmodule

