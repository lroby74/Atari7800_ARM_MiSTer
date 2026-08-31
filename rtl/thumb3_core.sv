`include "thumb3_defs.vh"

module thumb3_core
#(

	parameter WATCHDOG = 1
)
(
	input             clk,
	input             rst,

	input             start,
	input      [31:0] start_pc,
	input      [31:0] start_sp,
	input      [31:0] start_lr,

	input             start_keep,
	input      [31:0] start_r2,
	input             start_r2_we,
	output            running,
	output            halted,
	output reg [31:0] bx_pc,

	output     [31:0] i_addr,
	output            i_req,
	input             i_ack,
	input      [63:0] i_data,

	output     [31:0] d_addr,
	output            d_req,
	output            d_we,
	output      [1:0] d_sz,
	output            d_blk,

	output     [31:0] d_wdata,
	output      [3:0] d_be,
	input             d_free,

	input             d_gnt,

	input             d_ack,
	input      [31:0] d_rdata,

	input      [31:0] inv_addr,
	input             inv_en,

	output     [31:0] dbg_r0,
	output     [31:0] dbg_r2,
	output     [31:0] dbg_r3,
	output     [31:0] dbg_lr,

	output reg [31:0] dbg_pc,
	output reg        dbg_retire,
	output reg  [3:0] dbg_flags
);

	reg  [31:0] r [0:15];
	reg   [3:0] fl;
	reg         run;
	reg         halt_pend;
	reg         mem_issued;
	reg         mem_done;
	reg  [23:0] wd_cnt;

	reg  [31:0] pc_f, pc_f_d;
	reg         f_v, f_flush;
	reg  [31:0] fill_pc;
	reg         fill_busy;

	reg         fill_kill;
	reg         skid_v;
	reg  [31:0] skid_pc;
	reg  [15:0] skid_ir;

	reg         d_v;
	reg         d_pred;
	reg  [31:0] d_pc;
	reg  [15:0] d_ir;

	reg         e_v;
	reg  [31:0] e_pc, e_a, e_b, e_sdata;
	reg  [31:0] mul_r;
	reg         mul_wait;
	reg   [5:0] e_uop;
	reg   [3:0] e_rd, e_flagmask, e_rbase;
	reg         e_wb, e_shreg, e_link;
	reg   [1:0] e_sz;
	reg         e_sign, e_load, e_store, e_bx, e_blk;
	reg   [7:0] e_rlist;
	reg         e_rlist_r, e_bload, e_bwb, e_bdown;

	reg         m_v, m_wb, m_load, m_sign, m_blk;
	reg         e_early;
	reg         m_lwait;
	reg         m_lq;
	reg   [3:0] m_fl;
	reg  [31:0] m_pc, m_q;
	reg   [3:0] m_rd;
	reg   [1:0] m_sz, m_off;

	reg         blk_busy;
	reg  [31:0] blk_ptr;
	reg  [15:0] blk_mask;
	reg         blk_load, blk_wb;
	reg   [3:0] blk_base;
	reg         blk_pending;
	reg   [3:0] blk_rdest;
	reg         blk_done;
	reg  [31:0] blk_wbval;
	reg         blk_started;
	reg         blk_pcv;
	reg  [31:0] blk_pcnew;
	reg  [31:0] blk_pc;

	wire        stall;
	wire        blk_redir;
	wire [31:0] alu_q, wb_data;
	wire        alu_n, alu_z, alu_c, alu_v;
	wire        ic_hit, ic_valid;
	wire [31:0] ic_data;

	assign running = run;
	assign halted  = ~run;
	assign dbg_r0  = r[0];
	assign dbg_r2  = r[2];
	assign dbg_r3  = r[3];
	assign dbg_lr  = r[`R_LR];

	wire fill_ok = fill_busy && i_ack;
	wire f_ok    = ic_hit && !f_flush;

	wire pc_write = e_v && e_wb && (e_rd == 4'd15) && !e_load;

	wire e_bxarm  = e_v && e_bx && !e_link && !e_a[0];

	wire redirect = blk_redir || redir_now;

	wire miss_now = ic_valid && !ic_hit && !f_flush && !fill_busy && !blk_busy && !redirect;

	wire        adv_f     = !stall_back && !hold_front;

	wire [15:0] f_ir     = pc_f_d[1] ? ic_data[31:16] : ic_data[15:0];
	wire        f_isb2   = (f_ir[15:12] == 4'b1110);
	wire        f_isb1   = (f_ir[15:12] == 4'b1101) && (f_ir[11:8] != 4'hF);
	wire [31:0] f_off    = f_isb2 ? {{20{f_ir[10]}}, f_ir[10:0], 1'b0}
	                              : {{23{f_ir[7]}},  f_ir[7:0],  1'b0};
	wire [31:0] f_targ   = (pc_f_d + 32'd4) + f_off;
	wire [31:0] f_targ_p2 = f_targ + 32'd2;
	wire        redir_now = adv_f && (pc_write || (d_v && (c_taken != d_pred)));
	wire [31:0] pc_fall   = d_pc + 32'd2;
	wire [31:0] pc_redir  = pc_write ? (alu_q & 32'hFFFFFFFE)
	                                 : (c_taken ? c_targ : pc_fall);

	wire        f_pred    = adv_f && f_ok && !skid_v && !redir_now &&
	                        (f_isb2 || (f_isb1 && f_ir[7]));
	wire [31:0] pc_look   = redir_now ? pc_redir : (f_pred ? f_targ : pc_f);

	wire [31:0] pc_f_p2  = pc_f + 32'd2;
	wire [31:0] targ_p2  = c_targ2;
	wire [31:0] pcw_p2   = (alu_q & 32'hFFFFFFFE) + 32'd2;
	wire [31:0] fall_p2  = d_pc + 32'd4;
	wire [31:0] pc_next  = redir_now ? (pc_write ? pcw_p2 :
	                                    (c_taken ? targ_p2 : fall_p2))
	                                 : (f_pred ? f_targ_p2 : pc_f_p2);

	thumb3_icache ic (
		.clk(clk), .rst(rst),
		.pc(pc_look), .lookup(f_v && !stall),
		.valid(ic_valid), .hit(ic_hit), .data(ic_data),
		.fill_pc(fill_pc), .fill_d(i_data), .fill_en(fill_ok),
		.inv_addr(inv_addr), .inv_en(inv_en)
	);

	assign i_addr = {fill_pc[31:3], 3'b000};
	assign i_req  = fill_busy;

	wire [15:0] i_h0 = i_data[15:0];
	wire [15:0] i_h1 = i_data[31:16];
	wire [15:0] i_h2 = i_data[47:32];
	wire [15:0] i_h3 = i_data[63:48];

	reg  [15:0] i_sel, i_nxt;
	always @* begin
		case (pc_f[2:1])
			2'd0:    begin i_sel = i_h0; i_nxt = i_h1; end
			2'd1:    begin i_sel = i_h1; i_nxt = i_h2; end
			2'd2:    begin i_sel = i_h2; i_nxt = i_h3; end
			default: begin i_sel = i_h3; i_nxt = i_h3; end
		endcase
	end

	wire  [5:0] n_uop;
	wire  [3:0] n_rd, n_rn, n_rm, n_cond, n_flag;
	wire [31:0] n_imm;
	wire        n_bimm, n_apc, n_asp, n_azero, n_wb, n_sign, n_apcraw;
	wire [31:0] n_boff;
	wire        n_rlist_r, n_bload, n_bwb, n_bdown, n_link, n_shreg;
	wire  [1:0] n_sz;
	wire  [7:0] n_rlist;

	wire        take_fill = fill_ok && !d_v && !fill_kill && !blk_redir;
	wire [15:0] dec_ir    = take_fill ? i_sel :
	                        skid_v    ? skid_ir :
	                        (pc_f_d[1] ? ic_data[31:16] : ic_data[15:0]);

	thumb3_decode dec (
		.ir(dec_ir), .uop(n_uop), .rd(n_rd), .rn(n_rn), .rm(n_rm), .imm(n_imm),
		.b_imm(n_bimm), .a_pc(n_apc), .a_sp(n_asp), .a_zero(n_azero),
		.a_pcraw(n_apcraw), .b_off(n_boff),
		.wb(n_wb), .set_flag(n_flag), .mem_sz(n_sz), .mem_sign(n_sign),
		.cond(n_cond), .rlist(n_rlist), .rlist_r(n_rlist_r),
		.blk_load(n_bload), .blk_wb(n_bwb), .blk_down(n_bdown),
		.link(n_link), .shift_reg(n_shreg)
	);

	reg   [5:0] c_uop;
	reg   [3:0] c_rd, c_rn, c_rm, c_cond, c_flag;
	reg  [31:0] c_imm;
	reg         c_bimm, c_apc, c_asp, c_azero, c_wb, c_sign, c_apcraw;
	reg  [31:0] c_boff;
	reg         c_rlist_r, c_bload, c_bwb, c_bdown, c_link, c_shreg;
	reg   [1:0] c_sz;
	reg   [7:0] c_rlist;

	wire c_isload  = (c_uop == `U_LOAD);
	wire c_isstore = (c_uop == `U_STORE);
	wire c_isblk   = (c_uop == `U_BLOCK);
	wire c_isbr    = (c_uop == `U_BRANCH);
	wire c_isbx    = (c_uop == `U_BX);

	wire [31:0] pc_arch = d_pc + 32'd4;

	wire [1:0]  ef_off = addr_e[1:0];
	reg  [31:0] mem_data_e;
	always @* begin
		case (e_sz)
			`SZ_BYTE: begin
				case (ef_off)
					2'd0: mem_data_e = e_sign ? {{24{d_rdata[7]}},  d_rdata[7:0]}   : {24'd0, d_rdata[7:0]};
					2'd1: mem_data_e = e_sign ? {{24{d_rdata[15]}}, d_rdata[15:8]}  : {24'd0, d_rdata[15:8]};
					2'd2: mem_data_e = e_sign ? {{24{d_rdata[23]}}, d_rdata[23:16]} : {24'd0, d_rdata[23:16]};
					default: mem_data_e = e_sign ? {{24{d_rdata[31]}}, d_rdata[31:24]} : {24'd0, d_rdata[31:24]};
				endcase
			end
			`SZ_HALF: begin
				if (ef_off[1]) mem_data_e = e_sign ? {{16{d_rdata[31]}}, d_rdata[31:16]} : {16'd0, d_rdata[31:16]};
				else           mem_data_e = e_sign ? {{16{d_rdata[15]}}, d_rdata[15:0]}  : {16'd0, d_rdata[15:0]};
			end
			default: begin
				case (ef_off)
					2'd0: mem_data_e = d_rdata;
					2'd1: mem_data_e = {d_rdata[7:0],  d_rdata[31:8]};
					2'd2: mem_data_e = {d_rdata[15:0], d_rdata[31:16]};
					default: mem_data_e = {d_rdata[23:0], d_rdata[31:24]};
				endcase
			end
		endcase
	end

	wire ef_ok = e_v && e_wb && e_load && !e_blk && !blk_busy && d_ack &&
	             (mem_issued || e_early);

	function [31:0] rdreg;
		input [3:0] i;
		begin
			if (i == 4'd15)                                rdreg = pc_arch;
			else if (e_v && e_wb && e_rd == i && !e_load)   rdreg = alu_q;
			else if (ef_ok && e_rd == i)                    rdreg = mem_data_e;
			else if (m_v && m_wb && m_rd == i)              rdreg = wb_data;
			else                                            rdreg = r[i];
		end
	endfunction

	function [31:0] rdreg_br;
		input [3:0] i;
		begin
			if (i == 4'd15)                                rdreg_br = pc_arch;
			else if (e_v && e_wb && e_rd == i && !e_load)  rdreg_br = alu_q;
			else                                           rdreg_br = r[i];
		end
	endfunction
	wire [31:0] v_rn_br = rdreg_br(c_rn);
	wire [31:0] v_rn = rdreg(c_rn);
	wire [31:0] v_rm = rdreg(c_rm);
	wire [31:0] v_rd = rdreg(c_rd);
	wire [31:0] v_sp = rdreg(`R_SP);

	wire [31:0] op_a = c_azero  ? 32'd0 :
	                   c_apcraw ? pc_arch :
	                   c_apc    ? (pc_arch & 32'hFFFFFFFC) :
	                   c_asp    ? v_sp : v_rn;
	wire [31:0] op_b = c_bimm  ? c_imm : v_rm;

	wire [31:0] targ_br = pc_arch + c_boff;
	wire [31:0] targ_bx = c_link ? (v_rn_br + c_boff) : (v_rn_br & 32'hFFFFFFFE);
	wire [31:0] c_targ  = c_isbr ? targ_br : targ_bx;

	wire [31:0] c_boff2   = c_boff + 32'd2;
	wire [31:0] targ_br2  = pc_arch + c_boff2;
	wire [31:0] targ_bx2  = c_link ? (v_rn_br + c_boff2)
	                               : ((v_rn_br & 32'hFFFFFFFE) + 32'd2);
	wire [31:0] c_targ2   = c_isbr ? targ_br2 : targ_bx2;

	wire [3:0] fl_now = {(e_v && e_flagmask[3]) ? alu_n : fl[3],
	                     (e_v && e_flagmask[2]) ? alu_z : fl[2],
	                     (e_v && e_flagmask[1]) ? alu_c : fl[1],
	                     (e_v && e_flagmask[0]) ? alu_v : fl[0]};

	reg cond_ok;
	always @* begin
		case (c_cond)
			4'h0: cond_ok =  fl_now[2];
			4'h1: cond_ok = ~fl_now[2];
			4'h2: cond_ok =  fl_now[1];
			4'h3: cond_ok = ~fl_now[1];
			4'h4: cond_ok =  fl_now[3];
			4'h5: cond_ok = ~fl_now[3];
			4'h6: cond_ok =  fl_now[0];
			4'h7: cond_ok = ~fl_now[0];
			4'h8: cond_ok =  fl_now[1] & ~fl_now[2];
			4'h9: cond_ok = ~fl_now[1] |  fl_now[2];
			4'hA: cond_ok = (fl_now[3] == fl_now[0]);
			4'hB: cond_ok = (fl_now[3] != fl_now[0]);
			4'hC: cond_ok = ~fl_now[2] & (fl_now[3] == fl_now[0]);
			4'hD: cond_ok =  fl_now[2] | (fl_now[3] != fl_now[0]);
			default: cond_ok = 1'b1;
		endcase
	end

	wire c_taken = (c_isbr && cond_ok) || (c_isbx && (c_link || v_rn_br[0]));

	function conflitto;
		input [3:0] i;
		begin
			conflitto = (i == 4'd15) ||
			            (e_v && e_wb && (e_rd == i)) ||
			            (m_v && m_wb && (m_rd == i));
		end
	endfunction

	wire [31:0] a_src   = c_azero  ? 32'd0 :
	                      c_apcraw ? pc_arch :
	                      c_apc    ? (pc_arch & 32'hFFFFFFFC) : r[c_rn];
	wire [31:0] b_src   = c_bimm ? c_imm : r[c_rm];
	wire [31:0] addr_d  = a_src + b_src;
	wire        a_reg   = !(c_azero || c_apcraw || c_apc);
	wire        ind_ok  = (!a_reg  || !conflitto(c_rn)) &&
	                      (c_bimm  || !conflitto(c_rm));

	thumb3_alu alu (
		.uop(e_uop), .a(e_a), .b(e_b), .c_in(fl[1]), .shift_reg(e_shreg),
		.mul_in(mul_r),
		.q(alu_q), .n_out(alu_n), .z_out(alu_z), .c_out(alu_c), .v_out(alu_v)
	);

	reg [31:0] d_rdata_q;
	always @(posedge clk) if (d_ack) d_rdata_q <= d_rdata;

	wire [31:0] m_word = m_lq ? d_rdata_q : d_rdata;
	reg [31:0] mem_data;
	always @* begin
		case (m_sz)
			`SZ_BYTE: begin
				case (m_off)
					2'd0: mem_data = m_sign ? {{24{m_word[7]}},  m_word[7:0]}   : {24'd0, m_word[7:0]};
					2'd1: mem_data = m_sign ? {{24{m_word[15]}}, m_word[15:8]}  : {24'd0, m_word[15:8]};
					2'd2: mem_data = m_sign ? {{24{m_word[23]}}, m_word[23:16]} : {24'd0, m_word[23:16]};
					default: mem_data = m_sign ? {{24{m_word[31]}}, m_word[31:24]} : {24'd0, m_word[31:24]};
				endcase
			end
			`SZ_HALF: begin
				if (m_off[1]) mem_data = m_sign ? {{16{m_word[31]}}, m_word[31:16]} : {16'd0, m_word[31:16]};
				else          mem_data = m_sign ? {{16{m_word[15]}}, m_word[15:0]}  : {16'd0, m_word[15:0]};
			end
			default: begin

				case (m_off)
					2'd0: mem_data = m_word;
					2'd1: mem_data = {m_word[7:0],  m_word[31:8]};
					2'd2: mem_data = {m_word[15:0], m_word[31:16]};
					default: mem_data = {m_word[23:0], m_word[31:24]};
				endcase
			end
		endcase
	end

	assign wb_data = m_load ? mem_data : m_q;

	wire rd_rn  = c_isbx || c_asp || !(c_azero || c_apcraw || c_apc);
	wire rd_rm  = !c_bimm;
	wire uses_e = (rd_rn && (c_rn == e_rd)) || (rd_rm && (c_rm == e_rd)) ||
	              ((c_isstore || c_isblk) && c_rd == e_rd);
	wire stall_load = d_v && e_v && e_load && e_wb && uses_e && !ef_ok;
	wire stall_fill = fill_busy;

	wire mem_pend   = e_v && (e_load || e_store) && !mem_issued && !e_early;

	wire m_hold     = m_lwait && !d_ack;
	wire stall_mem  = (mem_pend && !d_free) || (blk_pending && !d_ack) || m_hold;

	wire mem_go     = mem_pend;

	wire is_mul    = e_v && (e_uop == `U_MUL);
	wire stall_mul = is_mul && !mul_wait;

	wire blk_start = e_v && e_blk && !blk_busy && !blk_started;

	wire        blk_pcnow = blk_pending && d_ack && blk_load && (blk_rdest == 4'd15);
	wire        blk_pcany = blk_pcv || blk_pcnow;
	wire [31:0] blk_pcval = blk_pcnow ? (d_rdata & 32'hFFFFFFFE) : blk_pcnew;
	wire        blk_fin   = blk_busy && !d_gnt && (!blk_pending || d_ack) && !(|blk_mask);
	assign blk_redir = blk_fin && blk_pcany;

	wire stall_bx   = d_v && c_isbx && m_v && m_wb && (m_rd == c_rn) &&
	                  (c_rn != 4'd15);
	wire hold_front = stall_load || stall_bx;
	wire stall_back = stall_fill || stall_mem || blk_busy || blk_start || stall_mul;

	assign stall = hold_front || stall_back;

	wire [31:0] addr_e = alu_q;

	wire stall_altro = stall_fill || m_lwait || blk_start || blk_pending;
	wire early_go   = d_v && c_isload && !c_isblk && ind_ok &&
	                  !(d_v && e_v && e_load && e_wb && uses_e) &&
	                  !pc_write && !blk_redir && !blk_busy &&
	                  !mem_pend && !stall_mul && !stall_altro;
	wire [31:0] addr   = blk_busy ? blk_ptr : (early_go ? addr_d : addr_e);

	reg [3:0] blk_next;
	always @* begin
		blk_next = 4'd15;
		if      (blk_mask[0])  blk_next = 4'd0;
		else if (blk_mask[1])  blk_next = 4'd1;
		else if (blk_mask[2])  blk_next = 4'd2;
		else if (blk_mask[3])  blk_next = 4'd3;
		else if (blk_mask[4])  blk_next = 4'd4;
		else if (blk_mask[5])  blk_next = 4'd5;
		else if (blk_mask[6])  blk_next = 4'd6;
		else if (blk_mask[7])  blk_next = 4'd7;
		else if (blk_mask[14]) blk_next = 4'd14;
		else if (blk_mask[15]) blk_next = 4'd15;
	end

	wire [31:0] blk_wdata = r[blk_next];

	wire [4:0] blk_n = {4'd0, e_rlist[0]} + {4'd0, e_rlist[1]} +
	                   {4'd0, e_rlist[2]} + {4'd0, e_rlist[3]} +
	                   {4'd0, e_rlist[4]} + {4'd0, e_rlist[5]} +
	                   {4'd0, e_rlist[6]} + {4'd0, e_rlist[7]} +
	                   {4'd0, e_rlist_r};

	assign d_addr  = {addr[31:2], 2'b00};
	assign d_req   = blk_busy ? ((|blk_mask) && !blk_pending)
	                         : (mem_go || early_go);
	assign d_we    = blk_busy ? ~blk_load   : (!early_go && e_v && e_store);
	assign d_sz    = blk_busy ? `SZ_WORD    : (early_go ? c_sz : e_sz);
	assign d_blk   = blk_busy;
	assign d_wdata = blk_busy ? blk_wdata :
	                 (e_sz == `SZ_BYTE) ? {4{e_sdata[7:0]}} :
	                 (e_sz == `SZ_HALF) ? {2{e_sdata[15:0]}} : e_sdata;
	assign d_be    = (blk_busy || early_go) ? 4'b1111 :
	                 (e_sz == `SZ_BYTE) ? (4'b0001 << addr_e[1:0]) :
	                 (e_sz == `SZ_HALF) ? (addr_e[1] ? 4'b1100 : 4'b0011) : 4'b1111;

	integer k;
	always @(posedge clk) begin
		if (rst) begin
			run <= 1'b0; f_v <= 1'b0; f_flush <= 1'b0; skid_v <= 1'b0;
			halt_pend <= 1'b0; mem_done <= 1'b0; wd_cnt <= 24'd0;
			mem_issued <= 1'b0; bx_pc <= 32'd0;
			mem_issued <= 1'b0;
			d_v <= 1'b0; d_pred <= 1'b0; e_v <= 1'b0; m_v <= 1'b0; m_blk <= 1'b0;
			m_lwait <= 1'b0; m_lq <= 1'b0; e_early <= 1'b0;
			fill_busy <= 1'b0; fill_kill <= 1'b0; blk_busy <= 1'b0; blk_pending <= 1'b0;
			blk_done <= 1'b0; blk_started <= 1'b0; blk_pcv <= 1'b0; mul_wait <= 1'b0;
			dbg_retire <= 1'b0; fl <= 4'd0;
			for (k = 0; k < 16; k = k + 1) r[k] <= 32'd0;
		end else if (start) begin
			run       <= 1'b1;
			halt_pend <= 1'b0; mem_done <= 1'b0; wd_cnt <= 24'd0;
			pc_f      <= start_pc;
			pc_f_d    <= start_pc;

			f_v       <= 1'b1; f_flush <= 1'b1; skid_v <= 1'b0;
			dbg_retire <= 1'b0;
			d_v       <= 1'b0; d_pred <= 1'b0; e_v <= 1'b0; m_v <= 1'b0; m_blk <= 1'b0;
			m_lwait   <= 1'b0; m_lq <= 1'b0; e_early <= 1'b0;
			fill_busy <= 1'b0; fill_kill <= 1'b0; blk_busy <= 1'b0; blk_pending <= 1'b0;
			blk_done  <= 1'b0; blk_started <= 1'b0; blk_pcv <= 1'b0; mul_wait <= 1'b0;
			if (!start_keep) begin
				r[13] <= start_sp;
				r[14] <= start_lr;
			end
			if (start_r2_we) r[2] <= start_r2;
		end else if (run) begin

			if (halt_pend) begin
				run       <= 1'b0;
				halt_pend <= 1'b0;
			end else if (e_bxarm && !stall_back) begin
				halt_pend <= 1'b1;
				bx_pc     <= e_pc + 32'd4;
			end
			wd_cnt <= wd_cnt + 1'b1;
			if (WATCHDOG && (&wd_cnt)) run <= 1'b0;

			mul_r <= e_a * e_b;
			if (stall_mul)        mul_wait <= 1'b1;
			else if (!stall_back) mul_wait <= 1'b0;

			if (m_v && m_wb && !m_hold) r[m_rd] <= wb_data;
			if (!m_hold) begin
				m_v     <= 1'b0;
				m_lwait <= 1'b0;
				m_lq    <= 1'b0;
			end

			dbg_retire <= (m_v && !m_blk && !m_hold) || blk_done;
			dbg_pc     <= blk_done ? blk_pc : m_pc;
			dbg_flags  <= blk_done ? fl : m_fl;
			blk_done   <= 1'b0;

			if (blk_start) begin
				blk_busy    <= 1'b1;
				blk_started <= 1'b1;
				blk_pending <= 1'b0;
				blk_pc      <= e_pc;
				blk_load    <= e_bload;
				blk_wb      <= e_bwb;
				blk_base    <= e_rbase;
				blk_mask    <= {e_rlist_r & e_bload, e_rlist_r & ~e_bload,
				                6'd0, e_rlist};
				blk_ptr     <= e_bdown ? (e_a - {25'd0, blk_n, 2'b00}) : e_a;

				blk_wbval   <= e_bdown ? (e_a - {25'd0, blk_n, 2'b00})
				                       : (e_a + {25'd0, blk_n, 2'b00});
			end

			if (blk_busy) begin

				if (blk_pending && d_ack) begin
					if (blk_load) r[blk_rdest] <= d_rdata;
					if (blk_load && blk_rdest == 4'd15) begin
						blk_pcv   <= 1'b1;
						blk_pcnew <= d_rdata & 32'hFFFFFFFE;
					end
					blk_pending <= 1'b0;
				end

				if (d_gnt) begin
					blk_rdest   <= blk_next;
					blk_mask    <= blk_mask & ~(16'd1 << blk_next);
					blk_ptr     <= blk_ptr + 32'd4;
					blk_pending <= 1'b1;
				end

				if (!d_gnt && (!blk_pending || d_ack)) begin
					if (|blk_mask) begin
					end else begin
						if (blk_wb) r[blk_base] <= blk_wbval;
						blk_busy <= 1'b0;
						blk_done <= 1'b1;

						if (blk_pcany) begin
							blk_pcv <= 1'b0;
							pc_f    <= blk_pcval;

							if (fill_busy) fill_kill <= 1'b1;
							f_flush <= 1'b1;
							d_v     <= 1'b0;
							skid_v  <= 1'b0;
						end
					end
				end
			end

			if (d_gnt && !blk_busy && !early_go) mem_issued <= 1'b1;
			if (d_ack && (mem_issued || e_early) && !blk_busy) mem_done <= 1'b1;
			if (!stall_back) begin
				mem_done   <= 1'b0;
				mem_issued <= 1'b0;

				m_v    <= e_v;
				e_early <= !hold_front && d_v && !pc_write && early_go && d_gnt;
				m_lwait <= e_v && e_load && !e_blk && !(mem_done || (d_ack && (mem_issued || e_early) && !blk_busy));
				m_lq    <= e_v && e_load && !e_blk &&  (mem_done || (d_ack && (mem_issued || e_early) && !blk_busy));
				m_blk  <= e_blk;
				m_pc   <= e_pc;
				m_rd   <= e_rd;
				m_q    <= alu_q;
				m_wb   <= e_wb;
				m_load <= e_load;
				m_sz   <= e_sz;
				m_sign <= e_sign;
				m_off  <= addr_e[1:0];
				m_fl   <= {e_flagmask[3] ? alu_n : fl[3],
				           e_flagmask[2] ? alu_z : fl[2],
				           e_flagmask[1] ? alu_c : fl[1],
				           e_flagmask[0] ? alu_v : fl[0]};

				if (e_v) begin
					if (e_flagmask[3]) fl[3] <= alu_n;
					if (e_flagmask[2]) fl[2] <= alu_z;
					if (e_flagmask[1]) fl[1] <= alu_c;
					if (e_flagmask[0]) fl[0] <= alu_v;
				end

				blk_started <= 1'b0;

				e_v        <= !hold_front && d_v && !pc_write;
				e_pc       <= d_pc;
				e_uop      <= c_uop;
				e_rd       <= c_rd;
				e_rbase    <= c_rn;
				e_flagmask <= c_flag;
				e_a        <= op_a;
				e_b        <= op_b;
				e_sdata    <= v_rd;
				e_wb       <= c_wb;
				e_shreg    <= c_shreg;
				e_link     <= c_link;
				e_sz       <= c_sz;
				e_sign     <= c_sign;
				e_load     <= c_isload;
				e_store    <= c_isstore;
				e_bx       <= c_isbx;
				e_blk      <= c_isblk;
				e_rlist    <= c_rlist;
				e_rlist_r  <= c_rlist_r;
				e_bload    <= c_bload;
				e_bwb      <= c_bwb;
				e_bdown    <= c_bdown;

				if (!hold_front) begin

				if (skid_v) begin
					d_v    <= 1'b1;
					d_pred <= 1'b0;
					d_pc   <= skid_pc;
					d_ir   <= skid_ir;
					c_uop <= n_uop; c_rd <= n_rd; c_rn <= n_rn; c_rm <= n_rm;
					c_imm <= n_imm; c_bimm <= n_bimm; c_apc <= n_apc;
					c_asp <= n_asp; c_azero <= n_azero; c_apcraw <= n_apcraw;
					c_boff <= n_boff; c_wb <= n_wb; c_flag <= n_flag;
					c_sz <= n_sz; c_sign <= n_sign; c_cond <= n_cond;
					c_rlist <= n_rlist; c_rlist_r <= n_rlist_r;
					c_bload <= n_bload; c_bwb <= n_bwb; c_bdown <= n_bdown;
					c_link <= n_link; c_shreg <= n_shreg;
					skid_v <= 1'b0;
				end else begin
					d_v  <= f_ok;
					d_pred <= f_pred;
					d_pc <= pc_f_d;
					d_ir <= pc_f_d[1] ? ic_data[31:16] : ic_data[15:0];
					c_uop <= n_uop; c_rd <= n_rd; c_rn <= n_rn; c_rm <= n_rm;
					c_imm <= n_imm; c_bimm <= n_bimm; c_apc <= n_apc;
					c_asp <= n_asp; c_azero <= n_azero; c_apcraw <= n_apcraw;
					c_boff <= n_boff; c_wb <= n_wb; c_flag <= n_flag;
					c_sz <= n_sz; c_sign <= n_sign; c_cond <= n_cond;
					c_rlist <= n_rlist; c_rlist_r <= n_rlist_r;
					c_bload <= n_bload; c_bwb <= n_bwb; c_bdown <= n_bdown;
					c_link <= n_link; c_shreg <= n_shreg;
				end

				pc_f_d  <= pc_look;
				pc_f    <= pc_next;
				f_flush <= 1'b0;

				if (redir_now) begin
					d_v    <= 1'b0;
					d_pred <= 1'b0;
					skid_v <= 1'b0;
				end
				end
			end

			if (stall && f_ok && !skid_v && !blk_redir) begin
				skid_v  <= 1'b1;
				skid_pc <= pc_f_d;
				skid_ir <= pc_f_d[1] ? ic_data[31:16] : ic_data[15:0];
			end

			if (miss_now) begin
				fill_busy <= 1'b1;
				fill_kill <= 1'b0;
				fill_pc   <= {pc_f_d[31:2], 2'b00};
				pc_f      <= pc_f_d;
				f_flush   <= 1'b1;
			end
			if (fill_ok) begin
				fill_busy <= 1'b0;
				fill_kill <= 1'b0;
				f_flush   <= 1'b0;

				if (!d_v && !fill_kill && !blk_redir) begin
					d_v  <= 1'b1;
					d_pred <= 1'b0;
					d_pc <= pc_f;
					d_ir <= i_sel;
					c_uop <= n_uop; c_rd <= n_rd; c_rn <= n_rn; c_rm <= n_rm;
					c_imm <= n_imm; c_bimm <= n_bimm; c_apc <= n_apc;
					c_asp <= n_asp; c_azero <= n_azero; c_apcraw <= n_apcraw;
					c_boff <= n_boff; c_wb <= n_wb; c_flag <= n_flag;
					c_sz <= n_sz; c_sign <= n_sign; c_cond <= n_cond;
					c_rlist <= n_rlist; c_rlist_r <= n_rlist_r;
					c_bload <= n_bload; c_bwb <= n_bwb; c_bdown <= n_bdown;
					c_link <= n_link; c_shreg <= n_shreg;
					if (pc_f[2:1] != 2'b11) begin
						skid_v  <= 1'b1;
						skid_pc <= pc_f + 32'd2;
						skid_ir <= i_nxt;
						pc_f    <= pc_f + 32'd4;
					end else begin
						pc_f    <= pc_f + 32'd2;
					end
				end
			end
		end
	end

endmodule

