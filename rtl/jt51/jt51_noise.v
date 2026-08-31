module jt51_noise(
    input             rst,
    input             clk,
    input             cen,
    input      [ 4:0] cycles,

    input      [ 4:0] nfrq,

    input      [ 9:0] eg,
    input             op31_no,

    output            out,
    output reg [11:0] mix
);

reg         update, nfrq_met;
reg  [ 4:0] cnt;
reg  [15:0] lfsr;
reg         last_lfsr0;
wire        all1, fb;
wire        mix_sgn;

assign out = lfsr[0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cnt  <= 5'b0;
    end else if(cen) begin
        if( &cycles[3:0] ) begin
            cnt <= update ? 5'd0 : (cnt+5'd1);
        end
        update   <= nfrq_met;
        nfrq_met <= ~nfrq == cnt;
    end
end

assign fb   = update ? ~((all1 & ~last_lfsr0) | (lfsr[2]^last_lfsr0))
                     : ~lfsr[0];
assign all1 = &lfsr;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        lfsr       <= 16'hffff;
        last_lfsr0 <= 1'b0;
    end else if(cen) begin
        lfsr       <= { fb, lfsr[15:1] };
        if(update) last_lfsr0 <= ~lfsr[0];
    end
end

assign mix_sgn =  ~out;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mix <= 12'd0;
    end else if( op31_no && cen ) begin
        mix     <= { mix_sgn, eg[9:2] ^ {8{out}}, {3{mix_sgn}} };
    end
end

endmodule

