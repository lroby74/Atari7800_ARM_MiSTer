`default_nettype none

module cdf_family_params (
    input  wire [1:0]  family_sel,
    output reg  [15:0] ds_base,
    output reg  [15:0] ds_inc_base,
    output reg  [15:0] wf_base,
    output reg  [7:0]  amp_stream,
    output reg  [7:0]  jump_mask,
    output reg         is_plus,
    output reg  [2:0]  start_bank,
    output reg  [15:0] prog_off,
    output reg  [31:0] cb0,
    output reg  [31:0] cb1,
    output reg  [31:0] cb2,
    output reg  [31:0] cb3
);

    always @* begin
        case (family_sel)
            2'b01: begin
                ds_base     = 16'h0098;
                ds_inc_base = 16'h0124;
                wf_base     = 16'h01b0;
                amp_stream  = 8'h23;
                jump_mask   = 8'hfe;
                is_plus     = 1'b0;
                start_bank  = 3'd6;
                prog_off    = 16'h1000;
                cb0         = 32'h00000756;
                cb1         = 32'h0000075a;
                cb2         = 32'h0000075e;
                cb3         = 32'h00000762;
            end
            2'b10: begin
                ds_base     = 16'h0098;
                ds_inc_base = 16'h0124;
                wf_base     = 16'h01b0;
                amp_stream  = 8'h23;
                jump_mask   = 8'hfe;
                is_plus     = 1'b1;
                start_bank  = 3'd0;
                prog_off    = 16'h0800;
                cb0         = 32'h00000756;
                cb1         = 32'h0000075a;
                cb2         = 32'h0000075e;
                cb3         = 32'h00000762;
            end
            default: begin
                ds_base     = 16'h00a0;
                ds_inc_base = 16'h0128;
                wf_base     = 16'h01b0;
                amp_stream  = 8'h22;
                jump_mask   = 8'hff;
                is_plus     = 1'b0;
                start_bank  = 3'd6;
                prog_off    = 16'h1000;
                cb0         = 32'h00000756;
                cb1         = 32'h0000075a;
                cb2         = 32'h0000075e;
                cb3         = 32'h00000762;
            end
        endcase
    end

endmodule

