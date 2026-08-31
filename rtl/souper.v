//------------------------------------------------------------------------------
// souper.v
// Memory Bastard for Atari 7800.
//------------------------------------------------------------------------------
// This mapper provides banking for 512KB of ROM, 32KB of RAM, optional graphic
// enhancement functionality, and an 8-Bit clocked output port.
//------------------------------------------------------------------------------
// Version 1.0, March 30th, 2015
// Copyright (C) 2015 Osman Celimli
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
//------------------------------------------------------------------------------
module souper(
	clk,
	pclk1,
	reset,

	halt_n,
	data,
	rw,

	addr_15,
	addr_14,
	addr_13,
	addr_12,
	addr_11,
	addr_10,
	addr_9,
	addr_8,
	addr_7,
	addr_2,
	addr_1,
	addr_0,

	romSel_n,
	ramSel_n,
	oe_n,
	wr_n,

	mapAddr_7p,

	audCom,
	audReq_n
);

	input			clk;
	input			pclk1;
	input			reset;

	input			halt_n;
	input			rw;

	input[7:0]		data;
	input			addr_15;
	input			addr_14;
	input			addr_13;
	input			addr_12;
	input			addr_11;
	input			addr_10;
	input			addr_9;
	input			addr_8;
	input			addr_7;
	input			addr_2;
	input			addr_1;
	input			addr_0;

	output			romSel_n;
	output			ramSel_n;
	output			oe_n;
	output			wr_n;

	output[11:0]	mapAddr_7p;

	output[7:0]		audCom;
	output			audReq_n;

	reg				haltDelA_ir,
					haltDelB_ir;
	wire			marRead_i;

assign oe_n = ~((rw) | marRead_i);
assign wr_n = ~(~rw);

assign marRead_i = ~halt_n & haltDelB_ir;

always@(posedge clk) begin
	if(reset) begin
		haltDelA_ir <= 1'b0;
		haltDelB_ir <= 1'b0;
	end
	else if (pclk1) begin
		if(~halt_n) begin
			haltDelA_ir <= ~halt_n;
			haltDelB_ir <= haltDelA_ir;
		end
		else begin
			haltDelA_ir <= 1'b0;
			haltDelB_ir <= 1'b0;
		end
	end
end

	reg 			soupMode_ir;

assign romSel_n = (marRead_i & soupMode_ir)
	? ~(addr_15 & ~addr_14)
	: ~(addr_15);
assign ramSel_n = (marRead_i & soupMode_ir)
	? ~(addr_14)
	: ~(~addr_15 & addr_14);

	reg				chrMode_ir;
	reg				exMode_ir;

	reg[4:0]		bankSel_ir;
	reg[7:0]		chrSelA_ir,
					chrSelB_ir;
	reg[2:0]		exSelV_ir,
					exSelD_ir;

always@(posedge clk) begin
	if(reset) begin
		chrMode_ir <= 0;
		exMode_ir <= 0;
		soupMode_ir <= 0;

		chrSelA_ir <= 0;
		chrSelB_ir <= 0;
		exSelV_ir <= 0;
		exSelD_ir <= 0;
		bankSel_ir <= 0;
	end else if (pclk1) begin
		if(addr_15 & ~rw) begin
			case({addr_2, addr_1, addr_0})
				3'd0 : bankSel_ir <= data[4:0];
				3'd1 : chrSelA_ir <= data[7:0];
				3'd2 : chrSelB_ir <= data[7:0];
				3'd3 : begin
					soupMode_ir <= data[0];
					chrMode_ir <= data[1];
					exMode_ir <= data[2];
				end
				3'd4 : exSelV_ir <= data[2:0];
				3'd5 : exSelD_ir <= data[2:0];
			endcase
		end
	end
end

	reg[7:0]		audData_ir;
	reg				audReq_ir;

always@(posedge clk) begin
	if(reset) begin
		audData_ir <= 0;
		audReq_ir <= 1'b1;
	end
	else if (pclk1) begin
		if(addr_15 & ~rw) begin
			if(addr_2 & addr_1 & addr_0) begin
				audData_ir <= data;
				audReq_ir <= ~audReq_ir;
			end
		end
	end
end

assign audCom = audData_ir;

assign audReq_n = audReq_ir;

assign mapAddr_7p = ramSel_n

	? ((marRead_i & chrMode_ir)
		? (addr_13
			? (addr_7
				? {chrSelB_ir[7:1],
					addr_11, addr_10, addr_9, addr_8,
					chrSelB_ir[0]}
				: {chrSelA_ir[7:1],
					addr_11, addr_10, addr_9, addr_8,
					chrSelA_ir[0]})
			: {5'b11111, addr_13, addr_12,
				addr_11, addr_10, addr_9, addr_8,
				addr_7})

		: (addr_14
			? {5'b11111, addr_13, addr_12,
				addr_11, addr_10, addr_9, addr_8,
				addr_7}
			: {bankSel_ir, addr_13, addr_12,
				addr_11, addr_10, addr_9, addr_8,
				addr_7}))

	: ((addr_13 & exMode_ir)
		? (addr_12
			? {4'd0, exSelD_ir,
				addr_11, addr_10, addr_9,
				addr_8, addr_7}
			: {4'd0, exSelV_ir,
				addr_11, addr_10, addr_9,
				addr_8, addr_7})
		: {5'd0,
			addr_13, addr_12,
			addr_11, addr_10, addr_9, addr_8,
			addr_7});
endmodule

