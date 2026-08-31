`default_nettype none

module thumb3_shim
(
	input  wire        clk,
	input  wire        rst,

	input  wire        start,
	input  wire [31:0] start_pc,
	input  wire [31:0] start_sp,
	input  wire [31:0] start_lr,
	output wire        halted,

	input  wire [31:0] cb_addr0,
	input  wire [31:0] cb_addr1,
	input  wire [31:0] cb_addr2,
	input  wire [31:0] cb_addr3,
	output reg         cb_req,
	output reg   [1:0] cb_id,
	output wire [31:0] cb_v1,
	output wire [31:0] cb_v2,
	input  wire        cb_ack,
	input  wire [31:0] cb_ret,

	output reg  [31:0] bus_addr,
	output reg  [31:0] bus_wdata,
	input  wire [31:0] bus_rdata,
	output reg   [3:0] bus_be,
	output reg         bus_we,
	output reg   [1:0] bus_sz,
	output reg         bus_req,
	input  wire        bus_ack,
	input  wire [31:0] bus_rdata_next,
	input  wire        bus_rdata_next_ok,

	output wire [31:0] bus_addr_pre,
	output wire [31:0] bus_addr_pre_nx,
	output wire        bus_req_pre,

	output wire [31:0] dbg_pc,
	output wire [31:0] dbg_r0
);

	wire [31:0] i_addr;
	wire        i_req;
	wire        i_ack;
	wire [63:0] i_data;

	wire [31:0] d_addr, d_wdata;
	wire        d_req, d_we, d_blk;
	wire  [1:0] d_sz;
	wire  [3:0] d_be;
	wire        d_ack;
	wire        d_gnt = take_d;
	wire [31:0] d_rdata = bus_rdata;

	wire        core_halted;
	wire [31:0] bx_pc, r_lr, r_r2, r_r3;

	reg         go;
	reg         go_keep;
	reg  [31:0] go_pc;
	reg         go_r2_we;
	reg  [31:0] go_r2;

	thumb3_core core (
		.clk(clk), .rst(rst),
		.start(go), .start_pc(go_pc),
		.start_sp(start_sp), .start_lr(start_lr),
		.start_keep(go_keep), .start_r2(go_r2), .start_r2_we(go_r2_we),
		.running(), .halted(core_halted), .bx_pc(bx_pc),
		.i_addr(i_addr), .i_req(i_req), .i_ack(i_ack), .i_data(i_data),
		.d_addr(d_addr), .d_req(d_req), .d_we(d_we), .d_sz(d_sz), .d_blk(d_blk),
		.d_wdata(d_wdata), .d_be(d_be), .d_free(idle), .d_gnt(d_gnt), .d_ack(d_ack), .d_rdata(d_rdata),
		.inv_addr(bus_addr), .inv_en(inv_en),
		.dbg_r0(dbg_r0), .dbg_r2(r_r2), .dbg_r3(r_r3), .dbg_lr(r_lr),
		.dbg_pc(dbg_pc), .dbg_retire(), .dbg_flags()
	);

	assign cb_v1 = r_r2;
	assign cb_v2 = r_r3;

	reg [3:0] code_region;
	always @(posedge clk) if (i_req) code_region <= i_addr[31:28];
	wire inv_en = bus_req && bus_we && (bus_addr[31:28] == code_region);

	localparam [1:0] S_IDLE = 2'd0, S_DATA = 2'd1, S_IF0 = 2'd2, S_IF1 = 2'd3;
	reg  [1:0] st;
	reg [31:0] if_lo;
	reg [31:0] if_addr;

	wire idle   = (st == S_IDLE);
	wire i_ack0 = (st == S_IF0) && bus_ack && bus_rdata_next_ok;
	wire i_ack1 = (st == S_IF1) && bus_ack;
	assign i_ack  = i_ack0 || i_ack1;
	assign i_data = i_ack0 ? {bus_rdata_next, bus_rdata} : {bus_rdata, if_lo};
	assign d_ack = (st == S_DATA) && bus_ack;
	wire take_d = idle && d_req;
	wire take_i = idle && !take_d && i_req && !i_ack;

	assign bus_addr_pre    = take_d ? {d_addr[31:2], 2'b00} : i_addr;
	assign bus_req_pre     = (take_d || take_i) && !bus_req;
	assign bus_addr_pre_nx = bus_addr_pre + 32'd4;

	always @(posedge clk) begin
		if (rst) begin
			st      <= S_IDLE;
			bus_req <= 1'b0;
			bus_we  <= 1'b0;
			bus_be  <= 4'd0;
			bus_sz  <= 2'd2;
		end else begin

			case (st)
				S_IDLE: begin

					if (take_d) begin
						bus_addr  <= {d_addr[31:2], 2'b00};
						bus_wdata <= d_wdata;
						bus_be    <= d_be;
						bus_sz    <= d_sz;
						bus_we    <= d_we;
						bus_req   <= 1'b1;
						st        <= S_DATA;
					end else if (take_i) begin
						bus_addr  <= i_addr;
						if_addr   <= i_addr;
						bus_be    <= 4'b1111;
						bus_sz    <= 2'd2;
						bus_we    <= 1'b0;
						bus_req   <= 1'b1;
						st        <= S_IF0;
					end
				end

				S_DATA: if (bus_ack) begin
					bus_req <= 1'b0;
					bus_we  <= 1'b0;
					st      <= S_IDLE;
				end

				S_IF0: if (bus_ack) begin
					if (bus_rdata_next_ok) begin
						bus_req <= 1'b0;
						st      <= S_IDLE;
					end else begin
						if_lo    <= bus_rdata;
						bus_addr <= if_addr + 32'd4;
						st       <= S_IF1;
					end
				end

				default: if (bus_ack) begin
					bus_req <= 1'b0;
					st      <= S_IDLE;
				end
			endcase
		end
	end

	reg        cb_busy;
	reg        was_halted;
	wire       stop_now = core_halted && !was_halted;
	wire [1:0] hit_id   = (bx_pc == cb_addr0) ? 2'd0 :
	                      (bx_pc == cb_addr1) ? 2'd1 :
	                      (bx_pc == cb_addr2) ? 2'd2 : 2'd3;
	wire       hit_any  = (bx_pc == cb_addr0) || (bx_pc == cb_addr1) ||
	                      (bx_pc == cb_addr2) || (bx_pc == cb_addr3);

	assign halted = core_halted && was_halted && !cb_busy && !go;

	always @(posedge clk) begin
		if (rst) begin
			go <= 1'b0; go_keep <= 1'b0; go_r2_we <= 1'b0;
			cb_req <= 1'b0; cb_id <= 2'd0; cb_busy <= 1'b0; was_halted <= 1'b1;
		end else begin
			go         <= 1'b0;
			go_r2_we   <= 1'b0;
			was_halted <= core_halted;

			if (start) begin
				go      <= 1'b1;
				go_keep <= 1'b0;
				go_pc   <= start_pc;
				cb_busy <= 1'b0;
				cb_req  <= 1'b0;
			end else if (stop_now && hit_any && !cb_busy) begin
				cb_busy <= 1'b1;
				cb_id   <= hit_id;
				cb_req  <= 1'b1;
			end else if (cb_busy && cb_ack) begin
				cb_req   <= 1'b0;
				cb_busy  <= 1'b0;

				go_r2_we <= (cb_id == 2'd2);
				go_r2    <= cb_ret;
				go       <= 1'b1;
				go_keep  <= 1'b1;
				go_pc    <= r_lr & 32'hFFFFFFFE;
			end
		end
	end

endmodule

`default_nettype wire

