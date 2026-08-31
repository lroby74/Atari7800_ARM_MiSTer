module thumb3_icache
(
	input             clk,
	input             rst,

	input      [31:0] pc,
	input             lookup,
	output            valid,
	output            hit,
	output     [31:0] data,

	input      [31:0] fill_pc,
	input      [63:0] fill_d,
	input             fill_en,

	input      [31:0] inv_addr,
	input             inv_en
);

	(* ramstyle = "MLAB, no_rw_check" *) reg [60:0] mem_e0 [0:31];
	(* ramstyle = "MLAB, no_rw_check" *) reg [60:0] mem_e1 [0:31];
	(* ramstyle = "MLAB, no_rw_check" *) reg [60:0] mem_o0 [0:31];
	(* ramstyle = "MLAB, no_rw_check" *) reg [60:0] mem_o1 [0:31];

	reg [31:0] vld_e0, vld_e1, vld_o0, vld_o1;
	reg [63:0] lru;

	wire [31:0] a_e    = {fill_pc[31:3], 3'b000};
	wire [31:0] a_o    = {fill_pc[31:3], 3'b100};
	wire [31:0] d_e    = fill_d[31:0];
	wire [31:0] d_o    = fill_d[63:32];
	wire  [4:0] set_e  = a_e[7:3];
	wire  [4:0] set_o  = a_o[7:3];
	wire        lru_e  = lru[{1'b0, set_e}];
	wire        lru_o  = lru[{1'b1, set_o}];

	wire [4:0] rset = pc[7:3];
	reg [60:0] qe0, qe1, qo0, qo1;
	reg [31:0] pc_d;
	reg        ve0_d, ve1_d, vo0_d, vo1_d, lookup_d, pc2_d;

	always @(posedge clk) begin
		if (fill_en) begin
			if (~lru_e) mem_e0[set_e] <= {a_e[31:3], d_e};
			else        mem_e1[set_e] <= {a_e[31:3], d_e};
			if (~lru_o) mem_o0[set_o] <= {a_o[31:3], d_o};
			else        mem_o1[set_o] <= {a_o[31:3], d_o};
		end
		qe0      <= mem_e0[rset];
		qe1      <= mem_e1[rset];
		qo0      <= mem_o0[rset];
		qo1      <= mem_o1[rset];
		pc2_d    <= pc[2];
		pc_d     <= pc;
		ve0_d    <= vld_e0[rset];
		ve1_d    <= vld_e1[rset];
		vo0_d    <= vld_o0[rset];
		vo1_d    <= vld_o1[rset];
		lookup_d <= lookup;
	end

	wire [60:0] q0 = pc2_d ? qo0 : qe0;
	wire [60:0] q1 = pc2_d ? qo1 : qe1;
	wire        v0 = pc2_d ? vo0_d : ve0_d;
	wire        v1 = pc2_d ? vo1_d : ve1_d;

	always @(posedge clk) begin
		if (rst) begin
			vld_e0 <= 32'd0; vld_e1 <= 32'd0;
			vld_o0 <= 32'd0; vld_o1 <= 32'd0;
			lru         <= 64'd0;
		end else begin
			if (fill_en) begin
				if (~lru_e) vld_e0[set_e] <= 1'b1; else vld_e1[set_e] <= 1'b1;
				if (~lru_o) vld_o0[set_o] <= 1'b1; else vld_o1[set_o] <= 1'b1;
				lru[{1'b0, set_e}] <= ~lru_e;
				lru[{1'b1, set_o}] <= ~lru_o;
			end

			if (inv_en) begin
				vld_e0[inv_addr[7:3]] <= 1'b0;
				vld_e1[inv_addr[7:3]] <= 1'b0;
				vld_o0[inv_addr[7:3]] <= 1'b0;
				vld_o1[inv_addr[7:3]] <= 1'b0;
			end
		end
	end

	wire h0 = v0 && (q0[60:32] == pc_d[31:3]);
	wire h1 = v1 && (q1[60:32] == pc_d[31:3]);

	assign valid = lookup_d;
	assign hit   = lookup_d && (h0 || h1);
	assign data  = h0 ? q0[31:0] : q1[31:0];

endmodule

