`default_nettype none

module arm_cart_rom #(
  parameter INIT_FILE = ""
)(
  input  wire        clk_a,
  input  wire        clk_b,

  input  wire        dpc_sel,

  input  wire        cart_download,

  input  wire [14:0] c_addr_a,
  input  wire [14:0] c_addr_a_nx,
  output wire [31:0] c_q_a,
  output wire [31:0] c_q_a_next,
  input  wire [14:0] c_addr_b,
  input  wire [31:0] c_data_b,
  input  wire  [3:0] c_byteena_b,
  input  wire        c_wren_b,
  output wire [31:0] c_q_b,

  input  wire [12:0] d_addr_a,
  output wire [31:0] d_q_a,
  input  wire [14:0] d_addr_b,
  output wire  [7:0] d_q_b,

  input  wire        e_sel,
  input  wire [16:0] e_addr,
  input  wire  [7:0] e_data,
  input  wire        e_wren,
  output wire  [7:0] e_q
);

  wire [14:0] addr_a    = dpc_sel ? {2'b00, d_addr_a} : c_addr_a;
  wire [14:0] addr_a_nx = dpc_sel ? {2'b00, d_addr_a} : c_addr_a_nx;
  wire [31:0] q_a, q_a_next;
  assign c_q_a      = q_a;
  assign c_q_a_next = q_a_next;
  assign d_q_a      = q_a;

  wire        take_e  = e_sel && !cart_download;
  wire        take_d  = dpc_sel && !cart_download && !take_e;
  wire [14:0] addr_b  = take_e ? e_addr[16:2] :
                        take_d ? {2'b00, d_addr_b[14:2]} : c_addr_b;
  wire [31:0] data_b  = take_e ? {4{e_data}} : c_data_b;
  wire  [3:0] be_b    = take_e ? (4'd1 << e_addr[1:0]) : c_byteena_b;
  wire        wren_b  = take_e ? e_wren : (c_wren_b && !take_d);
  wire [31:0] q_b;
  assign c_q_b = q_b;

  reg [1:0] e_lane_d1;
  always @(posedge clk_b) e_lane_d1 <= e_addr[1:0];
  assign e_q = q_b[e_lane_d1*8 +: 8];

  reg  [1:0] d_lane_d1;
  reg  [7:0] d_q_b_r;
  always @(posedge clk_b) begin
    d_lane_d1 <= d_addr_b[1:0];
    d_q_b_r   <= q_b[d_lane_d1*8 +: 8];
  end
  assign d_q_b = d_q_b_r;

  cdf_rom_m10k #(.INIT_FILE(INIT_FILE)) rom_i (
    .clk_a     (clk_a),
    .addr_a    (addr_a),
    .addr_a_nx (addr_a_nx),
    .q_a       (q_a),
    .q_a_next  (q_a_next),
    .clk_b     (clk_b),
    .addr_b    (addr_b),
    .data_b    (data_b),
    .byteena_b (be_b),
    .wren_b    (wren_b),
    .q_b       (q_b)
  );

endmodule

`default_nettype wire

