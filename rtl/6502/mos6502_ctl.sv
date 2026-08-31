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
// MOS 6502 control: predecode, the timing generator, and the per-cycle
// datapath steering for all 256 opcodes.
//
// THE ONE TIMING FACT THIS IS BUILT AROUND
//
// The random control logic latches its outputs on phase 2 and applies them on
// the following phase 1. So the
// control word driving cycle N was decided during phase 2 of cycle N-1. That
// is not a detail - it is what lets an instruction finish after IR has
// already been overwritten by the next opcode, which is how a 3-cycle
// LDA/ORA works at all. Everything here follows from it:
//
//   phase 1 of N : the latched control word is applied. Registers load, the
//                  address pins change.
//   phase 2 of N : memory data arrives. DL, ADD, PCL and PCH capture. The
//                  control word for cycle N+1 is computed and latched.
//
// T-STATES
//
// Cycle numbers here match the "#" column of the usual addressing-mode cycle
// tables. In the silicon's own naming, t==1 is T1
// (SYNC, and also T+ of the instruction just finishing) and the last cycle of
// an instruction is T0.
//
// WHY IR AND THE INCOMING BYTE ARE BOTH USED
//
// At phase 2 of the fetch cycle we are deciding the control for cycle 2 while
// IR still holds the *previous* opcode - which is exactly what we want, since
// that instruction's writeback happens on cycle 2's phase 1. The new opcode
// is on the data pins at that moment, so cycle 2's own sequencing comes from
// predecode reading those pins directly. That is what predecode is for on the
// real part, and it is why it can shorten a two-cycle instruction before the
// opcode has reached IR.
//============================================================================
module mos6502_ctl
	import mos6502_pkg::*;
#(
	parameter bit BCD_EN = 1'b1
) (
	input  logic       clk_sys,
	input  logic       phi1_en,

	input  logic       phi2_en,

	input  logic       res_n,
	input  logic       rdy,
	input  logic       irq_n,
	input  logic       nmi_n,
	input  logic       so_n,

	input  logic [7:0] data_in,
	input  logic [7:0] p,
	input  logic       acr_now,
	input  logic [7:0] dl,

	output ctl_t       c,
	output logic [7:0] ir,
	output logic       sync,
	output logic       jammed,

	output logic [3:0] dbg_t,
	output logic       dbg_hold,
	output logic       dbg_int_active,
	output logic       dbg_res_active,

	output logic [15:0] dbg_tg,
	output logic       dbg_take_int
);

	logic [3:0] t = 4'd1;

	ctl_t       c_reg;
	logic [3:0] nt;
	ctl_t       nc;

	decode_t    d;
	mos6502_decode decode (.ir(ir), .d(d));

	logic int_g, res_g, int_armed;

	logic int_active, res_active;
	assign res_active = res_g;
	assign int_active = int_g | res_g;

	logic nmi_pending;

	logic res_now;
	assign res_now = res_g | res_c2;
	logic so_last;

	logic sh_store;
	assign sh_store = (d.store == ST_SHA) || (d.store == ST_SHX) ||
	                  (d.store == ST_SHY) || (d.store == ST_TAS);

	logic pgx;
	logic idx_cross_q;
	logic br_take;
	logic br_back;
	logic br_fix;

	typedef enum logic [1:0] { PC_PC, PC_EA, PC_ADD, PC_FIX } pcsrc_e;
	pcsrc_e n_pc_src;

	assign sync = (hold ? sync_q : (t == 4'd1)) & ~res_no_prefetch;

	assign jammed = (d.mode == M_JAM) && (t >= 4'd2);

	assign dbg_t = t;
	assign dbg_hold = hold;
	assign dbg_int_active = int_active;
	assign dbg_res_active = res_active;
	assign dbg_tg = {4'd0, res_no_prefetch, res_p, end_x_q, t_zero, ext_t6, ext_t5, tg};
	assign dbg_take_int = take_int;

	logic pd_implied;

	assign pd_implied = data_in[3] & ~data_in[2] & ~data_in[0];

	logic pd_two_cycle;
	always_comb begin
		logic imp, m_xxx010x1, m_1xx000x0, m_0xx01000;
		imp        =  ir[3] & ~ir[2] & ~ir[0];
		m_xxx010x1 = ~ir[4] &  ir[3] & ~ir[2] &  ir[0];
		m_1xx000x0 =  ir[7] & ~ir[4] & ~ir[3] & ~ir[2] & ~ir[0];
		m_0xx01000 = ~ir[7] & ~ir[4] &  ir[3] & ~ir[2] & ~ir[1] & ~ir[0];
		pd_two_cycle = m_xxx010x1 | m_1xx000x0 | (imp & ~m_0xx01000);
	end

	function automatic ctl_t addr_pc();
		ctl_t r = CTL_IDLE;
		r.pcl_adl = 1'b1; r.pch_adh = 1'b1;
		r.adl_abl = 1'b1; r.adh_abh = 1'b1;
		return r;
	endfunction

	function automatic ctl_t addr_zp();
		ctl_t r = CTL_IDLE;
		r.dl_adl = 1'b1;
		r.zero_adh0 = 1'b1; r.zero_adh17 = 1'b1;
		r.adl_abl = 1'b1; r.adh_abh = 1'b1;
		return r;
	endfunction

	function automatic ctl_t addr_zp_add();
		ctl_t r = CTL_IDLE;
		r.add_adl = 1'b1;
		r.zero_adh0 = 1'b1; r.zero_adh17 = 1'b1;
		r.adl_abl = 1'b1; r.adh_abh = 1'b1;
		return r;
	endfunction

	function automatic ctl_t addr_stack();
		ctl_t r = CTL_IDLE;
		r.s_adl = 1'b1;
		r.zero_adh17 = 1'b1;
		r.adl_abl = 1'b1; r.adh_abh = 1'b1;
		return r;
	endfunction

	function automatic ctl_t addr_dl_add();
		ctl_t r = CTL_IDLE;
		r.add_adl = 1'b1; r.dl_adh = 1'b1;
		r.adl_abl = 1'b1; r.adh_abh = 1'b1;
		return r;
	endfunction

	function automatic ctl_t addr_fix_hi();
		ctl_t r = CTL_IDLE;
		r.add_sb06 = 1'b1; r.add_sb7 = 1'b1;
		r.sb_adh = 1'b1; r.adh_abh = 1'b1;
		return r;
	endfunction

	function automatic ctl_t addr_add_pch();
		ctl_t r = CTL_IDLE;
		r.add_adl = 1'b1; r.pch_adh = 1'b1;
		r.adl_abl = 1'b1; r.adh_abh = 1'b1;
		return r;
	endfunction

	function automatic ctl_t addr_vector(input logic hi);
		ctl_t r = CTL_IDLE;
		r.zero_adl0 = ~hi;
		r.zero_adl1 = res_now;
		r.zero_adl2 = nmi_pending & ~res_now;
		r.adl_abl = 1'b1; r.adh_abh = 1'b1;
		return r;
	endfunction

	function automatic ctl_t alu_index(input logic use_x);
		ctl_t r = CTL_IDLE;
		if (use_x) r.x_sb = 1'b1; else r.y_sb = 1'b1;
		r.sb_add = 1'b1;
		r.dl_db  = 1'b1; r.db_add = 1'b1;
		r.sums   = 1'b1;
		return r;
	endfunction

	function automatic ctl_t alu_fix(input logic carry);
		ctl_t r = CTL_IDLE;
		r.zero_add = 1'b1;
		r.dl_db = 1'b1; r.db_add = 1'b1;
		r.sums = 1'b1;
		r.alucin = carry;
		return r;
	endfunction

	function automatic ctl_t op_a(input decode_t o);
		ctl_t r = CTL_IDLE;
		logic combo;

		combo = (o.rmw != RMW_NONE) && (o.data != D_NONE) && (o.mode != M_ACC);

		if (combo) begin
			unique case (o.data)
			D_ORA: begin r.ac_sb=1; r.sb_add=1; r.ors =1; end
			D_AND: begin r.ac_sb=1; r.sb_add=1; r.ands=1; end
			D_EOR: begin r.ac_sb=1; r.sb_add=1; r.eors=1; end
			D_ADC: begin r.ac_sb=1; r.sb_add=1; r.sums=1; r.alucin=p[0];
			             r.daa=BCD_EN & p[3]; end
			D_SBC: begin r.ac_sb=1; r.sb_add=1; r.sums=1; r.alucin=p[0];
			             r.dsa=BCD_EN & p[3]; end
			D_CMP: begin r.ac_sb=1; r.sb_add=1; r.sums=1; r.alucin=1; end
			default: ;
			endcase
			return r;
		end

		unique case (o.data)
		D_LDA: begin r.dl_db=1; r.sb_db=1; r.sb_ac=1; r.db7_n=1; r.dbz_z=1; end
		D_LDX: begin r.dl_db=1; r.sb_db=1; r.sb_x =1; r.db7_n=1; r.dbz_z=1; end
		D_LDY: begin r.dl_db=1; r.sb_db=1; r.sb_y =1; r.db7_n=1; r.dbz_z=1; end
		D_LAX: begin r.dl_db=1; r.sb_db=1; r.sb_ac=1; r.sb_x=1;
		             r.db7_n=1; r.dbz_z=1; end
		D_ORA: begin r.ac_sb=1; r.sb_add=1; r.dl_db=1; r.db_add=1; r.ors =1; end
		D_AND: begin r.ac_sb=1; r.sb_add=1; r.dl_db=1; r.db_add=1; r.ands=1; end

		D_ANC: begin r.ac_sb=1; r.sb_add=1; r.dl0_db=1; r.db_add=1; r.ands=1; end
		D_ALR: begin r.ac_sb=1; r.sb_add=1; r.dl0_db=1; r.db_add=1; r.srs=1; end
		D_ARR: begin r.ac_sb=1; r.sb_add=1; r.dl0_db=1; r.db_add=1; r.srs=1;
		             r.arr_d = BCD_EN & p[3]; end

		D_LAS: begin r.s_sb=1;  r.sb_add=1; r.sb_x=1;
		             r.dl_db=1; r.db_add=1; r.ands=1; end

		D_ANE: begin r.ac_sb=1; r.x_sb=1; r.sb_add=1;
		             r.dl_db=1; r.db_add=1; r.ands=1; end
		D_LXA: begin r.ac_sb=1; r.sb_add=1; r.dl_db=1; r.db_add=1; r.ands=1; end
		D_EOR: begin r.ac_sb=1; r.sb_add=1; r.dl_db=1; r.db_add=1; r.eors=1; end
		D_ADC: begin r.ac_sb=1; r.sb_add=1; r.dl_db=1; r.db_add=1;
		             r.sums=1; r.alucin=p[0]; r.daa=BCD_EN & p[3]; end
		D_SBC: begin r.ac_sb=1; r.sb_add=1; r.dl_db=1; r.ndb_add=1;
		             r.sums=1; r.alucin=p[0]; r.dsa=BCD_EN & p[3]; end
		D_CMP: begin r.ac_sb=1; r.sb_add=1; r.dl_db=1; r.ndb_add=1;
		             r.sums=1; r.alucin=1; end
		D_CPX: begin r.x_sb =1; r.sb_add=1; r.dl_db=1; r.ndb_add=1;
		             r.sums=1; r.alucin=1; end
		D_CPY: begin r.y_sb =1; r.sb_add=1; r.dl_db=1; r.ndb_add=1;
		             r.sums=1; r.alucin=1; end

		D_BIT: begin r.ac_sb=1; r.sb_add=1; r.dl_db=1; r.db_add=1; r.ands=1;
		             r.db7_n=1; r.db6_v=1; end
		D_SBX: begin r.ac_sb=1; r.x_sb=1; r.sb_add=1; r.dl_db=1; r.ndb_add=1;
		             r.sums=1; r.alucin=1; end
		default: ;
		endcase

		if (o.mode == M_ACC) begin
			r.ac_sb = 1; r.sb_add = 1; r.ac_db = 1; r.db_add = 1;
			unique case (o.rmw)
			RMW_ASL: begin r.sums = 1; end
			RMW_ROL: begin r.sums = 1; r.alucin = p[0]; end
			RMW_LSR: begin r.srs  = 1; end
			RMW_ROR: begin r.srs  = 1; end
			default: ;
			endcase
		end

		if (o.mode == M_PULL) begin
			r.dl_db = 1;
			if (ir[6]) begin
				r.sb_db = 1; r.sb_ac = 1; r.db7_n = 1; r.dbz_z = 1;
			end else begin
				r.db_p = 1; r.db0_c = 1; r.db6_v = 1; r.db7_n = 1;
			end
		end

		if (o.mode == M_IMP) begin
			unique case (o.imp)
			I_TAX: begin r.ac_sb=1; r.sb_db=1; r.sb_x =1; r.db7_n=1; r.dbz_z=1; end
			I_TAY: begin r.ac_sb=1; r.sb_db=1; r.sb_y =1; r.db7_n=1; r.dbz_z=1; end
			I_TXA: begin r.x_sb =1; r.sb_db=1; r.sb_ac=1; r.db7_n=1; r.dbz_z=1; end
			I_TYA: begin r.y_sb =1; r.sb_db=1; r.sb_ac=1; r.db7_n=1; r.dbz_z=1; end
			I_TSX: begin r.s_sb =1; r.sb_db=1; r.sb_x =1; r.db7_n=1; r.dbz_z=1; end
			I_TXS: begin r.x_sb =1; r.sb_s =1; end

			I_INX: begin r.x_sb=1; r.sb_add=1; r.ndb_add=1; r.sums=1; r.alucin=1; end
			I_INY: begin r.y_sb=1; r.sb_add=1; r.ndb_add=1; r.sums=1; r.alucin=1; end
			I_DEX: begin r.x_sb=1; r.sb_add=1; r.db_add =1; r.sums=1; end
			I_DEY: begin r.y_sb=1; r.sb_add=1; r.db_add =1; r.sums=1; end
			I_CLC, I_SEC: r.ir5_c = 1;
			I_CLI, I_SEI: r.ir5_i = 1;
			I_CLD, I_SED: r.ir5_d = 1;
			I_CLV:        r.zero_v = 1;
			default: ;
			endcase
		end
		return r;
	endfunction

	function automatic ctl_t op_b(input decode_t o);
		ctl_t r = CTL_IDLE;
		logic wrote;
		wrote = 1'b0;

		unique case (o.data)
		D_ORA, D_AND, D_EOR:
			begin r.sb_ac=1; r.db7_n=1; r.dbz_z=1; wrote=1; end
		D_ADC:
			begin r.sb_ac=1; r.db7_n=1; r.dbz_z=1; r.acr_c=1; r.avr_v=1;
			      r.daa=BCD_EN & p[3]; wrote=1; end
		D_SBC:
			begin r.sb_ac=1; r.db7_n=1; r.dbz_z=1; r.acr_c=1; r.avr_v=1;
			      r.dsa=BCD_EN & p[3]; wrote=1; end
		D_CMP, D_CPX, D_CPY:
			begin r.db7_n=1; r.dbz_z=1; r.acr_c=1; wrote=1; end

		D_BIT:
			begin r.dbz_z=1; wrote=1; end

		D_ANC:
			begin r.db7_n=1; r.dbz_z=1; r.db7_c=1; wrote=1; end
		D_ALR:
			begin r.sb_ac=1; r.db7_n=1; r.dbz_z=1; r.acr_c=1; wrote=1; end

		D_ARR:
			begin r.sb_ac=1; r.db7_n=1; r.dbz_z=1; r.arr_flags=1;
			      r.arr_daa = BCD_EN & p[3]; wrote=1; end

		D_LAS:
			begin r.sb_ac=1; r.db7_n=1; r.dbz_z=1; wrote=1; end
		D_ANE:
			begin r.sb_ac=1; r.db7_n=1; r.dbz_z=1; wrote=1; end
		D_LXA:
			begin r.sb_ac=1; r.sb_x=1; r.db7_n=1; r.dbz_z=1; wrote=1; end
		D_SBX:
			begin r.sb_x=1; r.db7_n=1; r.dbz_z=1; r.acr_c=1; wrote=1; end
		default: ;
		endcase

		if (o.mode == M_ACC) begin
			r.sb_ac=1; r.db7_n=1; r.dbz_z=1; r.acr_c=1; wrote=1;
		end

		if (o.mode == M_IMP) begin
			unique case (o.imp)
			I_INX, I_DEX: begin r.sb_x=1; r.db7_n=1; r.dbz_z=1; wrote=1; end
			I_INY, I_DEY: begin r.sb_y=1; r.db7_n=1; r.dbz_z=1; wrote=1; end
			default: ;
			endcase
		end

		if (wrote) begin
			r.add_sb06 = 1;
			r.add_sb7  = ((o.mode == M_ACC && o.rmw == RMW_ROR) ||
			              (o.data == D_ARR)) ? ~p[0] : 1'b1;
			r.sb_db    = 1;
		end
		return r;
	endfunction

	function automatic ctl_t op_rmw(input rmwop_e k);
		ctl_t r = CTL_IDLE;
		r.dl_db = 1; r.db_add = 1;
		unique case (k)
		RMW_ASL: begin r.sb_db=1; r.sb_add=1; r.sums=1; end
		RMW_ROL: begin r.sb_db=1; r.sb_add=1; r.sums=1; r.alucin=p[0]; end
		RMW_LSR: begin r.sb_db=1; r.sb_add=1; r.srs =1; end
		RMW_ROR: begin r.sb_db=1; r.sb_add=1; r.srs =1; end
		RMW_INC: begin r.zero_add=1;          r.sums=1; r.alucin=1; end
		RMW_DEC: begin r.sb_add=1;            r.sums=1; end
		default: ;
		endcase
		return r;
	endfunction

	function automatic ctl_t rmw_out(input rmwop_e k, input dataop_e dop);
		ctl_t r = CTL_IDLE;
		r.add_sb06 = 1;
		r.add_sb7  = (k == RMW_ROR) ? ~p[0] : 1'b1;
		r.sb_db    = 1;
		r.db7_n    = 1; r.dbz_z = 1;
		if (k != RMW_INC && k != RMW_DEC) r.acr_c = 1;

		if (dop == D_CMP || dop == D_SBC) r.ndb_add = 1;
		else if (dop != D_NONE)           r.db_add  = 1;
		return r;
	endfunction

	function automatic ctl_t store_out(input storesrc_e k);
		ctl_t r = CTL_IDLE;
		unique case (k)
		ST_A:  begin r.ac_db = 1; end
		ST_X:  begin r.x_sb = 1; r.sb_db = 1; end
		ST_Y:  begin r.y_sb = 1; r.sb_db = 1; end
		ST_AX: begin r.ac_db = 1; r.x_sb = 1; r.sb_db = 1; end
		ST_SHA, ST_TAS:
		       begin r.ac_db = 1; r.x_sb = 1; r.sb_db = 1;
		             r.add_sb06 = 1; r.add_sb7 = 1; end
		ST_SHX: begin r.x_sb = 1; r.sb_db = 1;
		             r.add_sb06 = 1; r.add_sb7 = 1; end
		ST_SHY: begin r.y_sb = 1; r.sb_db = 1;
		             r.add_sb06 = 1; r.add_sb7 = 1; end
		default: ;
		endcase
		return r;
	endfunction

	function automatic ctl_t store_sh(input storesrc_e k, input logic crossed);
		ctl_t r = store_out(k);
		r.wr = 1'b1;
		if (crossed) begin r.sb_adh = 1'b1; r.adh_abh = 1'b1; end
		return r;
	endfunction

	function automatic ctl_t seq(input decode_t o, input logic [3:0] n,
	                             input logic idx_crossed);
		ctl_t r = CTL_IDLE;

		unique case (o.mode)

		M_ZP: unique case (n)
			4'd3: begin r = addr_zp();
			            if (o.access == A_WRITE) begin
			                r.wr = 1; r = r | store_out(o.store);
			            end
			      end
			4'd4: begin r.wr = 1; r.dl_db = 1; r = r | op_rmw(o.rmw); end
			4'd5: begin r.wr = 1; r = r | rmw_out(o.rmw, o.data); end
			default: ;
			endcase

		M_ZPX, M_ZPY: unique case (n)
			4'd3: begin r = addr_zp() | alu_index(o.mode == M_ZPX); end
			4'd4: begin r = addr_zp_add();
			            if (o.access == A_WRITE) begin
			                r.wr = 1; r = r | store_out(o.store);
			            end
			      end
			4'd5: begin r.wr = 1; r.dl_db = 1; r = r | op_rmw(o.rmw); end
			4'd6: begin r.wr = 1; r = r | rmw_out(o.rmw, o.data); end
			default: ;
			endcase

		M_ABS: unique case (n)
			4'd3: begin r = addr_pc(); r.pcl_pcl = 1; r.pch_pch = 1; r.ipc = 1;
			            r = r | alu_fix(1'b0);
			      end
			4'd4: begin r = addr_dl_add();
			            if (o.access == A_WRITE) begin
			                r.wr = 1; r = r | store_out(o.store);
			            end
			      end
			4'd5: begin r.wr = 1; r.dl_db = 1; r = r | op_rmw(o.rmw); end
			4'd6: begin r.wr = 1; r = r | rmw_out(o.rmw, o.data); end
			default: ;
			endcase

		M_ABX, M_ABY: unique case (n)
			4'd3: begin r = addr_pc(); r.pcl_pcl = 1; r.pch_pch = 1; r.ipc = 1;
			            r = r | alu_index(o.mode == M_ABX);
			      end

			4'd4: begin r = addr_dl_add() | alu_fix(sh_store ? 1'b1 : acr_now);
			            if (o.store == ST_TAS) begin
			                r.ac_sb = 1; r.x_sb = 1; r.sb_s = 1;
			            end
			      end
			4'd5: begin if (sh_store) r = store_sh(o.store, idx_crossed);
			            else begin
			                r = addr_fix_hi();
			                if (o.access == A_WRITE) begin
			                    r.wr = 1; r = r | store_out(o.store);
			                end
			            end
			      end
			4'd6: begin r.wr = 1; r.dl_db = 1; r = r | op_rmw(o.rmw); end
			4'd7: begin r.wr = 1; r = r | rmw_out(o.rmw, o.data); end
			default: ;
			endcase

		M_IZX: unique case (n)
			4'd3: begin r = addr_zp() | alu_index(1'b1); end
			4'd4: begin r = addr_zp_add();

			            r.add_sb06 = 1; r.add_sb7 = 1; r.sb_add = 1;
			            r.ndb_add = 1; r.sums = 1; r.alucin = 1;
			      end
			4'd5: begin r = addr_zp_add() | alu_fix(1'b0); end
			4'd6: begin r = addr_dl_add();
			            if (o.access == A_WRITE) begin
			                r.wr = 1; r = r | store_out(o.store);
			            end
			      end
			4'd7: begin r.wr = 1; r.dl_db = 1; r = r | op_rmw(o.rmw); end
			4'd8: begin r.wr = 1; r = r | rmw_out(o.rmw, o.data); end
			default: ;
			endcase

		M_IZY: unique case (n)
			4'd3: begin r = addr_zp();
			            r.zero_add = 1; r.dl_db = 1; r.db_add = 1;
			            r.sums = 1; r.alucin = 1;
			      end
			4'd4: begin r = addr_zp_add() | alu_index(1'b0); end
			4'd5: begin r = addr_dl_add() | alu_fix(sh_store ? 1'b1 : acr_now); end
			4'd6: begin if (sh_store) r = store_sh(o.store, idx_crossed);
			            else begin
			                r = addr_fix_hi();
			                if (o.access == A_WRITE) begin
			                    r.wr = 1; r = r | store_out(o.store);
			                end
			            end
			      end
			4'd7: begin r.wr = 1; r.dl_db = 1; r = r | op_rmw(o.rmw); end
			4'd8: begin r.wr = 1; r = r | rmw_out(o.rmw, o.data); end
			default: ;
			endcase

		M_REL: unique case (n)
			4'd3: begin r = addr_pc();
			            r.dl_db = 1; r.sb_db = 1; r.sb_add = 1;
			            r.pcl_adl = 1; r.adl_add = 1;
			            r.sums = 1;
			      end
			4'd4: begin r = addr_add_pch();

			            r.adl_pcl = 1; r.pch_pch = 1;
			            r.pch_db = 1; r.db_add = 1;
			            if (!br_back) begin r.zero_add = 1; r.alucin = 1; end
			            else            r.sb_add = 1;
			            r.sums = 1;
			      end
			default: ;
			endcase

		M_JAB: unique case (n)
			4'd3: begin r = addr_pc() | alu_fix(1'b0); end
			default: ;
			endcase

		M_IND: unique case (n)
			4'd3: begin r = addr_pc(); r.pcl_pcl = 1; r.pch_pch = 1; r.ipc = 1;
			            r = r | alu_fix(1'b0);
			      end
			4'd4: begin r = addr_dl_add();
			            r.add_sb06 = 1; r.add_sb7 = 1; r.sb_add = 1;
			            r.ndb_add = 1; r.sums = 1; r.alucin = 1;
			      end
			4'd5: begin r.add_adl = 1; r.adl_abl = 1;
			            r = r | alu_fix(1'b0);
			      end
			default: ;
			endcase

		M_PUSH: unique case (n)
			4'd3: begin r = addr_stack(); r.wr = 1; r.s_dec = 1;
			            if (ir[6]) r.ac_db = 1;
			            else begin r.p_db = 1; r.b_out = 1; end
			      end
			default: ;
			endcase

		M_PULL: unique case (n)
			4'd3: begin r = addr_stack(); r.s_inc = 1; end
			4'd4: begin r = addr_stack(); end
			default: ;
			endcase

		M_JSR: unique case (n)
			4'd3: begin r = addr_stack() | alu_fix(1'b0); end
			4'd4: begin r = addr_stack(); r.wr = 1; r.s_dec = 1; r.pch_db = 1; end
			4'd5: begin r = addr_stack(); r.wr = 1; r.s_dec = 1; r.pcl_db = 1; end
			4'd6: begin r = addr_pc(); r.pcl_pcl = 1; r.pch_pch = 1; end
			default: ;
			endcase

		M_RTS: unique case (n)
			4'd3: begin r = addr_stack(); r.s_inc = 1; end
			4'd4: begin r = addr_stack(); r.s_inc = 1; end
			4'd5: begin r = addr_stack() | alu_fix(1'b0); end
			4'd6: begin r = addr_dl_add();
			            r.adl_pcl = 1; r.adh_pch = 1; r.ipc = 1;
			      end
			default: ;
			endcase

		M_RTI: unique case (n)
			4'd3: begin r = addr_stack(); r.s_inc = 1; end
			4'd4: begin r = addr_stack(); r.s_inc = 1; end
			4'd5: begin r = addr_stack(); r.s_inc = 1;

			            r.dl_db = 1; r.db_p = 1; r.db0_c = 1; r.db6_v = 1;
			            r.db7_n = 1;
			      end
			4'd6: begin r = addr_stack() | alu_fix(1'b0); end
			default: ;
			endcase

		M_BRK: unique case (n)
			4'd3: begin r = addr_stack(); r.wr = ~res_active; r.s_dec = 1;
			            r.pch_db = 1;
			      end
			4'd4: begin r = addr_stack(); r.wr = ~res_active; r.s_dec = 1;
			            r.pcl_db = 1;
			      end
			4'd5: begin r = addr_stack(); r.wr = ~res_active; r.s_dec = 1;
			            r.p_db = 1; r.b_out = ~int_active;
			      end
			4'd6: begin r = addr_vector(1'b0); r.one_i = 1; end
			4'd7: begin r = addr_vector(1'b1) | alu_fix(1'b0); end
			default: ;
			endcase

		default: ;
		endcase
		return r;
	endfunction

	logic br_flag;

	always_comb begin
		unique case (ir[7:6])
		2'b00:   br_flag = p[7];
		2'b01:   br_flag = p[6];
		2'b10:   br_flag = p[0];
		default: br_flag = p[1];
		endcase
	end

	assign br_take = (br_flag == ir[5]);

	assign br_fix = dl[7] ^ acr_now;

	assign br_back = dl[7];

	logic hold, wr_q, sync_q, rdy_q;
	wire  rdy_cy = phi1_en ? rdy : rdy_q;
	assign hold = ~rdy_cy & ~wr_q;

	always_ff @(posedge clk_sys) begin
		if (!res_n)      rdy_q <= 1'b1;
		else if (phi1_en) rdy_q <= rdy;
	end

	logic br_back_q;
	logic adh_carry;
	assign adh_carry = ~((d.mode == M_REL) & br_back_q);

	logic sh_write_cycle;
	assign sh_write_cycle = sh_store &&
	                        (((d.mode == M_ABX || d.mode == M_ABY) && t == 4'd5) ||
	                         (d.mode == M_IZY && t == 4'd6));

	function automatic ctl_t hold_mask(input ctl_t x, input logic carry);
		ctl_t r = x;
		r.ipc     = 1'b0;
		r.adl_abl = 1'b0;
		r.wr      = 1'b0;
		r.db_p    = 1'b0;
		r.pcl_db  = 1'b0;
		r.ndb_add = 1'b0;
		r.sb_add  = 1'b0;  r.zero_add = 1'b0;  r.db_add = 1'b0;
		r.adl_add = 1'b0;
		r.sums = 1'b0; r.ands = 1'b0; r.eors = 1'b0; r.ors = 1'b0; r.srs = 1'b0;
		r.alucin = 1'b0;
		r.sb_s    = 1'b0;
		r.s_inc   = 1'b0;
		r.s_dec   = 1'b0;
		r.adh_abh = x.adh_abh & x.sb_adh & carry;
		r.add_ff  = sh_write_cycle;
		return r;
	endfunction

	ctl_t c_pre;
	assign c_pre = hold ? hold_mask(c_reg, adh_carry) : c_reg;

	always_comb begin
		c = c_pre;
		c.so_v = so_edge_q;
		c.wr   = c_pre.wr & ~res_now;
	end

	logic so_edge, so_edge_q;
	assign so_edge = so_last & ~so_n;

	function automatic logic is_last(input logic [3:0] k, input logic crossed,
	                                 input logic taken, input logic pch_fix);
		logic r;
		r = 1'b0;
		if (k != 4'd1) begin
			unique case (d.mode)
			M_IMP, M_ACC, M_IMM: r = (k == 4'd2);
			M_JAM:               r = 1'b0;
			M_ZP:   r = (d.access == A_RMW) ? (k == 4'd5) : (k == 4'd3);
			M_ZPX,
			M_ZPY:  r = (d.access == A_RMW) ? (k == 4'd6) : (k == 4'd4);
			M_ABS:  r = (d.access == A_RMW) ? (k == 4'd6) : (k == 4'd4);
			M_ABX,
			M_ABY:  unique case (d.access)
			        A_READ:  r = (k == 4'd4 && !crossed) || (k == 4'd5);
			        A_WRITE: r = (k == 4'd5);
			        default: r = (k == 4'd7);
			        endcase
			M_IZX:  r = (d.access == A_RMW) ? (k == 4'd8) : (k == 4'd6);
			M_IZY:  unique case (d.access)
			        A_READ:  r = (k == 4'd5 && !crossed) || (k == 4'd6);
			        A_WRITE: r = (k == 4'd6);
			        default: r = (k == 4'd8);
			        endcase
			M_REL:  r = (k == 4'd2 && !taken)
			          | (k == 4'd3 && !pch_fix)
			          | (k == 4'd4);
			M_JAB:  r = (k == 4'd3);
			M_IND:  r = (k == 4'd5);
			M_JSR:  r = (k == 4'd6);
			M_RTS,
			M_RTI:  r = (k == 4'd6);
			M_BRK:  r = (k == 4'd7);
			M_PUSH: r = (k == 4'd3);
			M_PULL: r = (k == 4'd4);
			default: ;
			endcase
		end
		return r;
	endfunction

	logic last;
	assign last = is_last(t, pgx, br_take, br_fix);

	logic [5:0] tg, tg_c2;
	logic       sync_c2;
	logic       ext_t5, ext_t6;

	logic tz_pre_n, t_zero;
	assign tz_pre_n = ~pd_two_cycle;

	logic end_x;

	assign end_x = (t != 4'd1)
	             & ((d.mode == M_REL)
	                ? ((t == 4'd3) & tg[3])
	                : (is_last(t + 4'd1,
	                           (t == 4'd3 || t == 4'd4) ? acr_now : pgx,
	                           br_take, br_fix)
	                   & ~pd_two_cycle));

	logic [3:0] rmw_rd;
	always_comb begin
		unique case (d.mode)
		M_ZP:        rmw_rd = 4'd3;
		M_ZPX, M_ZPY,
		M_ABS:       rmw_rd = 4'd4;
		M_ABX, M_ABY: rmw_rd = 4'd5;
		M_IZX, M_IZY: rmw_rd = 4'd6;
		default:     rmw_rd = 4'd0;
		endcase
	end

	logic ext_t5_r, ext_t6_r;
	assign ext_t5 = hold ? ext_t5_r : ((d.access == A_RMW) && (t == rmw_rd));
	assign ext_t6 = hold ? ext_t6_r : ((d.access == A_RMW) && (t == rmw_rd + 4'd1));

	logic end_x_q;
	assign t_zero = sync | (end_x_q & tg_go) | res_p;

	logic tg_go;
	assign tg_go = ~hold;

	always_comb begin
		tg[0] = ~(sync | (~t_zero & tz_pre_n)) | (tg_c2[0] & ~tg_go);
		tg[1] = tg_c2[0] & tg_go;
		tg[2] = ~t_zero & ((tg_c2[2] & ~tg_go) | (sync_c2  & tg_go));
		tg[3] = ~t_zero & ((tg_c2[3] & ~tg_go) | (tg_c2[2] & tg_go));
		tg[4] = ~t_zero & ((tg_c2[4] & ~tg_go) | (tg_c2[3] & tg_go));
		tg[5] = ~t_zero & ((tg_c2[5] & ~tg_go) | (tg_c2[4] & tg_go));
	end

	assign nt = (last | tg[0]) ? 4'd1
	          : (jammed && t >= 4'd6) ? t : (t + 4'd1);

	always_comb begin
		nc = CTL_IDLE;

		if (nt == 4'd1) begin

			unique case (n_pc_src)
			PC_EA:  begin nc = addr_dl_add(); end
			PC_ADD: begin nc = addr_add_pch(); end
			PC_FIX: begin nc = addr_fix_hi();  end
			default: nc = addr_pc();
			endcase

			if (n_pc_src == PC_FIX) begin
				nc.pcl_pcl = 1; nc.adh_pch = 1;
			end else if (n_pc_src == PC_PC) begin
				nc.pcl_pcl = 1; nc.pch_pch = 1;
			end else begin
				nc.adl_pcl = 1;
				if (n_pc_src == PC_ADD) nc.pch_pch = 1; else nc.adh_pch = 1;
			end

			if (vec_merge) begin
				nc = addr_vector(1'b1);
				nc.dl_adh  = 1'b1;
				nc.adl_pcl = 1'b1;
				nc.adh_pch = 1'b1;
			end
			nc.ipc = ~(n_int_g | n_res_g);
			nc = nc | op_a(d);
		end else if (nt == 4'd2) begin

			nc = addr_pc();
			nc.pcl_pcl = 1; nc.pch_pch = 1;
			nc.ipc = ~pd_implied & ~int_active;
			nc = nc | op_b(d);
		end else begin
			nc = seq(d, nt, idx_cross_q);
		end

		if (jammed) begin
			nc = CTL_IDLE;
			nc.adl_abl = 1'b1;
			nc.adh_abh = 1'b1;

			nc.zero_adl0 = (nt == 4'd4) || (nt == 4'd5);
		end
	end

	logic n_int_g, take_int;

	logic irq_p;
	logic nmi_p;
	logic nmi_l;
	logic nmig, nmig_c2;
	logic vec_n_c2, brk_done_q;

	logic n_res_g;
	assign n_res_g = res_c2 | (res_g & ~brk_done);

	logic res_c2 = 1'b1, res_p = 1'b1;

	logic sync_short, res_no_prefetch;
	assign res_no_prefetch = res_p & ~sync_short;

	logic vec_merge;
	assign vec_merge = tg[0] && (d.mode == M_BRK) && (t == 4'd6);

	logic vec_cyc, brk_done;
	assign vec_cyc  = (d.mode == M_BRK) && (t == 4'd6 || t == 4'd7);
	assign brk_done = (d.mode == M_BRK) && (t == 4'd6) && !hold;

	logic nmi_req;
	assign nmi_req = nmi_p & ~nmi_l & vec_n_c2;
	assign nmig    = nmi_req | (nmig_c2 & ~brk_done_q);

	always_ff @(posedge clk_sys) begin
		if (phi1_en) begin
			irq_p   <= ~irq_n;
			nmi_p   <= ~nmi_n;

			nmi_l   <= ~nmi_n & (nmig_c2 | nmi_l);
			nmig_c2 <= nmig;

			res_c2  <= ~res_n;
			res_g   <= res_c2 | (res_g & ~brk_done_q);

			vec_n_c2 <= ~vec_cyc;
		end
		if (phi2_en) begin
			res_p      <= res_c2;

			sync_short <= (d.mode == M_REL) && (t == 4'd3) && last && tg[3];
			brk_done_q <= brk_done;

			tg_c2   <= tg;
			sync_c2 <= sync;

			if (!hold) begin
				end_x_q  <= end_x;
				ext_t5_r <= ext_t5;
				ext_t6_r <= ext_t6;
			end
		end
	end

	logic int_req, poll_now;
	assign nmi_pending = nmig;
	assign int_req = nmi_pending || (irq_p && !p[2]);

	assign poll_now = (d.mode == M_REL) ? (t == 4'd2 || t == 4'd4) : last;

	assign take_int = last && !int_active && (d.mode != M_BRK)
	                  && (poll_now ? int_req : int_armed);

	always_comb begin
		n_int_g = int_g;
		if (d.mode == M_BRK && t == 4'd7) n_int_g = 1'b0;
		else if (take_int)                n_int_g = 1'b1;
	end

	always_comb begin
		n_pc_src = PC_PC;
		if (last) begin
			unique case (d.mode)
			M_JAB, M_IND, M_BRK, M_JSR, M_RTI: n_pc_src = PC_EA;

			M_REL:        n_pc_src = (t == 4'd2) ? PC_PC :
			                         (t == 4'd3) ? PC_ADD : PC_FIX;
			default:      n_pc_src = PC_PC;
			endcase
		end
	end

	always_ff @(posedge clk_sys) begin

		if (phi2_en) begin

			so_last  <= so_n;
			so_edge_q <= so_edge;

			wr_q <= c.wr;
			if (!hold) sync_q <= (t == 4'd1);

			if (hold) begin
				t     <= t;
				c_reg <= c_reg;

				if (t == 4'd1 && !int_active && int_req) begin
					int_g      <= 1'b1;
					int_armed  <= 1'b0;

					c_reg.ipc <= 1'b0;
				end

				if (sh_write_cycle) c_reg.adh_abh <= 1'b0;
			end else begin
				t     <= nt;
				c_reg <= nc;

				if (d.mode == M_REL && t == 4'd3) br_back_q <= br_back;

				int_g      <= n_int_g;
				if (poll_now) int_armed <= int_req;
				if (take_int) int_armed <= 1'b0;

				if (t == 4'd1) begin
					ir      <= int_active ? 8'h00 : data_in;
					end

				if (t == 4'd3 || t == 4'd4) pgx <= acr_now;

				if ((d.mode == M_ABX || d.mode == M_ABY) && t == 4'd3)
					idx_cross_q <= acr_now;
				if (d.mode == M_IZY && t == 4'd4)
					idx_cross_q <= acr_now;

			end
		end
	end

endmodule

