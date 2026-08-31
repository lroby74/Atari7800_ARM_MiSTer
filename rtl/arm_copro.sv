`default_nettype none

module arm_copro
(
	input  wire        clk,
	input  wire        reset,

	input  wire  [2:0] reg_a,
	input  wire  [7:0] reg_din,
	input  wire        reg_wr,
	input  wire        reg_rd,
	output reg   [7:0] reg_dout,

	input  wire  [7:0] aud_com,
	input  wire        aud_req,

	input  wire        auto_start,

	output wire [24:0] ext_addr,
	output wire        ext_req,
	input  wire  [7:0] ext_data,
	input  wire        ext_ack,

	output wire [15:0] audio,
	output wire        busy
);

	wire [31:0] i_addr;
	wire        i_req;
	reg         i_ack;
	reg  [63:0] i_data;

	wire [31:0] d_addr, d_wdata;
	wire  [3:0] d_be;
	wire        d_req, d_we;
	reg  [31:0] d_rdata;
	reg         d_ack;

	reg         arm_start;
	wire        arm_halted;

	reg  [31:0] inv_addr;
	reg         inv_en;

	reg  [15:0] ptr;
	reg         ld_wr;
	reg   [7:0] ld_data;
	reg  [15:0] ld_addr;

	wire        p_ld = ld_wr;

	wire        d_ext = d_addr[23];
	wire        p_d  = d_req && !p_ld && !d_ext;
	wire        p_i  = i_req && !i_ack && !p_ld && !p_d;

	wire        ext_take = ext_req && ext_ack;

	wire        d_free   = !p_ld && (!d_ext || ext_ack);

	wire [13:0] p_addr  = p_ld ? ld_addr[13:0]
	                    : (p_d ? d_addr[13:0] : i_addr[13:0]);
	wire [31:0] p_wdata = p_ld ? {4{ld_data}} : d_wdata;
	wire  [3:0] p_be    = p_ld ? (4'b0001 << ld_addr[1:0]) : d_be;
	wire        p_we    = p_ld || (p_d && d_we && !d_addr[14] && !d_ext);

	thumb3_core #(.WATCHDOG(0)) cpu (
		.clk(clk), .rst(reset),
		.start(arm_start), .start_pc(32'h00000000),
		.start_sp(32'h00004000), .start_lr(32'hFFFFFFFF),
		.start_keep(1'b0), .start_r2(32'd0), .start_r2_we(1'b0),
		.running(), .halted(arm_halted), .bx_pc(),
		.i_addr(i_addr), .i_req(i_req), .i_ack(i_ack), .i_data(i_data),
		.d_addr(d_addr), .d_req(d_req), .d_we(d_we), .d_sz(), .d_blk(),
		.d_wdata(d_wdata), .d_be(d_be),
		.d_free(d_free),
		.d_gnt(p_d | ext_take),
		.d_ack(d_ack), .d_rdata(d_rdata),
		.inv_addr(inv_addr), .inv_en(inv_en),
		.dbg_r0(), .dbg_r2(), .dbg_r3(), .dbg_lr(),
		.dbg_pc(), .dbg_retire(), .dbg_flags()
	);

	assign busy = ~arm_halted;

	wire [10:0] ridx = p_addr[13:3];
	wire        rodd = p_addr[2];

	wire        we_e = p_we && ~rodd;
	wire        we_o = p_we &&  rodd;

	parameter FW_FILE = "copro_m_";

	reg [7:0] m_e0 [0:2047];  reg [7:0] q_e0;
	reg [7:0] m_e1 [0:2047];  reg [7:0] q_e1;
	reg [7:0] m_e2 [0:2047];  reg [7:0] q_e2;
	reg [7:0] m_e3 [0:2047];  reg [7:0] q_e3;
	reg [7:0] m_o0 [0:2047];  reg [7:0] q_o0;
	reg [7:0] m_o1 [0:2047];  reg [7:0] q_o1;
	reg [7:0] m_o2 [0:2047];  reg [7:0] q_o2;
	reg [7:0] m_o3 [0:2047];  reg [7:0] q_o3;

	initial begin
		if (FW_FILE != "") begin
			$readmemh({FW_FILE, "e0.hex"}, m_e0);
			$readmemh({FW_FILE, "e1.hex"}, m_e1);
			$readmemh({FW_FILE, "e2.hex"}, m_e2);
			$readmemh({FW_FILE, "e3.hex"}, m_e3);
			$readmemh({FW_FILE, "o0.hex"}, m_o0);
			$readmemh({FW_FILE, "o1.hex"}, m_o1);
			$readmemh({FW_FILE, "o2.hex"}, m_o2);
			$readmemh({FW_FILE, "o3.hex"}, m_o3);
		end
	end

	always @(posedge clk) begin
		if (we_e && p_be[0]) m_e0[ridx] <= p_wdata[7:0];
		q_e0 <= m_e0[ridx];
	end
	always @(posedge clk) begin
		if (we_e && p_be[1]) m_e1[ridx] <= p_wdata[15:8];
		q_e1 <= m_e1[ridx];
	end
	always @(posedge clk) begin
		if (we_e && p_be[2]) m_e2[ridx] <= p_wdata[23:16];
		q_e2 <= m_e2[ridx];
	end
	always @(posedge clk) begin
		if (we_e && p_be[3]) m_e3[ridx] <= p_wdata[31:24];
		q_e3 <= m_e3[ridx];
	end
	always @(posedge clk) begin
		if (we_o && p_be[0]) m_o0[ridx] <= p_wdata[7:0];
		q_o0 <= m_o0[ridx];
	end
	always @(posedge clk) begin
		if (we_o && p_be[1]) m_o1[ridx] <= p_wdata[15:8];
		q_o1 <= m_o1[ridx];
	end
	always @(posedge clk) begin
		if (we_o && p_be[2]) m_o2[ridx] <= p_wdata[23:16];
		q_o2 <= m_o2[ridx];
	end
	always @(posedge clk) begin
		if (we_o && p_be[3]) m_o3[ridx] <= p_wdata[31:24];
		q_o3 <= m_o3[ridx];
	end

	wire [31:0] q_even = {q_e3, q_e2, q_e1, q_e0};
	wire [31:0] q_odd  = {q_o3, q_o2, q_o1, q_o0};

	always @(posedge clk) begin
		i_ack <= p_i;
		if (reset) i_ack <= 1'b0;
	end
	always @* i_data = {q_odd, q_even};

	reg [15:0] sample;
	reg        auto_done;
	reg  [7:0] com_latch;
	reg        com_flag;

	assign ext_addr = d_addr[24:0] & 25'h07FFFFF;
	assign ext_req  = d_req && d_ext && !d_we;
	reg  [7:0] ext_lat;
	reg        ext_done;
	always @(posedge clk) begin
		if (reset) begin
			ext_lat  <= 8'd0;
			ext_done <= 1'b0;
		end else begin
			ext_done <= 1'b0;
			if (ext_take) begin
				ext_lat  <= ext_data;
				ext_done <= 1'b1;
			end
		end
	end

	reg        d_hi_d, d_off_d, d_ext_d;
	always @(posedge clk) begin
		d_hi_d  <= d_addr[14];
		d_ext_d <= d_ext;
		d_off_d <= d_addr[2];
		d_ack   <= p_d | ext_done;
		if (reset) d_ack <= 1'b0;
	end

	always @* begin
		if (d_ext_d)
			d_rdata = {24'd0, ext_lat};
		else if (d_hi_d)
			d_rdata = d_off_d ? {23'd0, com_flag, com_latch} : {16'd0, sample};
		else
			d_rdata = d_off_d ? q_odd : q_even;
	end

	assign audio = sample;

	always @(posedge clk) begin
		inv_en   <= ld_wr;
		inv_addr <= {16'd0, ld_addr};
		if (reset) inv_en <= 1'b0;
	end

	always @(posedge clk) begin
		if (reset) begin
			ptr <= 16'd0; arm_start <= 1'b0; ld_wr <= 1'b0;
			sample <= 16'd0; com_latch <= 8'd0; com_flag <= 1'b0; auto_done <= 1'b0;
		end else begin
			arm_start <= 1'b0;
			ld_wr     <= 1'b0;

			if (auto_start && !auto_done) begin
				arm_start <= 1'b1;
				auto_done <= 1'b1;
			end

			if (d_req && d_we && d_addr[14] && !d_addr[2]) begin
				if (d_be[0]) sample[7:0]  <= d_wdata[7:0];
				if (d_be[1]) sample[15:8] <= d_wdata[15:8];
			end

			if (d_req && !d_we && d_addr[14] && d_addr[2])
				com_flag <= 1'b0;

			if (aud_req) begin
				com_latch <= aud_com;
				com_flag  <= 1'b1;
			end

			if (reg_wr) begin
				case (reg_a[2:0])
					3'd0: ptr[7:0]  <= reg_din;
					3'd1: ptr[15:8] <= reg_din;
					3'd2: begin
						ld_addr <= ptr;
						ld_data <= reg_din;
						ld_wr   <= 1'b1;
						ptr     <= ptr + 16'd1;
					end
					3'd3: if (reg_din[0]) arm_start <= 1'b1;
					default: ;
				endcase
			end
			if (reg_rd && reg_a[2:0] == 3'd2) ptr <= ptr + 16'd1;
		end
	end

	always @* begin
		case (reg_a[2:0])
			3'd3:    reg_dout = {7'd0, busy};
			3'd4:    reg_dout = sample[7:0];
			3'd5:    reg_dout = sample[15:8];
			default: reg_dout = 8'd0;
		endcase
	end

endmodule

`default_nettype wire

