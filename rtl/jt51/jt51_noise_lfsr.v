module jt51_noise_lfsr #(parameter init=14220 )(
    input   rst,
    input   clk,
    input   cen,
    input   base,
    output  out
);

reg [16:0] bb;
assign out = bb[16];

always @(posedge clk, posedge rst) begin : base_counter
    if( rst ) begin
        bb          <= init[16:0];
    end
    else if(cen) begin
        if(  base ) begin
            bb[16:1]    <= bb[15:0];
            bb[0]       <= ~(bb[16]^bb[13]);
        end
    end
end

endmodule

