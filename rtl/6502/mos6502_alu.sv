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
// MOS 6502 ALU and the decimal adjust adders.
//
// Structure follows the visual6502 netlist.
//
// Two notes on polarity and placement, because both look wrong at first:
//
//  * The silicon's ALU emits the complement of its result and the ADD hold
//    register inverts it again on phi2. The pair cancels, so this module
//    carries the true value throughout.
//
//  * The decimal adjust is NOT inside the ALU. It sits on the SB -> A path
//    only, so the uncorrected result is what reaches memory, ADL and DB.
//    That is the structural reason the BCD flag anomalies happen: N comes
//    from the uncorrected bit 7, Z from the uncorrected byte, and only the
//    accumulator ever sees the corrected value.
//============================================================================

// The ALU proper. Combinational; the ADD register that captures `res` lives
// in the datapath.
module mos6502_alu #(
	parameter bit BCD_EN = 1
) (
	input  logic [7:0] ai,
	input  logic [7:0] bi,

	input  logic       sums,
	input  logic       ands,
	input  logic       eors,
	input  logic       ors,
	input  logic       srs,
	input  logic       cin,

	input  logic       daa,

	output logic [7:0] res,
	output logic       acr,
	output logic       avr,
	output logic       hc
);

	logic [4:0] lo;
	logic [4:0] hi;
	logic [7:0] sum;
	logic       dc34;

	assign lo = {1'b0, ai[3:0]} + {1'b0, bi[3:0]} + {4'b0, cin};

	assign dc34 = BCD_EN && daa && (lo[4] || (lo[3] && (lo[2] || lo[1])));
	assign hc   = lo[4] | dc34;

	assign hi   = {1'b0, ai[7:4]} + {1'b0, bi[7:4]} + {4'b0, hc};
	assign sum  = {hi[3:0], lo[3:0]};

	logic dc78;
	assign dc78 = BCD_EN && daa && (hi[4] || (sum[7] && (sum[6] || sum[5])));

	assign avr = ~(ai[7] ^ bi[7]) & (ai[7] ^ sum[7]);

	assign acr = srs ? (ai[0] & bi[0]) : (hi[4] | dc78);

	always_comb begin
		unique case (1'b1)
			sums:    res = sum;
			ands:    res = ai & bi;
			eors:    res = ai ^ bi;
			ors:     res = ai | bi;
			srs:     res = {1'b0, ai[7:1] & bi[7:1]};
			default: res = 8'hFF;
		endcase
	end

endmodule

module mos6502_daa #(
	parameter bit BCD_EN = 1
) (
	input  logic [7:0] sb,
	input  logic       daa,
	input  logic       dsa,
	input  logic       hc,
	input  logic       acr,
	output logic [7:0] out
);

	logic add_lo, sub_lo, add_hi, sub_hi;

	assign add_lo = BCD_EN && daa && hc;
	assign sub_lo = BCD_EN && dsa && !hc;
	assign add_hi = BCD_EN && daa && acr;
	assign sub_hi = BCD_EN && dsa && !acr;

	always_comb begin
		out = sb;

		out[1] = sb[1] ^ (add_lo | sub_lo);
		out[2] = sb[2] ^ ((add_lo & ~sb[1]) | (sub_lo &  sb[1]));
		out[3] = sb[3] ^ ((add_lo &  (sb[1] | sb[2])) |
		                  (sub_lo & ~(sb[1] & sb[2])));

		out[5] = sb[5] ^ (add_hi | sub_hi);
		out[6] = sb[6] ^ ((add_hi & ~sb[5]) | (sub_hi &  sb[5]));
		out[7] = sb[7] ^ ((add_hi &  (sb[5] | sb[6])) |
		                  (sub_hi & ~(sb[5] & sb[6])));
	end

endmodule

