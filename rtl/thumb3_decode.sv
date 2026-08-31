`include "thumb3_defs.vh"

module thumb3_decode
(
	input      [15:0] ir,

	output reg  [5:0] uop,
	output reg  [3:0] rd,
	output reg  [3:0] rn,
	output reg  [3:0] rm,
	output reg [31:0] imm,
	output reg [31:0] b_off,

	output reg        b_imm,
	output reg        a_pc,
	output reg        a_sp,
	output reg        a_zero,

	output reg        a_pcraw,

	output reg        wb,
	output reg  [3:0] set_flag,
	output reg  [1:0] mem_sz,
	output reg        mem_sign,
	output reg  [3:0] cond,
	output reg  [7:0] rlist,
	output reg        rlist_r,
	output reg        blk_load,
	output reg        blk_wb,
	output reg        blk_down,
	output reg        link,
	output reg        shift_reg

);

	wire [2:0] f_rd  = ir[2:0];
	wire [2:0] f_rs  = ir[5:3];
	wire [2:0] f_rn  = ir[8:6];
	wire [4:0] f_of5 = ir[10:6];
	wire [7:0] f_of8 = ir[7:0];

	always @* begin

		uop = `U_UNDEF; rd = 4'd0; rn = 4'd0; rm = 4'd0; imm = 32'd0;
		b_off = 32'd0; a_pcraw = 1'b0;
		b_imm = 1'b0; a_pc = 1'b0; a_sp = 1'b0; a_zero = 1'b0; wb = 1'b0;
		set_flag = `F_NONE; mem_sz = `SZ_WORD; mem_sign = 1'b0;
		cond = 4'hE; rlist = 8'd0; rlist_r = 1'b0;
		blk_load = 1'b0; blk_wb = 1'b0; blk_down = 1'b0; link = 1'b0;
		shift_reg = 1'b0;

		if ((ir & 16'hF000) == 16'hF000) begin

			if (ir[11]) begin

				uop     = `U_BX;
				rn      = `R_LR;
				b_off   = ({21'd0, ir[10:0]} << 1) - 32'd2;
				rd      = `R_LR;
				wb      = 1'b1;
				a_pcraw = 1'b1;
				b_imm   = 1'b1;
				imm     = 32'hFFFFFFFF;
				link    = 1'b1;
			end else begin

				uop     = `U_BLPFX;
				rd      = `R_LR;
				wb      = 1'b1;
				a_pcraw = 1'b1;
				b_imm   = 1'b1;
				imm     = {{9{ir[10]}}, ir[10:0], 12'd0} + 32'd2;
			end
		end else if ((ir & 16'hF000) == 16'hE000) begin

			uop   = `U_BRANCH;
			b_off = {{20{ir[10]}}, ir[10:0], 1'b0};
		end else if ((ir & 16'hFF00) == 16'hDF00) begin

			uop = `U_SWI;
			imm = {24'd0, f_of8};
		end else if ((ir & 16'hF000) == 16'hD000) begin

			uop   = `U_BRANCH;
			cond  = ir[11:8];
			b_off = {{23{ir[7]}}, ir[7:0], 1'b0};
		end else if ((ir & 16'hF000) == 16'hC000) begin

			uop      = `U_BLOCK;
			rn       = {1'b0, ir[10:8]};
			rlist    = f_of8;
			blk_load = ir[11];
			blk_wb   = 1'b1;
		end else if ((ir & 16'hF600) == 16'hB400) begin

			uop      = `U_BLOCK;
			rn       = `R_SP;
			rlist    = f_of8;
			rlist_r  = ir[8];
			blk_load = ir[11];
			blk_wb   = 1'b1;
			blk_down = ~ir[11];
		end else if ((ir & 16'hFF00) == 16'hB000) begin

			uop      = ir[7] ? `U_SUB : `U_ADD;
			rd       = `R_SP;
			rn       = `R_SP;
			imm      = {23'd0, ir[6:0], 2'b00};
			b_imm    = 1'b1;
			wb       = 1'b1;
		end else if ((ir & 16'hF000) == 16'hA000) begin

			uop   = `U_ADD;
			rd    = {1'b0, ir[10:8]};
			a_pc  = ~ir[11];
			a_sp  =  ir[11];
			rn    = `R_SP;
			imm   = {22'd0, f_of8, 2'b00};
			b_imm = 1'b1;
			wb    = 1'b1;
		end else if ((ir & 16'hF000) == 16'h9000) begin

			uop    = ir[11] ? `U_LOAD : `U_STORE;
			rd     = {1'b0, ir[10:8]};
			rn     = `R_SP;
			imm    = {22'd0, f_of8, 2'b00};
			b_imm  = 1'b1;
			mem_sz = `SZ_WORD;
			wb     = ir[11];
		end else if ((ir & 16'hF000) == 16'h8000) begin

			uop    = ir[11] ? `U_LOAD : `U_STORE;
			rd     = {1'b0, f_rd};
			rn     = {1'b0, f_rs};
			imm    = {26'd0, f_of5, 1'b0};
			b_imm  = 1'b1;
			mem_sz = `SZ_HALF;
			wb     = ir[11];
		end else if ((ir & 16'hE000) == 16'h6000) begin

			uop    = ir[11] ? `U_LOAD : `U_STORE;
			rd     = {1'b0, f_rd};
			rn     = {1'b0, f_rs};
			imm    = ir[12] ? {27'd0, f_of5} : {25'd0, f_of5, 2'b00};
			b_imm  = 1'b1;
			mem_sz = ir[12] ? `SZ_BYTE : `SZ_WORD;
			wb     = ir[11];
		end else if ((ir & 16'hF200) == 16'h5200) begin

			rd       = {1'b0, f_rd};
			rn       = {1'b0, f_rs};
			rm       = {1'b0, f_rn};
			mem_sign = ir[10];
			if (~ir[10] & ~ir[11]) begin
				uop    = `U_STORE;
				mem_sz = `SZ_HALF;
			end else begin
				uop    = `U_LOAD;
				wb     = 1'b1;
				mem_sz = (ir[10] & ~ir[11]) ? `SZ_BYTE : `SZ_HALF;
			end
		end else if ((ir & 16'hF200) == 16'h5000) begin

			uop    = ir[11] ? `U_LOAD : `U_STORE;
			rd     = {1'b0, f_rd};
			rn     = {1'b0, f_rs};
			rm     = {1'b0, f_rn};
			mem_sz = ir[10] ? `SZ_BYTE : `SZ_WORD;
			wb     = ir[11];
		end else if ((ir & 16'hF800) == 16'h4800) begin

			uop    = `U_LOAD;
			rd     = {1'b0, ir[10:8]};
			a_pc   = 1'b1;
			imm    = {22'd0, f_of8, 2'b00};
			b_imm  = 1'b1;
			mem_sz = `SZ_WORD;
			wb     = 1'b1;
		end else if ((ir & 16'hFC00) == 16'h4400) begin

			rd = {ir[7], f_rd};
			rm = {ir[6], f_rs};
			rn = {ir[7], f_rd};
			case (ir[9:8])
				2'b00: begin uop = `U_ADD; wb = 1'b1; end
				2'b01: begin uop = `U_CMP; set_flag = `F_NZCV; end
				2'b10: begin uop = `U_MOV; wb = 1'b1; end
				default: begin

					uop  = `U_BX;
					rn   = {ir[6], f_rs};
					link = 1'b0;
				end
			endcase
		end else if ((ir & 16'hFC00) == 16'h4000) begin

			rd = {1'b0, f_rd};
			rn = {1'b0, f_rd};
			rm = {1'b0, f_rs};
			wb = 1'b1;
			case (ir[9:6])
				4'h0: begin uop = `U_AND; set_flag = `F_NZ;   end
				4'h1: begin uop = `U_EOR; set_flag = `F_NZ;   end
				4'h2: begin uop = `U_LSL; set_flag = `F_NZC;  shift_reg = 1'b1; end
				4'h3: begin uop = `U_LSR; set_flag = `F_NZC;  shift_reg = 1'b1; end
				4'h4: begin uop = `U_ASR; set_flag = `F_NZC;  shift_reg = 1'b1; end
				4'h5: begin uop = `U_ADC; set_flag = `F_NZCV; end
				4'h6: begin uop = `U_SBC; set_flag = `F_NZCV; end
				4'h7: begin uop = `U_ROR; set_flag = `F_NZC;  shift_reg = 1'b1; end
				4'h8: begin uop = `U_TST; set_flag = `F_NZ;   wb = 1'b0; end
				4'h9: begin uop = `U_NEG; set_flag = `F_NZCV; a_zero = 1'b1; end
				4'hA: begin uop = `U_CMP; set_flag = `F_NZCV; wb = 1'b0; end
				4'hB: begin uop = `U_CMN; set_flag = `F_NZCV; wb = 1'b0; end
				4'hC: begin uop = `U_ORR; set_flag = `F_NZ;   end
				4'hD: begin uop = `U_MUL; set_flag = `F_NZ;   end
				4'hE: begin uop = `U_BIC; set_flag = `F_NZ;   end
				default: begin uop = `U_MVN; set_flag = `F_NZ; end
			endcase
		end else if ((ir & 16'hE000) == 16'h2000) begin

			rd    = {1'b0, ir[10:8]};
			rn    = {1'b0, ir[10:8]};
			imm   = {24'd0, f_of8};
			b_imm = 1'b1;
			case (ir[12:11])
				2'b00: begin uop = `U_MOV; set_flag = `F_NZ;   wb = 1'b1; end
				2'b01: begin uop = `U_CMP; set_flag = `F_NZCV;            end
				2'b10: begin uop = `U_ADD; set_flag = `F_NZCV; wb = 1'b1; end
				default: begin uop = `U_SUB; set_flag = `F_NZCV; wb = 1'b1; end
			endcase
		end else if ((ir & 16'hF800) == 16'h1800) begin

			rd       = {1'b0, f_rd};
			rn       = {1'b0, f_rs};
			rm       = {1'b0, f_rn};
			imm      = {29'd0, f_rn};
			b_imm    = ir[10];
			uop      = ir[9] ? `U_SUB : `U_ADD;
			set_flag = `F_NZCV;
			wb       = 1'b1;
		end else if ((ir & 16'hE000) == 16'h0000) begin

			rd       = {1'b0, f_rd};
			rn       = {1'b0, f_rs};
			imm      = {27'd0, f_of5};
			b_imm    = 1'b1;
			set_flag = `F_NZC;
			wb       = 1'b1;
			case (ir[12:11])
				2'b00:   uop = `U_LSL;
				2'b01:   uop = `U_LSR;
				default: uop = `U_ASR;
			endcase
		end
	end

endmodule

