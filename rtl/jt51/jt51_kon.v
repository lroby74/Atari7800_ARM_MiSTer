module jt51_kon(
    input           rst,
    input           clk,
    input           cen,
    input   [3:0]   keyon_op,
    input   [2:0]   keyon_ch,
    input   [1:0]   cur_op,
    input   [2:0]   cur_ch,
    input           up_keyon,
    input           csm,
    input           overflow_A,

    output  reg     keyon_II
);

reg din;
wire drop;

reg [3:0] cur_op_hot;

always @(posedge clk) if (cen)
    keyon_II <= (csm&&overflow_A) || drop;

always @(*) begin
    case( cur_op )
        2'd0: cur_op_hot = 4'b0001;
        2'd1: cur_op_hot = 4'b0100;
        2'd2: cur_op_hot = 4'b0010;
        2'd3: cur_op_hot = 4'b1000;
    endcase
    din = keyon_ch==cur_ch && up_keyon ? |(keyon_op&cur_op_hot) : drop;
end

jt51_sh #(.width(1),.stages(32)) u_konch(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .din    ( din       ),
    .drop   ( drop      )
);

endmodule

