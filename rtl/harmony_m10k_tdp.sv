`default_nettype none

module harmony_m10k_tdp #(
  parameter INIT_FILE = "",
  parameter AW = 12
)(
  input  wire          clk_a,
  input  wire [AW-1:0] addr_a,
  input  wire [31:0]   data_a,
  input  wire [3:0]    byteena_a,
  input  wire          wren_a,
  output wire [31:0]   q_a,
  input  wire          clk_b,
  input  wire [AW-1:0] addr_b,
  input  wire [31:0]   data_b,
  input  wire [3:0]    byteena_b,
  input  wire          wren_b,
  output wire [31:0]   q_b
);
  localparam NW = (1 << AW);
  altsyncram #(
    .intended_device_family        ("Cyclone V"),
    .lpm_type                      ("altsyncram"),
    .operation_mode                ("BIDIR_DUAL_PORT"),
    .ram_block_type                ("M10K"),
    .width_a                       (32), .widthad_a(AW), .numwords_a(NW), .width_byteena_a(4),
    .width_b                       (32), .widthad_b(AW), .numwords_b(NW), .width_byteena_b(4),

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
  ) ram_i (
    .clock0        (clk_a),
    .clock1        (clk_b),
    .address_a     (addr_a), .data_a(data_a), .byteena_a(byteena_a), .wren_a(wren_a), .q_a(q_a),
    .address_b     (addr_b), .data_b(data_b), .byteena_b(byteena_b), .wren_b(wren_b), .q_b(q_b),
    .aclr0         (1'b0),   .aclr1(1'b0),
    .addressstall_a(1'b0),   .addressstall_b(1'b0),
    .clocken0      (1'b1),   .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
    .rden_a        (1'b1),   .rden_b(1'b1),
    .eccstatus     ()
  );
endmodule
`default_nettype wire

