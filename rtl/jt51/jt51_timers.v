module jt51_timers(
    input         rst,
    input         clk,
    input         cen,
    input         zero,
    input [9:0]   value_A,
    input [7:0]   value_B,
    input         load_A,
    input         load_B,
    input         clr_flag_A,
    input         clr_flag_B,
    input         enable_irq_A,
    input         enable_irq_B,
    output        flag_A,
    output        flag_B,
    output        overflow_A,
    output        irq_n
);

assign irq_n = ~( (flag_A&enable_irq_A) | (flag_B&enable_irq_B) );

jt51_timer #(.CW(10)) timer_A(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .zero       ( zero      ),
    .start_value( value_A   ),
    .load       ( load_A    ),
    .clr_flag   ( clr_flag_A),
    .flag       ( flag_A    ),
    .overflow   ( overflow_A)
);

jt51_timer #(.CW(8),.FREE_EN(1)) timer_B(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),
    .zero       ( zero          ),
    .start_value( value_B       ),
    .load       ( load_B        ),
    .clr_flag   ( clr_flag_B    ),
    .flag       ( flag_B        ),
    .overflow   (               )
);

endmodule

module jt51_timer #(parameter
    CW      = 8,
    FREE_EN = 0
) (
    input   rst,
    input   clk,
    input   cen,
    input   zero,
    input   [CW-1:0] start_value,
    input   load,
    input   clr_flag,
    output reg flag,
    output reg overflow
);

reg          last_load;
reg [CW-1:0] cnt, next;
reg [   3:0] free_cnt, free_next;
reg          free_ov;

always@(posedge clk, posedge rst)
    if( rst )
        flag <= 1'b0;
    else  begin
        if( clr_flag )
            flag <= 1'b0;
        else if(overflow) flag<=1'b1;
    end

always @(*) begin
    {free_ov, free_next} = { 1'b0, free_cnt} + 1'b1;

    {overflow, next }    = { 1'b0, cnt }     + (FREE_EN ? free_ov : 1'b1);

end

always @(posedge clk) if(cen && zero) begin : counter
    last_load <= load;
    if ( rst )
        cnt <= 0;
    else if( (load && !last_load) || overflow ) begin
      cnt  <= start_value;
    end
    else if( last_load ) cnt <= next;
end

always @(posedge clk) begin
    if( rst ) begin
        free_cnt <= 4'd0;
    end else if( cen&&zero ) begin
        free_cnt <= free_cnt+4'd1;
    end
end

endmodule

