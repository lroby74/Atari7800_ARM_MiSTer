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
// NMOS 6502, 40-pin part, cycle accurate.
//
// Real pins only. Nothing Atari-specific lives here: the 7800's HALT is in
// sally.sv, and the NES 2A03's DMA stall arrives on `rdy` like any other RDY
// source. With BCD_EN=0 this is the 2A03/2A07 core.
//
// phi0 (pin 37) is replaced by the clk_sys + phi1_en/phi2_en trio, which is
// the one documented departure from the pin contract. Everything clocked runs
// off clk_sys and is gated by one of the two enables, so clk_sys can be as
// fast as the system needs without changing target timing.
//============================================================================
module mos6502
	import mos6502_pkg::*;
#(

	parameter bit BCD_EN = 1'b1
) (

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

	output logic        jammed,

	output logic  [7:0] dbg_a, dbg_x, dbg_y, dbg_s, dbg_p, dbg_ir,
	output logic [15:0] dbg_pc,
	output logic  [3:0] dbg_t,
	output logic        dbg_hold, dbg_int_active, dbg_take_int, dbg_res_active,
	output logic [15:0] dbg_tg
);

	ctl_t       c;
	logic       sync_ctl;
	logic [7:0] ir;
	logic [7:0] a, x, y, s, p, dl, pcl, pch;
	logic       acr_now;

	mos6502_ctl #(.BCD_EN(BCD_EN)) ctl (
		.clk_sys(clk_sys), .phi1_en(phi1_en), .phi2_en(phi2_en),
		.res_n(res_n), .rdy(rdy), .irq_n(irq_n), .nmi_n(nmi_n), .so_n(so_n),
		.data_in(data_in), .p(p), .acr_now(acr_now), .dl(dl),
		.c(c), .ir(ir), .sync(sync_ctl), .jammed(jammed),
		.dbg_t(dbg_t), .dbg_hold(dbg_hold),
		.dbg_int_active(dbg_int_active), .dbg_take_int(dbg_take_int),
		.dbg_res_active(dbg_res_active), .dbg_tg(dbg_tg)
	);

	mos6502_dp #(.BCD_EN(BCD_EN)) dp (
		.clk_sys(clk_sys), .phi1_en(phi1_en), .phi2_en(phi2_en),
		.c(c), .ir(ir), .data_in(data_in),
		.a(a), .x(x), .y(y), .s(s), .p(p), .dl(dl),
		.addr_out(addr_out), .data_out(data_out),
		.acr_now(acr_now), .pcl(pcl), .pch(pch)
	);

	assign dbg_a  = a;   assign dbg_x = x;  assign dbg_y = y;
	assign dbg_s  = s;   assign dbg_p = p;  assign dbg_ir = ir;
	assign dbg_pc = {pch, pcl};

	logic phase2;
	always_ff @(posedge clk_sys) begin
		if      (phi1_en) phase2 <= 1'b0;
		else if (phi2_en) phase2 <= 1'b1;
	end

	assign phi1_out = ~phase2;
	assign phi2_out =  phase2;

	logic wr_pin, sync_pin;
	always_ff @(posedge clk_sys) begin
		if (phi1_en) begin
			wr_pin   <= c.wr;
			sync_pin <= sync_ctl;
		end
	end

	assign rw_n = ~wr_pin;
	assign sync = sync_pin;

	assign data_oe = wr_pin & phase2;

endmodule

