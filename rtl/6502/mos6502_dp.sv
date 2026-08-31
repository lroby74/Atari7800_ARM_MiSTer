// k7800 (c) by Jamie Blanks
//
// Copyright (c) 2026 Jamie Blanks
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

//============================================================================
// MOS 6502 datapath: the four internal buses and every register hanging off
// them. Structure follows the visual6502 netlist.
//
// Why this is worth building as the real thing rather than as an ALU with a
// state machine around it: the awkward behaviour a 6502 core has to get right
// is mostly structural. The unfixed high byte on cycle 4 of abs,X falls out
// of ADL/ADH being separate buses with one adder between them. ROR's carry-in
// falls out of SB bit 7 having its own control line. $01xx and $FFxx fall out
// of forcing bits low against a precharged bus. None of that needs a special
// case here, because the wires are the ones the die has.
//
// Phases: every register is clocked by clk_sys and gated by phi1_en or
// phi2_en, whichever phase the silicon's latch is transparent on.
//============================================================================
module mos6502_dp
	import mos6502_pkg::*;
#(
	parameter bit BCD_EN = 1'b1
) (
	input  logic       clk_sys,
	input  logic       phi1_en,
	input  logic       phi2_en,

	input  ctl_t       c,
	input  logic [7:0] ir,
	input  logic [7:0] data_in,

	output logic [7:0] a, x, y, s,
	output logic [7:0] p,
	output logic [7:0] dl,
	output logic [15:0] addr_out,
	output logic [7:0] data_out,

	output logic       acr_now,

	output logic [7:0] pcl, pch
);

	logic [7:0] s_in, s_out;
	logic [7:0] pcls, pchs;
	logic [7:0] abl, abh;
	logic [7:0] dor;
	logic [7:0] ai, bi;
	logic [7:0] add;
	logic       acr, avr;

	logic p_n, p_v, p_d, p_i, p_z, p_c;
	logic [7:0] p_out;

	logic [7:0] db, sb, adl, adh;

	logic [7:0] db_raw, sb_raw, adh_raw;

	always_comb begin
		db_raw = 8'hFF;
		if (c.dl_db)  db_raw &= dl;
		if (c.dl0_db) db_raw[0] &= dl[0];
		if (c.pcl_db) db_raw &= pcl;
		if (c.pch_db) db_raw &= pch;
		if (c.ac_db)  db_raw &= a;
		if (c.p_db)   db_raw &= p_out;
	end

	always_comb begin
		sb_raw = 8'hFF;
		if (c.s_sb)     sb_raw &= s_out;
		if (c.x_sb)     sb_raw &= x;
		if (c.y_sb)     sb_raw &= y;
		if (c.ac_sb)    sb_raw &= a;
		if (c.add_sb06) sb_raw[6:0] &= add[6:0];
		if (c.add_sb7)  sb_raw[7]   &= add[7];
	end

	always_comb begin
		adl = 8'hFF;
		if (c.dl_adl)  adl &= dl;
		if (c.pcl_adl) adl &= pcl;
		if (c.s_adl)   adl &= s_out;
		if (c.add_adl) adl &= add;
		if (c.zero_adl0) adl[0] = 1'b0;
		if (c.zero_adl1) adl[1] = 1'b0;
		if (c.zero_adl2) adl[2] = 1'b0;
	end

	always_comb begin
		adh_raw = 8'hFF;
		if (c.dl_adh)  adh_raw &= dl;
		if (c.pch_adh) adh_raw &= pch;
		if (c.zero_adh0)  adh_raw[0]   = 1'b0;
		if (c.zero_adh17) adh_raw[7:1] = 7'b0;
	end

	always_comb begin
		logic [7:0] merged;
		merged = sb_raw;
		if (c.sb_db)  merged &= db_raw;
		if (c.sb_adh) merged &= adh_raw;

		sb  = merged;
		db  = c.sb_db  ? merged : db_raw;
		adh = c.sb_adh ? merged : adh_raw;
	end

	logic [7:0] alu_res, a_next;
	logic       alu_acr, alu_avr, alu_hc;
	logic       alu_active;

	assign alu_active = c.sums | c.ands | c.eors | c.ors | c.srs;
	logic       hc_held;

	mos6502_alu #(.BCD_EN(BCD_EN)) alu (
		.ai(ai), .bi(bi), .cin(c.alucin),
		.sums(c.sums), .ands(c.ands), .eors(c.eors), .ors(c.ors), .srs(c.srs),
		.daa(c.daa),
		.res(alu_res), .acr(alu_acr), .avr(alu_avr),
		.hc(alu_hc)
	);

	logic [7:0] daa_out;
	mos6502_daa #(.BCD_EN(BCD_EN)) adjust (
		.sb(sb), .daa(c.daa), .dsa(c.dsa), .hc(hc_held), .acr(acr),
		.out(daa_out)
	);

	logic arr_lo_q, arr_hi_q;
	logic [7:0] arr_fix;
	always_comb begin
		arr_fix = sb;
		if (arr_lo_q) arr_fix[3:0] = sb[3:0] + 4'd6;
		if (arr_hi_q) arr_fix[7:4] = sb[7:4] + 4'd6;
	end

	assign a_next = c.arr_daa ? arr_fix : daa_out;

	logic       pc_carry;
	logic [7:0] pcl_next, pch_next;

	assign {pc_carry, pcl_next} = {1'b0, pcls} + {8'b0, c.ipc};
	assign pch_next = pchs + {7'b0, pc_carry};

	assign p     = {p_n, p_v, 2'b00, p_d, p_i, p_z, p_c};

	assign p_out = {p_n, p_v | c.so_v, 1'b1, c.b_out, p_d, p_i, p_z, p_c};

	always_ff @(posedge clk_sys) begin
		if (phi1_en) begin
			if (c.sb_x)  x <= sb;
			if (c.sb_y)  y <= sb;
			if (c.sb_ac) a <= a_next;
			if      (c.sb_s) s_in <= sb;
			else if (c.s_inc) s_in <= s_out + 8'd1;
			else if (c.s_dec) s_in <= s_out - 8'd1;

			if (c.sb_add)  ai <= sb;
			if (c.zero_add) ai <= 8'h00;
			if (c.db_add)  bi <= db;
			if (c.ndb_add) bi <= ~db;
			if (c.adl_add) bi <= adl;

			if      (c.adl_pcl) pcls <= adl;
			else                pcls <= pcl;
			if      (c.adh_pch) pchs <= adh;
			else                pchs <= pch;

			if (c.adl_abl) abl <= adl;
			if (c.adh_abh) abh <= adh;

			dor <= db;

			if (c.so_v)   p_v <= 1'b1;
			if (c.db_p) begin
				p_z <= db[1];
				p_i <= db[2];
				p_d <= db[3];
			end
			if (c.db0_c)  p_c <= db[0];
			if (c.ir5_c)  p_c <= ir[5];
			if (c.acr_c)  p_c <= acr;
			if (c.db7_n)  p_n <= db[7];
			if (c.dbz_z)  p_z <= (db == 8'h00);
			if (c.ir5_i)  p_i <= ir[5];
			if (c.one_i)  p_i <= 1'b1;
			if (c.ir5_d)  p_d <= ir[5];
			if (c.db6_v)  p_v <= db[6];
			if (c.db7_c)  p_c <= db[7];
			if (c.arr_flags) begin
				p_c <= c.arr_daa ? arr_hi_q : db[6];
				p_v <= db[6] ^ db[5];
			end
			if (c.avr_v)  p_v <= avr;
			if (c.one_v)  p_v <= 1'b1;
			if (c.zero_v) p_v <= 1'b0;
		end

		if (phi2_en) begin

			if (c.arr_d) begin
				arr_lo_q <= ai[3:0] >= 4'd5;
				arr_hi_q <= ai[7:4] >= 4'd5;
			end

			if (c.add_ff)      add <= 8'hFF;
			else if (alu_active) begin
				add     <= alu_res;
				acr     <= alu_acr;
				avr     <= alu_avr;
				hc_held <= alu_hc;
			end

			dl <= data_in;

			if (c.alu_n) p_n <= alu_res[7];
			if (c.alu_z) p_z <= (alu_res == 8'h00);
			if (c.alu_c) p_c <= alu_acr;
			if (c.alu_v) p_v <= alu_avr;

			pcl <= pcl_next;
			pch <= pch_next;

			s_out <= c.s_s ? s_out : s_in;
		end
	end

	assign acr_now  = alu_acr;
	assign s        = s_out;
	assign addr_out = {abh, abl};
	assign data_out = dor;

endmodule

