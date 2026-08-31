`default_nettype none
module cdc_sync2 (
  input  wire dst_clk,
  input  wire d,
  output reg  q
);
  reg q1;
  always @(posedge dst_clk) begin
    q1 <= d;
    q  <= q1;
  end
endmodule
`default_nettype wire

