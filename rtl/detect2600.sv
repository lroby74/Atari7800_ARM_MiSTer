typedef enum bit[4:0] {
	BANK00, BANKF8, BANKF6, BANKFE, BANKE0, BANK3F, BANKF4, BANKP2,
	BANKFA, BANKCV, BANK2K, BANKUA, BANKE7, BANKF0, BANK32, BANKAR,
	BANK3E, BANKSB, BANKWD, BANKEF, BANKJANE, BANKDPCP, BANKCTY, BANKCDF,
	BANKFA2, BANKEND
} bss_type ;

module detect2600
(
	input clk,
	input reset,
	input [24:0] addr,
	input enable,
	input [31:0] cart_size,
	input [7:0] data,
	output reg [4:0] force_bs,
	output reg sc,
	output [1:0] cdf_family,
	output quadtari
);

wire hasMatch3F;

wire hasMatchEF_0 , hasMatchEF_1, hasMatchEF_2,hasMatchEF_3;
wire hasMatchEF = hasMatchEF_0 | hasMatchEF_1| hasMatchEF_2 | hasMatchEF_3;

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h0C, 8'hE0 , 8'hFF }),
	.needmatches(8'd1)
	) match_bytes_EF_0(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchEF_0)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hE0 , 8'hFF }),
	.needmatches(8'd1)
	) match_bytes_EF_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchEF_1)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h0C, 8'hE0 , 8'h1F }),
	.needmatches(8'd1)
	) match_bytes_EF_2(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchEF_2)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hE0 , 8'h1F }),
	.needmatches(8'd1)
	) match_bytes_EF_3(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchEF_3)
);

wire hasMatchDPCP;
match_bytes #(
	.num_bytes(8'd4),
	.pattern({ 8'h44, 8'h50 , 8'h43, 8'h2B }),
	.needmatches(8'd2)
	) match_bytes_DPCP(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchDPCP)
);

wire hasMatchCTY;
match_bytes #(
	.num_bytes(8'd5),
	.pattern({ 8'h4C, 8'h45 , 8'h4E, 8'h49, 8'h4E }),
	.needmatches(8'd1)
	) match_bytes_CTY(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchCTY)
);

wire  hasMatchCDF_1,hasMatchCDF_2,hasMatchCDF_J;
wire hasMatchCDF =  hasMatchCDF_1  | hasMatchCDF_2 | hasMatchCDF_J;

wire hasMatchQT_champ, hasMatchQT_plain;
assign quadtari = hasMatchQT_champ | hasMatchQT_plain;

match_bytes #(
	.num_bytes(8'd8),
	.pattern({ 8'h1B, 8'h1F, 8'h0B, 8'h0E, 8'h1E, 8'h0B, 8'h1C, 8'h13 }),
	.needmatches(8'd1)
	) match_bytes_QT_champ(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchQT_champ)
);

match_bytes #(
	.num_bytes(8'd8),
	.pattern({ 8'h51, 8'h55, 8'h41, 8'h44, 8'h54, 8'h41, 8'h52, 8'h49 }),
	.needmatches(8'd1)
	) match_bytes_QT_plain(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchQT_plain)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h43, 8'h44 , 8'h46 }),
	.needmatches(8'd3)
	) match_bytes_CDF_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchCDF_1)
);
match_bytes #(
	.num_bytes(8'd8),
	.pattern({ 8'h50, 8'h4C , 8'h55, 8'h53, 8'h43, 8'h44, 8'h46, 8'h4A }),
	.needmatches(8'd1)
	) match_bytes_CDF_2(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchCDF_2)
);
match_bytes #(
	.num_bytes(8'd4),
	.pattern({ 8'h43, 8'h44 , 8'h46, 8'h4A }),
	.needmatches(8'd1)
	) match_bytes_CDF_J(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchCDF_J)
);

reg [1:0] cdf_family_r;
always @(posedge clk) begin
	if (hasMatchCDF_2)      cdf_family_r <= 2'b10;
	else if (hasMatchCDF_J) cdf_family_r <= 2'b01;
	else                    cdf_family_r <= 2'b00;
	if (reset) cdf_family_r <= 2'b00;
end

match_bytes #(
	.num_bytes(8'd2),
	.pattern({ 8'h85, 8'h3F }),
	.needmatches(8'd2)
	) match_bytes_3F(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatch3F)
);

wire hasMatch3E_1;
wire hasMatch3E = hasMatch3E_1 & hasMatch3F;
match_bytes #(
	.num_bytes(8'd2),
	.pattern({ 8'h85, 8'h3E }),
	.needmatches(8'd1)
	) match_bytes_3E_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatch3E_1)
);

wire hasMatchWD;
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hA5,8'h39, 8'h4C }),
	.needmatches(8'd1)
	) match_bytes_WD_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchWD)
);

wire hasMatchSB_1,hasMatchSB_2;
wire hasMatchSB = hasMatchSB_1 |  hasMatchSB_2;
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hBD,8'h00, 8'h08 }),
	.needmatches(8'd1)
	) match_bytes_SB_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchSB_1)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD,8'h00, 8'h08 }),
	.needmatches(8'd1)
	) match_bytes_SB_2(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchSB_2)
);

wire hasMatchE7_0 , hasMatchE7_1 , hasMatchE7_2 , hasMatchE7_3 , hasMatchE7_4 , hasMatchE7_5 , hasMatchE7_6;
wire hasMatchE7 = hasMatchE7_0 | hasMatchE7_1 | hasMatchE7_2 | hasMatchE7_3 | hasMatchE7_4 | hasMatchE7_5 | hasMatchE7_6;
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hE2 , 8'hFF }),
	.needmatches(8'd1)
	) match_bytes_E7_0(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE7_0)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hE5 , 8'hFF }),
	.needmatches(8'd1)
	) match_bytes_E7_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE7_1)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hE5 , 8'h1F }),
	.needmatches(8'd1)
	) match_bytes_E7_2(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE7_2)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hE7 , 8'h1F }),
	.needmatches(8'd1)
	) match_bytes_E7_3(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE7_3)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h0C, 8'hE7 , 8'h1F }),
	.needmatches(8'd1)
	) match_bytes_E7_4(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE7_4)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h8D, 8'hE7 , 8'hFF }),
	.needmatches(8'd1)
	) match_bytes_E7_5(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE7_5)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hE7 , 8'h1F }),
	.needmatches(8'd1)
	) match_bytes_E7_6(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE7_6)
);

wire hasMatchJANE;
match_bytes #(
	.num_bytes(8'd4),
	.pattern({ 8'hAD, 8'hF1 , 8'hFF, 8'h60 }),
	.needmatches(8'd1)
	) match_bytes_JANE(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchJANE)
);

wire  hasMatchE0_0 , hasMatchE0_1 , hasMatchE0_2 , hasMatchE0_3 , hasMatchE0_4 , hasMatchE0_5 , hasMatchE0_6 , hasMatchE0_7;
wire hasMatchE0 = hasMatchE0_0 | hasMatchE0_1 | hasMatchE0_2 | hasMatchE0_3 | hasMatchE0_4 | hasMatchE0_5 | hasMatchE0_6 | hasMatchE0_7;
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h8D, 8'hE0 , 8'h1F }),
	.needmatches(8'd1)
	) match_bytes_E0_0(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE0_0)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h8D, 8'hE0 , 8'h5F }),
	.needmatches(8'd1)
	) match_bytes_E0_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE0_1)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h8D, 8'hE9 , 8'hFF }),
	.needmatches(8'd1)
	) match_bytes_E0_2(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE0_2)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h0C, 8'hE0 , 8'h1F }),
	.needmatches(8'd1)
	) match_bytes_E0_3(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE0_3)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hE0 , 8'h1F }),
	.needmatches(8'd1)
	) match_bytes_E0_4(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE0_4)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hE9 , 8'hFF }),
	.needmatches(8'd1)
	) match_bytes_E0_5(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE0_5)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hED , 8'hFF }),
	.needmatches(8'd1)
	) match_bytes_E0_6(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE0_6)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hF3 , 8'hBF }),
	.needmatches(8'd1)
	) match_bytes_E0_7(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchE0_7)
);

wire hasMatchF8_0 , hasMatchF8_1;
wire hasMatchF8 = hasMatchF8_0 | hasMatchF8_1;
wire hasMatchFE_0 , hasMatchFE_1 , hasMatchFE_2 , hasMatchFE_3;
wire hasMatchFE = (~hasMatchF8) && (hasMatchFE_0 | hasMatchFE_1 | hasMatchFE_2 | hasMatchFE_3 );

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h8D, 8'hF9 , 8'h1F }),
	.needmatches(8'd2)
	) match_bytes_F8_0(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchF8_0)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h8D, 8'hF9 , 8'hFF }),
	.needmatches(8'd2)
	) match_bytes_F8_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchF8_1)
);

match_bytes #(
	.num_bytes(8'd5),
	.pattern({ 8'h20, 8'h00 , 8'hD0, 8'hC6 , 8'hC5 }),
	.needmatches(8'd1)
	) match_bytes_FE_0(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchFE_0)
);
match_bytes #(
	.num_bytes(8'd5),
	.pattern({ 8'h20, 8'hC3 , 8'hF8, 8'hA5 , 8'h82 }),
	.needmatches(8'd1)
	) match_bytes_FE_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchFE_1)
);
match_bytes #(
	.num_bytes(8'd5),
	.pattern({ 8'hD0, 8'hFB , 8'h20, 8'h73 , 8'hFE }),
	.needmatches(8'd1)
	) match_bytes_FE_2(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchFE_2)
);
match_bytes #(
	.num_bytes(8'd5),
	.pattern({ 8'h20, 8'h00 , 8'hF0, 8'h84 , 8'hD6 }),
	.needmatches(8'd1)
	) match_bytes_FE_3(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchFE_3)
);

wire hasMatchCV_0 , hasMatchCV_1;
wire hasMatchCV = hasMatchCV_0 | hasMatchCV_1;

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h9D, 8'hFF , 8'hF3 }),
	.needmatches(8'd1)
	) match_bytes_CV_0(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchCV_0)
);
match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h99, 8'h00 , 8'hF4 }),
	.needmatches(8'd1)
	) match_bytes_CV_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchCV_1)
);

wire hasMatchUA_0 , hasMatchUA_1 , hasMatchUA_2 , hasMatchUA_3 , hasMatchUA_4 , hasMatchUA_5 , hasMatchUA_6 , hasMatchUA_7 , hasMatchUA_8 , hasMatchUA_9 , hasMatchUA_10 , hasMatchUA_11;
wire hasMatchUA = hasMatchUA_0 | hasMatchUA_1 | hasMatchUA_2 | hasMatchUA_3 | hasMatchUA_4 | hasMatchUA_5 | hasMatchUA_6 | hasMatchUA_7 | hasMatchUA_8 | hasMatchUA_9 | hasMatchUA_10 | hasMatchUA_11;

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h8D, 8'h40 , 8'h02 }),
	.needmatches(8'd1)
	) match_bytes_UA_0(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_0)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'h40 , 8'h02 }),
	.needmatches(8'd1)
	) match_bytes_UA_1(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_1)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hBD, 8'h1F , 8'h02 }),
	.needmatches(8'd1)
	) match_bytes_UA_2(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_2)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h2C, 8'hC0 , 8'h02 }),
	.needmatches(8'd1)
	) match_bytes_UA_3(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_3)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h8D, 8'hC0 , 8'h02 }),
	.needmatches(8'd1)
	) match_bytes_UA_4(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_4)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hC0 , 8'h02 }),
	.needmatches(8'd1)
	) match_bytes_UA_5(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_5)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h2C, 8'hC0 , 8'h0F }),
	.needmatches(8'd1)
	) match_bytes_UA_6(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_6)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h2C, 8'hB0 , 8'h0F }),
	.needmatches(8'd1)
	) match_bytes_UA_7(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_7)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h2C, 8'hC0 , 8'h0F }),
	.needmatches(8'd1)
	) match_bytes_UA_8(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_8)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h8D, 8'hC0 , 8'h0F }),
	.needmatches(8'd1)
	) match_bytes_UA_9(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_9)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'hAD, 8'hC0 , 8'h0F }),
	.needmatches(8'd1)
	) match_bytes_UA_10(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_10)
);

match_bytes #(
	.num_bytes(8'd3),
	.pattern({ 8'h2C, 8'hC0 , 8'hEF }),
	.needmatches(8'd1)
	) match_bytes_UA_11(
	.addr(addr),
	.enable(enable),
	.clk(clk),
	.reset(reset),
	.data(data),
	.hasMatch(hasMatchUA_11)
);

reg [31:0] sc_crc0,sc_crc1,sc_crc2;
reg has_sc;

always @(posedge clk) begin
	if (enable) begin
		if (addr < 16'h80) begin
			if (addr==0)
			begin
				sc_crc1<=0;
				has_sc<=0;
				sc_crc0<=nextCRC32_D8(data,32'b0);
			end
			else
				sc_crc0<=nextCRC32_D8(data,sc_crc0);
		end
		else if (addr >= 16'h80 && addr < 16'h100) begin
			sc_crc1<=nextCRC32_D8(data,sc_crc1);
		end
		else if (addr==16'h100) begin
			has_sc<= (sc_crc0==sc_crc1);
			sc_crc0<=0;
			sc_crc1<=0;
		end
		if (addr >= 16'h1000 && addr < 16'h1080) begin
			sc_crc0<=nextCRC32_D8(data,sc_crc0);
		end
		else if (addr >= 16'h1080 && addr < 16'h1100) begin
			sc_crc1<=nextCRC32_D8(data,sc_crc1);
		end
		else if (addr==16'h1100) begin
                        if (has_sc)
				has_sc<= (sc_crc0==sc_crc1);
		end
	end
end

  function [31:0] nextCRC32_D8;

	input [7:0] Data;
	input [31:0] crc;
	reg [7:0] d;
	reg [31:0] c;
	reg [31:0] newcrc;
  begin
	d = Data;
	c = crc;

	newcrc[0] = d[6] ^ d[0] ^ c[24] ^ c[30];
	newcrc[1] = d[7] ^ d[6] ^ d[1] ^ d[0] ^ c[24] ^ c[25] ^ c[30] ^ c[31];
	newcrc[2] = d[7] ^ d[6] ^ d[2] ^ d[1] ^ d[0] ^ c[24] ^ c[25] ^ c[26] ^ c[30] ^ c[31];
	newcrc[3] = d[7] ^ d[3] ^ d[2] ^ d[1] ^ c[25] ^ c[26] ^ c[27] ^ c[31];
	newcrc[4] = d[6] ^ d[4] ^ d[3] ^ d[2] ^ d[0] ^ c[24] ^ c[26] ^ c[27] ^ c[28] ^ c[30];
	newcrc[5] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[1] ^ d[0] ^ c[24] ^ c[25] ^ c[27] ^ c[28] ^ c[29] ^ c[30] ^ c[31];
	newcrc[6] = d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[2] ^ d[1] ^ c[25] ^ c[26] ^ c[28] ^ c[29] ^ c[30] ^ c[31];
	newcrc[7] = d[7] ^ d[5] ^ d[3] ^ d[2] ^ d[0] ^ c[24] ^ c[26] ^ c[27] ^ c[29] ^ c[31];
	newcrc[8] = d[4] ^ d[3] ^ d[1] ^ d[0] ^ c[0] ^ c[24] ^ c[25] ^ c[27] ^ c[28];
	newcrc[9] = d[5] ^ d[4] ^ d[2] ^ d[1] ^ c[1] ^ c[25] ^ c[26] ^ c[28] ^ c[29];
	newcrc[10] = d[5] ^ d[3] ^ d[2] ^ d[0] ^ c[2] ^ c[24] ^ c[26] ^ c[27] ^ c[29];
	newcrc[11] = d[4] ^ d[3] ^ d[1] ^ d[0] ^ c[3] ^ c[24] ^ c[25] ^ c[27] ^ c[28];
	newcrc[12] = d[6] ^ d[5] ^ d[4] ^ d[2] ^ d[1] ^ d[0] ^ c[4] ^ c[24] ^ c[25] ^ c[26] ^ c[28] ^ c[29] ^ c[30];
	newcrc[13] = d[7] ^ d[6] ^ d[5] ^ d[3] ^ d[2] ^ d[1] ^ c[5] ^ c[25] ^ c[26] ^ c[27] ^ c[29] ^ c[30] ^ c[31];
	newcrc[14] = d[7] ^ d[6] ^ d[4] ^ d[3] ^ d[2] ^ c[6] ^ c[26] ^ c[27] ^ c[28] ^ c[30] ^ c[31];
	newcrc[15] = d[7] ^ d[5] ^ d[4] ^ d[3] ^ c[7] ^ c[27] ^ c[28] ^ c[29] ^ c[31];
	newcrc[16] = d[5] ^ d[4] ^ d[0] ^ c[8] ^ c[24] ^ c[28] ^ c[29];
	newcrc[17] = d[6] ^ d[5] ^ d[1] ^ c[9] ^ c[25] ^ c[29] ^ c[30];
	newcrc[18] = d[7] ^ d[6] ^ d[2] ^ c[10] ^ c[26] ^ c[30] ^ c[31];
	newcrc[19] = d[7] ^ d[3] ^ c[11] ^ c[27] ^ c[31];
	newcrc[20] = d[4] ^ c[12] ^ c[28];
	newcrc[21] = d[5] ^ c[13] ^ c[29];
	newcrc[22] = d[0] ^ c[14] ^ c[24];
	newcrc[23] = d[6] ^ d[1] ^ d[0] ^ c[15] ^ c[24] ^ c[25] ^ c[30];
	newcrc[24] = d[7] ^ d[2] ^ d[1] ^ c[16] ^ c[25] ^ c[26] ^ c[31];
	newcrc[25] = d[3] ^ d[2] ^ c[17] ^ c[26] ^ c[27];
	newcrc[26] = d[6] ^ d[4] ^ d[3] ^ d[0] ^ c[18] ^ c[24] ^ c[27] ^ c[28] ^ c[30];
	newcrc[27] = d[7] ^ d[5] ^ d[4] ^ d[1] ^ c[19] ^ c[25] ^ c[28] ^ c[29] ^ c[31];
	newcrc[28] = d[6] ^ d[5] ^ d[2] ^ c[20] ^ c[26] ^ c[29] ^ c[30];
	newcrc[29] = d[7] ^ d[6] ^ d[3] ^ c[21] ^ c[27] ^ c[30] ^ c[31];
	newcrc[30] = d[7] ^ d[4] ^ c[22] ^ c[28] ^ c[31];
	newcrc[31] = d[5] ^ c[23] ^ c[29];
	nextCRC32_D8 = newcrc;
  end
  endfunction

reg fa2_tail_zero;
always @(posedge clk) begin
	if (enable) begin
		if (addr == 0)
			fa2_tail_zero <= 1'b1;
		else if (addr >= 25'd29696 && addr < 25'd32768 && data != 8'd0)
			fa2_tail_zero <= 1'b0;
	end
end

always @(posedge clk) begin :bs_decision
sc<=0;
if (hasMatchCDF && cart_size>='d32768) force_bs<=BANKCDF;
else if (hasMatchFE) force_bs<=BANKFE;
else if (hasMatchE0 && cart_size=='d8192) force_bs<=BANKE0;
else if (hasMatch3E && cart_size>'d4096)  force_bs<=BANK3E;
else if (hasMatch3F && cart_size>'d4096) force_bs<=BANK3F;
else if (hasMatchSB && cart_size>='d131072) force_bs<=BANKSB;
else if (hasMatchEF && cart_size=='d65536 ) begin
	force_bs<=BANKEF;
	sc <= has_sc;
end
else if (hasMatchDPCP && cart_size=='d32768) force_bs<=BANKDPCP;
else if (hasMatchCTY && cart_size=='d32768) force_bs<=BANKCTY;
else if (hasMatchCTY && cart_size=='d61440) force_bs<=BANKCTY;
else if (hasMatchCV) force_bs<=BANKCV;
else if (hasMatchJANE && cart_size=='d16384) force_bs<=BANKJANE;
else if (hasMatchE7) force_bs<=BANKE7;
else if (cart_size == 'h2000 && hasMatchWD ) force_bs<=BANKWD;
else if (cart_size == 'h2000 && hasMatchUA ) force_bs<=BANKUA;
else if (cart_size == 'h1800) force_bs<=BANKAR;
else if (cart_size == 'h2100) force_bs<=BANKAR;
else if (cart_size == 'h4200) force_bs<=BANKAR;
else if (cart_size == 'h6300) force_bs<=BANKAR;
else if (cart_size == 'h8400) force_bs<=BANKAR;
else if (cart_size <= 'h0800) force_bs<=BANK2K;
else if (cart_size <= 'h1000) force_bs<=BANK00;
else if (cart_size <= 'h2000) begin
	force_bs<=BANKF8;
        sc <= has_sc;
end
else if (cart_size >= 'h2800 && cart_size <= 'h2900) force_bs<=BANKP2;
else if (cart_size <= 'h3000) force_bs<=BANKFA;
else if (cart_size <= 'h4000) begin
	force_bs<=BANKF6;
        sc <= has_sc;
end
else if (cart_size == 'd24576 || cart_size == 'd28672) force_bs<=BANKFA2;
else if (cart_size == 'd32768 && fa2_tail_zero && !has_sc) force_bs<=BANKFA2;
else if (cart_size <= 'h8000) begin
	force_bs<=BANKF4;
        sc <= has_sc;
end
else if (cart_size < 'h10000) force_bs<=BANK32;
else if (cart_size == 'h10000) force_bs<=BANKF0;
else if (cart_size == 'd131072 || cart_size == 'd262144) force_bs<=BANKSB;
else force_bs<=0;

end

assign cdf_family = cdf_family_r;

endmodule: detect2600

module match_bytes
(
	input clk,
	input reset,
	input  [24:0] addr,
	input  enable,
	input  [7:0] data,
	output reg hasMatch
);

parameter [7:0] num_bytes = 8'd1;
parameter [(num_bytes*8)-1:0] pattern = '0;
parameter [7:0] needmatches=8'b1;

reg [(num_bytes*8)-1:0] lastPattern;

reg [7:0] curMatch;

always @(posedge clk)
begin
	if (enable)
	begin

		if (addr==25'b0)
		begin
			curMatch<=8'b0;
			hasMatch<=0;
			lastPattern<= {lastPattern[(num_bytes*8)-9:0],data};
		end
		else
		begin
			lastPattern<= {lastPattern[(num_bytes*8)-9:0],data};
			if (lastPattern == pattern)
			begin
					curMatch<=curMatch+8'b1;
					if (curMatch==(needmatches-8'b1))
						hasMatch<=1;
			end
		end
	end
	if (reset) begin
		curMatch <= 0;
		hasMatch <= 0;
		lastPattern <= '0;
	end
end

endmodule: match_bytes

