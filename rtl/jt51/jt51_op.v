module jt51_op(
    `ifdef TEST_SUPPORT
    input               test_eg,
    input               test_op0,
    `endif
    input               rst,
    input               clk,
    input               cen,
    input       [9:0]   pg_phase_X,
    input       [2:0]   con_I,
    input       [2:0]   fb_II,

    input       [9:0]   eg_atten_XI,

    input               use_prevprev1,
    input               use_internal_x,
    input               use_internal_y,
    input               use_prev2,
    input               use_prev1,
    input               test_214,

    input               m1_enters,
    input               c1_enters,
    `ifdef SIMULATION
    input               zero,
    `endif

    output signed   [13:0]  op_XVII
);

wire signed [13:0] prev1, prevprev1, prev2;

jt51_sh #( .width(14), .stages(8)) prev1_buffer(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen    ( cen   ),
    .din    ( c1_enters ? op_XVII : prev1 ),
    .drop   ( prev1 )
);

jt51_sh #( .width(14), .stages(8)) prevprev1_buffer(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen    ( cen   ),
    .din    ( c1_enters ? prev1 : prevprev1 ),
    .drop   ( prevprev1 )
);

jt51_sh #( .width(14), .stages(8)) prev2_buffer(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen    ( cen   ),
    .din    ( m1_enters ? op_XVII : prev2 ),
    .drop   ( prev2 )
);

reg [13:0]  x,  y;
reg [14:0]  xs, ys, pm_preshift_II;
reg         m1_II;

always @(*) begin
    x  = ( {14{use_prevprev1}}  & prevprev1 ) |
          ( {14{use_internal_x}} & op_XVII ) |
          ( {14{use_prev2}}      & prev2 );
    y  = ( {14{use_prev1}}      & prev1 ) |
          ( {14{use_internal_y}} & op_XVII );
    xs = { x[13], x };
    ys = { y[13], y };
end

always @(posedge clk) if(cen) begin
    pm_preshift_II <= xs + ys;
    m1_II <= m1_enters;
end

reg  [9:0]  phasemod_II;
wire [9:0]  phasemod_X;

always @(*) begin

    if (!m1_II )
        phasemod_II = pm_preshift_II[10:1];
    else
        case( fb_II )
            3'd0: phasemod_II = 10'd0;
            3'd1: phasemod_II = { {4{pm_preshift_II[14]}}, pm_preshift_II[14:9] };
            3'd2: phasemod_II = { {3{pm_preshift_II[14]}}, pm_preshift_II[14:8] };
            3'd3: phasemod_II = { {2{pm_preshift_II[14]}}, pm_preshift_II[14:7] };
            3'd4: phasemod_II = {    pm_preshift_II[14],   pm_preshift_II[14:6] };
            3'd5: phasemod_II = pm_preshift_II[14:5];
            3'd6: phasemod_II = pm_preshift_II[13:4];
            3'd7: phasemod_II = pm_preshift_II[12:3];
            default: phasemod_II = 10'dx;
        endcase
end

jt51_sh #( .width(10), .stages(8)) phasemod_sh(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .cen    ( cen           ),
    .din    ( phasemod_II   ),
    .drop   ( phasemod_X    )
);

reg [ 9:0]  phase;

reg [ 7:0]  phaselo_XI, aux_X;
reg signbit_X;

always @(*) begin
    phase   = phasemod_X + pg_phase_X;
    aux_X   = phase[7:0] ^ {8{~phase[8]}};
    signbit_X = phase[9];
end

always @(posedge clk) if(cen) begin
    phaselo_XI <= aux_X;
end

wire [45:0] sta_XI;

jt51_phrom u_phrom(
    .clk    ( clk       ),
    .cen    ( cen       ),
    .addr   ( aux_X[5:1]),
    .ph     ( sta_XI    )
);

reg [18:0]  stb;
reg [10:0]  stf, stg;
reg [11:0]  logsin;
reg [10:0]  subtresult;
reg [11:0]  atten_internal_XI;

always @(*) begin

    case( phaselo_XI[7:6] )
        2'b00: stb = { 10'b0, sta_XI[29], sta_XI[25], 2'b0, sta_XI[18],
            sta_XI[14], 1'b0, sta_XI[7] , sta_XI[3] };
        2'b01: stb = { 6'b0 , sta_XI[37], sta_XI[34], 2'b0, sta_XI[28],
            sta_XI[24], 2'b0, sta_XI[17], sta_XI[13], sta_XI[10], sta_XI[6], sta_XI[2] };
        2'b10: stb = { 2'b0, sta_XI[43], sta_XI[41], 2'b0, sta_XI[36],
            sta_XI[33], 2'b0, sta_XI[27], sta_XI[23], 1'b0, sta_XI[20],
            sta_XI[16], sta_XI[12], sta_XI[9], sta_XI[5], sta_XI[1] };
        2'b11: stb = {
              sta_XI[45], sta_XI[44], sta_XI[42], sta_XI[40]
            , sta_XI[39], sta_XI[38], sta_XI[35], sta_XI[32]
            , sta_XI[31], sta_XI[30], sta_XI[26], sta_XI[22]
            , sta_XI[21], sta_XI[19], sta_XI[15], sta_XI[11]
            , sta_XI[8], sta_XI[4], sta_XI[0] };
        default: stb = 19'dx;
    endcase

    stf = { stb[18:15], stb[12:11], stb[8:7], stb[4:3], stb[0] };

    if( phaselo_XI[0] )
        stg = { 2'b0, stb[14], stb[14:13], stb[10:9], stb[6:5], stb[2:1] };
    else
        stg = 11'd0;

    logsin = stf + stg;

    subtresult = eg_atten_XI + logsin[11:2];

    atten_internal_XI = { subtresult[9:0], logsin[1:0] } | {12{subtresult[10]}};
end

wire [44:0] exp_XII;
reg  [11:0] totalatten_XII;
reg  [12:0] etb;
reg  [ 9:0] etf;
reg  [ 2:0] etg;

jt51_exprom u_exprom(
    .clk    ( clk           ),
    .cen    ( cen           ),
    .addr   ( atten_internal_XI[5:1] ),
    .exp    ( exp_XII       )
);

always @(posedge clk) if(cen) begin
    totalatten_XII <= atten_internal_XI;
end

always @(*) begin

    case( totalatten_XII[7:6] )
        2'b00: begin
                etf = { 1'b1, exp_XII[44:36]  };
                etg = { 1'b1, exp_XII[35:34] };
            end
        2'b01: begin
                etf = exp_XII[33:24];
                etg = { 2'b10, exp_XII[23] };
            end
        2'b10: begin
                etf = { 1'b0, exp_XII[22:14]  };
                etg = exp_XII[13:11];
            end
        2'b11: begin
                etf = { 2'b00, exp_XII[10:3]  };
                etg = exp_XII[2:0];
            end
    endcase
end

reg [9:0]   mantissa_XIII;
reg [3:0]   exponent_XIII;

always @(posedge clk) if(cen) begin

    mantissa_XIII <= etf + { 7'd0, totalatten_XII[0] ? 3'd0 : etg };
    exponent_XIII <= totalatten_XII[11:8];
end

reg [12:0]  shifter, shifter_2, shifter_3;

always @(*) begin

    shifter = { 3'b001, mantissa_XIII };
    case( ~exponent_XIII[1:0] )
        2'b00: shifter_2 = { 1'b0, shifter[12:1] };
        2'b01: shifter_2 = shifter;
        2'b10: shifter_2 = { shifter[11:0], 1'b0 };
        2'b11: shifter_2 = { shifter[10:0], 2'b0 };
    endcase
    case( ~exponent_XIII[3:2] )
        2'b00: shifter_3 = {12'b0, shifter_2[12]   };
        2'b01: shifter_3 = { 8'b0, shifter_2[12:8] };
        2'b10: shifter_3 = { 4'b0, shifter_2[12:4] };
        2'b11: shifter_3 = shifter_2;
    endcase
end

reg signed [13:0] op_XIII;
wire signbit_XIII;

always @(*) begin
    op_XIII = ({ test_214, shifter_3 } ^ {14{signbit_XIII}}) + {13'd0, signbit_XIII};
end

jt51_sh #( .width(14), .stages(4)) out_padding(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .din    ( op_XIII   ),
    .drop   ( op_XVII   )
);

jt51_sh #( .width(1), .stages(3)) shsignbit(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .din    ( signbit_X ),
    .drop   ( signbit_XIII  )
);

`ifndef JT51_NODEBUG
`ifdef SIMULATION

wire [4:0] cnt;

sep32_cnt u_sep32_cnt (.clk(clk), .cen(cen), .zero(zero), .cnt(cnt));

sep32 #(.width(14),.stg(17)) sep_op(
    .clk    ( clk           ),
    .cen    ( cen           ),
    .mixed  ( op_XVII       ),
    .cnt    ( cnt           )
    );

`endif
`endif

endmodule

