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
// SALLY - Atari's 6502C, the CPU in the 5200 and the 7800.
//
// A stock 6502 plus one pin: HALT, pin 35, active low, so MARIA can take the
// bus for display list DMA.
//
// WHERE THIS CIRCUIT CAME FROM
//
// Atari built this same function out of discrete parts on the 400/800 CPU
// board. HALT circuit.png, Figure 2-12: ANTIC's /HALT goes
// through a 74LS02 pair (Z301A/B) into a 7474 (Z302A/B) clocked off the phi
// pair, whose output enables two 74LS244 octal buffers (Z303, Z304) sitting
// between the CPU's address pins and the system bus - while the CPU itself is
// stalled through its ordinary RDY pin.
//
// For the 5200 and 7800 they folded all of that onto the CPU die. Tracing
// Schematic_Atari7800_NTSC_4000.jpg shows the 7800 board has
// none of those parts: SALLY's A0-A15 and D0-D7 go straight onto the bus,
// HALT arrives from MARIA pin 40 with only a 4k7 pull-up (R63), and MARIA
// drives RDY on a separate pin. So this module is on-die logic, not board
// logic - but it is the same circuit, which is why it is worth naming after
// the parts it replaced.
//
// TIMING
//
//              cycle N      N+1        N+2        N+3        N+4       N+5
//   phi2    __|~~~|_____|~~~|_____|~~~|_____|~~~|_____|~~~|_____|~~~|_____
//   halt_n  ~~~~\_____________________________________________/~~~~~~~~~~~
//                ^ MARIA moves it ~70 ns after phi2 falls
//   sample        s          s          s          s          s    <- phi2_en
//   addr_oe ~~~~~~~~~~~~~~~~~~~~~\____________________________________/~~~
//                                 ^ the bus is MARIA's from the start of N+2
//
// Measured from capture-range.sr (16 MHz, 19424 samples):
// the CPU clock is 558.8 ns (1.7896 MHz); /HALT is low for exactly 36 samples
// = 2.250 us = 4.03 CPU cycles on all three pulses in the capture; and every
// /HALT edge lands ~70 ns after phi2 falls, giving ~315 ns of setup before
// the next phi2. Sampling on phi2_en is therefore the far side of the cycle
// from MARIA's edge.
//
// The two cycles of latency in and out are NOT measured - the capture probed
// only SYNC, BLANK, /HALT and PCLK2, so it cannot see the bus change hands.
// Two cycles is what DMA.sv and souper.v independently assume, and moving
// that edge breaks both. Treat it as fitted, not established.
//
// THE TWO PATHS
//
// On the 800, ANTIC drives two separate things: RDY into the CPU's own RDY
// pin, which stalls it, and HALT into the flip-flop pair, which tristates the
// buffers. SALLY cannot copy that split: MARIA has no RDY of its own to spare
// and RDY holds a read but never a write, so a read-modify-write straddling
// the boundary writes into a bus MARIA already owns. HALT here therefore takes
// the core's phase enables away instead - see the comment on `bus_off`
// below.
//
// The consequence is the handover phase. `halt_s`/`halt_bus` move on phi2_en,
// so the bus and the core's phase enables change hands together at the start
// of phase 2, never at the cycle boundary. A cycle whose phase 1 was SALLY's
// simply stops there and finishes its phase 2 when the bus comes back, so no
// half cycle of core activity ever happens off the bus. That coupling is the
// contract.
//
// Nothing states this outright for SALLY - there is no die shot, and the
// existing logic capture has no address, R/W or output-enable channel - so the
// handover edge is fitted, not measured.
//============================================================================
module sally (
	input  logic        clk_sys,
	input  logic        phi1_en,
	input  logic        phi2_en,

	input  logic        res_n,
	input  logic        rdy,

	input  logic        irq_n,
	input  logic        nmi_n,
	input  logic        so_n,
	input  logic  [7:0] data_in,
	output logic  [7:0] data_out,
	output logic        data_oe,
	output logic [15:0] addr_out,
	output logic        rw_n,
	output logic        sync,
	output logic        phi1_out,
	output logic        phi2_out,

	input  logic        halt_n,

	output logic        addr_oe,
	output logic        rw_oe,
	output logic        is_halted,

	output logic        jammed,

	output logic  [7:0] dbg_a, dbg_x, dbg_y, dbg_s, dbg_p, dbg_ir,
	output logic [15:0] dbg_pc
);

	logic halt_s, halt_bus;

	always_ff @(posedge clk_sys) begin
		if (!res_n) begin
			halt_s   <= 1'b0;
			halt_bus <= 1'b0;
		end else if (phi2_en) begin
			halt_s   <= ~halt_n;
			halt_bus <= halt_s;
		end
	end

	logic core_data_oe;

	logic bus_off;
	assign bus_off   = halt_s & halt_bus;

	assign addr_oe   = ~bus_off;
	assign rw_oe     = ~bus_off;
	assign data_oe   = core_data_oe & ~bus_off;
	assign is_halted = bus_off;

	logic core_phi1_en, core_phi2_en;
	assign core_phi1_en = phi1_en & ~bus_off;
	assign core_phi2_en = phi2_en & ~bus_off;

	logic phase2;
	always_ff @(posedge clk_sys) begin
		if      (phi1_en) phase2 <= 1'b0;
		else if (phi2_en) phase2 <= 1'b1;
	end

	assign phi1_out = ~phase2;
	assign phi2_out =  phase2;

	mos6502 #(.BCD_EN(1'b1)) core (
		.clk_sys  (clk_sys),
		.phi1_en  (core_phi1_en),
		.phi2_en  (core_phi2_en),
		.res_n    (res_n),
		.rdy      (rdy),
		.irq_n    (irq_n),
		.nmi_n    (nmi_n),
		.so_n     (so_n),
		.data_in  (data_in),
		.data_out (data_out),
		.data_oe  (core_data_oe),
		.addr_out (addr_out),
		.rw_n     (rw_n),
		.sync     (sync),
		.phi1_out (),
		.phi2_out (),
		.jammed   (jammed),

		.dbg_a (dbg_a), .dbg_x (dbg_x), .dbg_y(dbg_y), .dbg_s(dbg_s),
		.dbg_p (dbg_p), .dbg_ir(dbg_ir), .dbg_pc(dbg_pc),
		.dbg_t (), .dbg_hold(), .dbg_int_active(), .dbg_take_int(),
		.dbg_res_active(), .dbg_tg()
	);

endmodule

