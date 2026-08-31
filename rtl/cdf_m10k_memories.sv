`default_nettype none

module cdf_rom_m10k #(
  parameter INIT_FILE = ""
)(
  input  wire        clk_a,
  input  wire [14:0] addr_a,

  input  wire [14:0] addr_a_nx,
  output wire [31:0] q_a,
  output wire [31:0] q_a_next,
  input  wire        clk_b,
  input  wire [14:0] addr_b,
  input  wire [31:0] data_b,
  input  wire [3:0]  byteena_b,
  input  wire        wren_b,
  output wire [31:0] q_b
);
  wire [13:0] idx_a  = addr_a[14:1];
  wire [13:0] a_even = addr_a[0] ? addr_a_nx[14:1] : idx_a;
  wire [13:0] a_odd  = idx_a;
  wire [13:0] idx_b  = addr_b[14:1];

  wire [31:0] qe_a, qo_a, qe_b, qo_b;
  assign q_a      = addr_a[0] ? qo_a : qe_a;
  assign q_a_next = addr_a[0] ? qe_a : qo_a;

  reg sel_b_d1 = 1'b0;
  always @(posedge clk_b) sel_b_d1 <= addr_b[0];
  assign q_b = sel_b_d1 ? qo_b : qe_b;

  altsyncram #(
    .intended_device_family        ("Cyclone V"),
    .lpm_type                      ("altsyncram"),
    .operation_mode                ("BIDIR_DUAL_PORT"),
    .ram_block_type                ("M10K"),
    .width_a                       (32), .widthad_a(14), .numwords_a(16384), .width_byteena_a(4),
    .width_b                       (32), .widthad_b(14), .numwords_b(16384), .width_byteena_b(4),

    .outdata_reg_a                 ("UNREGISTERED"),
    .outdata_reg_b                 ("UNREGISTERED"),
    .address_reg_b                 ("CLOCK1"),
    .indata_reg_b                  ("CLOCK1"),
    .wrcontrol_wraddress_reg_b     ("CLOCK1"),
    .byteena_reg_b                 ("CLOCK1"),
    .read_during_write_mode_port_a ("DONT_CARE"),
    .read_during_write_mode_port_b ("DONT_CARE"),
    .read_during_write_mode_mixed_ports("DONT_CARE"),
    .power_up_uninitialized        ("FALSE"),
    .init_file                     (INIT_FILE)
  ) ram_even (
    .clock0        (clk_a),  .clock1(clk_b),
    .address_a     (a_even), .data_a(32'd0), .byteena_a(4'b1111), .wren_a(1'b0), .q_a(qe_a),
    .address_b     (idx_b),  .data_b(data_b), .byteena_b(byteena_b),
    .wren_b        (wren_b & ~addr_b[0]), .q_b(qe_b),
    .aclr0         (1'b0),   .aclr1(1'b0),
    .addressstall_a(1'b0),   .addressstall_b(1'b0),
    .clocken0      (1'b1),   .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
    .rden_a        (1'b1),   .rden_b(1'b1),
    .eccstatus     ()
  );

  altsyncram #(
    .intended_device_family        ("Cyclone V"),
    .lpm_type                      ("altsyncram"),
    .operation_mode                ("BIDIR_DUAL_PORT"),
    .ram_block_type                ("M10K"),
    .width_a                       (32), .widthad_a(14), .numwords_a(16384), .width_byteena_a(4),
    .width_b                       (32), .widthad_b(14), .numwords_b(16384), .width_byteena_b(4),
    .outdata_reg_a                 ("UNREGISTERED"),
    .outdata_reg_b                 ("UNREGISTERED"),
    .address_reg_b                 ("CLOCK1"),
    .indata_reg_b                  ("CLOCK1"),
    .wrcontrol_wraddress_reg_b     ("CLOCK1"),
    .byteena_reg_b                 ("CLOCK1"),
    .read_during_write_mode_port_a ("DONT_CARE"),
    .read_during_write_mode_port_b ("DONT_CARE"),
    .read_during_write_mode_mixed_ports("DONT_CARE"),
    .power_up_uninitialized        ("FALSE"),
    .init_file                     (INIT_FILE)
  ) ram_odd (
    .clock0        (clk_a),  .clock1(clk_b),
    .address_a     (a_odd),  .data_a(32'd0), .byteena_a(4'b1111), .wren_a(1'b0), .q_a(qo_a),
    .address_b     (idx_b),  .data_b(data_b), .byteena_b(byteena_b),
    .wren_b        (wren_b & addr_b[0]), .q_b(qo_b),
    .aclr0         (1'b0),   .aclr1(1'b0),
    .addressstall_a(1'b0),   .addressstall_b(1'b0),
    .clocken0      (1'b1),   .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
    .rden_a        (1'b1),   .rden_b(1'b1),
    .eccstatus     ()
  );
endmodule

module cdf_display_m10k (
  input  wire        clk,
  input  wire [11:0] addr_a,
  input  wire [7:0]  data_a,
  input  wire        wren_a,
  output wire [7:0]  q_a,
  input  wire [11:0] addr_b,
  output wire [7:0]  q_b
);
  altsyncram #(
    .intended_device_family        ("Cyclone V"),
    .lpm_type                      ("altsyncram"),
    .operation_mode                ("BIDIR_DUAL_PORT"),
    .ram_block_type                ("M10K"),
    .width_a                       (8), .widthad_a(12), .numwords_a(4096), .width_byteena_a(1),
    .width_b                       (8), .widthad_b(12), .numwords_b(4096), .width_byteena_b(1),
    .outdata_reg_a                 ("CLOCK0"),
    .outdata_reg_b                 ("CLOCK0"),
    .address_reg_b                 ("CLOCK0"),
    .indata_reg_b                  ("CLOCK0"),
    .wrcontrol_wraddress_reg_b     ("CLOCK0"),
    .byteena_reg_b                 ("CLOCK0"),
    .read_during_write_mode_port_a ("DONT_CARE"),
    .read_during_write_mode_port_b ("DONT_CARE"),
    .read_during_write_mode_mixed_ports("DONT_CARE"),
    .power_up_uninitialized        ("FALSE")
  ) ram_i (
    .clock0        (clk),
    .address_a     (addr_a), .data_a(data_a), .byteena_a(1'b1), .wren_a(wren_a), .q_a(q_a),
    .address_b     (addr_b), .data_b(8'd0),    .byteena_b(1'b1), .wren_b(1'b0),  .q_b(q_b),
    .aclr0         (1'b0),   .aclr1(1'b0),
    .addressstall_a(1'b0),   .addressstall_b(1'b0),
    .clocken0      (1'b1),   .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
    .rden_a        (1'b1),   .rden_b(1'b1),
    .eccstatus     ()
  );
endmodule
`default_nettype wire

