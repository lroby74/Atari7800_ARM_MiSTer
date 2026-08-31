`default_nettype none
module cdf_bridge #(
  parameter ROM_FILE="", RAM_FILE="", parameter ROM_DEPTH=131072,

  parameter RAM_DEPTH=32768, parameter DISP_DEPTH=4096,
  parameter bit SIM_TEST_HOOKS=0,

  parameter [17:0] WAIT_MAX = 18'd262143,

  parameter [17:0] DWAIT_BUDGET = 18'd4,

  parameter bit    ARSP_EN     = 1'b1,

  parameter bit    ARSP_PLUS_ONLY = 1'b0,
  parameter [17:0] ARSP_BUDGET = 18'd8192,

  parameter bit    CWAIT_EN    = 1'b1,
  parameter [17:0] CWAIT_BUDGET = 18'd65535
)(
  input wire clk,
  input wire clk_vid,
  input wire rst,
  input wire rst_vid,

  input wire [15:0] m6502_addr, input wire [7:0] m6502_din, input wire m6502_rwn,
  output reg [7:0] m6502_dout,

  input wire [31:0] bus_addr, input wire [31:0] bus_wdata, output wire [31:0] bus_rdata,

  input wire [31:0] bus_addr_pre, input wire bus_req_pre,
  input wire [31:0] bus_addr_pre_nx,
  input wire [3:0] bus_be, input wire bus_we, input wire [1:0] bus_sz, input wire bus_req,
  output wire bus_ack,

  output wire [31:0] bus_rdata_next,
  output wire        bus_rdata_next_ok,

  output wire       cmd_hold,
  output reg        callfn,
  output reg [7:0]  callfn_val,
  input wire        cb_req,
  input wire [1:0]  cb_id,
  input wire [31:0] cb_v1, input wire [31:0] cb_v2,
  output reg [31:0] cb_ret,
  output reg        cb_ack,

  input wire [1:0] family_sel,
  input wire ldx_en, input wire ldy_en,
  input wire [15:0] ff_offset,

  input wire disp_bank,

  input wire ds_wait_arm,

  input wire arm_run_now,

  input wire arm_run_any,
  output wire ds_wait,

  input wire rom_load_we, input wire [16:0] rom_load_addr, input wire [7:0] rom_load_data,

  output wire [14:0] rom_addr_a_o, output wire [14:0] rom_addr_a_nx_o,
  input  wire [31:0] rom_q_a_i,    input  wire [31:0] rom_q_a_next_i,
  output wire [14:0] rom_addr_b_o, output wire [31:0] rom_data_b_o,
  output wire  [3:0] rom_be_b_o,   output wire        rom_wren_b_o,
  input  wire [31:0] rom_q_b_i,

  input wire [18:0] rom_bytes,

  output wire [3:0] dbg_bank, output wire [7:0] dbg_mode,
  output wire        dbg_lda_valid, output wire [12:0] dbg_lda_addr, output wire [7:0] dbg_ff_val
);
  localparam [7:0] COMMSTREAM = 8'd32, JUMPSTREAM_BASE = 8'd33;

  wire [15:0] ds_base, ds_inc_base, wf_base, prog_off;
  wire [7:0] amp_stream, jump_mask; wire is_plus; wire [2:0] start_bank;
  wire [31:0] cb0_nc, cb1_nc, cb2_nc, cb3_nc;
  cdf_family_params params(.family_sel(family_sel), .ds_base(ds_base),
    .ds_inc_base(ds_inc_base), .wf_base(wf_base), .amp_stream(amp_stream),
    .jump_mask(jump_mask), .is_plus(is_plus), .start_bank(start_bank),
    .prog_off(prog_off),
    .cb0(cb0_nc), .cb1(cb1_nc), .cb2(cb2_nc), .cb3(cb3_nc));

  reg  [14:0] rom_addr_b;

  wire [14:0] rom_addr_a = arm_addr_eff[16:2];

  wire [31:0] arm_addr_eff_nx = bus_req_pre ? bus_addr_pre_nx
                                            : (bus_addr + 32'd4);
  wire [14:0] rom_addr_a_nx = arm_addr_eff_nx[16:2];

  localparam [13:0] RSTFILL_DRIVER = 14'd512;
  reg  [13:0] rstf_w = 14'h3FFF;
  wire        rstf_run = ~rstf_w[13];
  reg         rst_d;
  reg         rstf_we_q, rstf_drv_q;
  reg  [12:0] rstf_wa_q;
  always @(posedge clk) begin
    rst_d <= rst;
    if (rst && !rst_d) rstf_w <= 14'd0;
    else if (rstf_run) rstf_w <= rstf_w + 14'd1;
    rstf_we_q  <= rstf_run;
    rstf_wa_q  <= rstf_w[12:0];
    rstf_drv_q <= (rstf_w < RSTFILL_DRIVER);
  end

  wire        rom_wren_b  = rom_load_we;

  wire [14:0] rom_addr_bp = rom_load_we ? rom_load_addr[16:2]
                          : rstf_run    ? {2'b00, rstf_w[12:0]}
                                        : rom_addr_b;
  wire [31:0] rom_data_b  = {4{rom_load_data}};
  wire [3:0]  rom_be_b    = 4'b0001 << rom_load_addr[1:0];

  assign rom_addr_a_o    = rom_addr_a;
  assign rom_addr_a_nx_o = rom_addr_a_nx;
  assign rom_addr_b_o    = rom_addr_bp;
  assign rom_data_b_o    = rom_data_b;
  assign rom_be_b_o      = rom_be_b;
  assign rom_wren_b_o    = rom_wren_b;
  wire [31:0] rom_q_a      = rom_q_a_i;
  wire [31:0] rom_q_a_next = rom_q_a_next_i;
  wire [31:0] rom_q_b      = rom_q_b_i;

  localparam [16:0] HARMONY_LOAD_BYTES   = 17'd32768;
  localparam [16:0] HARMONY_DRIVER_BYTES = 17'd2048;
  wire [31:0] harmony_q_a, harmony_q_b;
  reg  [12:0] harmony_addr_b; reg harmony_we_b; reg [3:0] harmony_be_b;
  reg  [31:0] harmony_wdata_b;
  wire harmony_load_we = rom_load_we && (rom_load_addr < HARMONY_LOAD_BYTES);
  wire [7:0] harmony_load_data = (rom_load_addr < HARMONY_DRIVER_BYTES) ? rom_load_data : 8'd0;

  function [12:0] remap_disp; input [12:0] w; input bank; begin
    remap_disp = w;
  end endfunction

  localparam PINGPONG_ACTIVE = 1'b0;

  wire [31:0] arm_addr_eff = bus_req_pre ? bus_addr_pre : bus_addr;
  wire [12:0] harmony_wa_a  = arm_addr_eff[14:2];
  wire        arm_bank      = PINGPONG_ACTIVE ? ~disp_bank : disp_bank;
  wire [12:0] harmony_addr_a = remap_disp(harmony_wa_a, arm_bank);
  wire [31:0] harmony_data_a = bus_wdata;
  wire [3:0]  harmony_be_a   = bus_be;
  wire        harmony_we_a   = bus_req && bus_we && (bus_addr[31:28]==4'h4);

  wire [12:0] harmony_addr_bp = harmony_load_we ? rom_load_addr[14:2]
                              : rstf_we_q       ? rstf_wa_q
                                                : remap_disp(harmony_addr_b, disp_bank);
  wire [31:0] harmony_data_bp = harmony_load_we ? {4{harmony_load_data}}
                              : rstf_we_q       ? (rstf_drv_q ? rom_q_b : 32'd0)
                                                : harmony_wdata_b;
  wire [3:0]  harmony_be_bp   = harmony_load_we ? (4'b0001 << rom_load_addr[1:0])
                              : rstf_we_q       ? 4'b1111
                                                : harmony_be_b;
  wire        harmony_we_bp   = harmony_load_we | rstf_we_q | harmony_we_b;
  harmony_m10k_tdp #(.INIT_FILE(RAM_FILE), .AW(13)) harmony_ram_i (
    .clk_a(clk_vid), .addr_a(harmony_addr_a), .data_a(harmony_data_a),
    .byteena_a(harmony_be_a), .wren_a(harmony_we_a), .q_a(harmony_q_a),
    .clk_b(clk), .addr_b(harmony_addr_bp), .data_b(harmony_data_bp),
    .byteena_b(harmony_be_bp), .wren_b(harmony_we_bp), .q_b(harmony_q_b)
  );

  reg [3:0]  bank_reg;
  reg [7:0]  mode_reg;
  reg        lda_valid;  reg [12:0] lda_addr;
  reg [1:0]  fj_active;  reg [12:0] fj_operand; reg [7:0] fj_stream;
  reg [7:0]  amp_cached;
  reg [31:0] music_freq [0:2];
  reg [31:0] music_cnt  [0:2];
  reg [7:0]  wave_size  [0:2];
  reg [7:0]  ff_val;
  reg [9:0]  mus_div;

  wire fast_fetch_en    = (mode_reg[3:0] == 4'h0);
  wire digital_audio_en = (mode_reg[7:4] == 4'h0);

  assign dbg_bank = bank_reg;
  assign dbg_mode = mode_reg;

  assign dbg_lda_valid = lda_valid;
  assign dbg_lda_addr  = lda_addr;
  assign dbg_ff_val    = ff_val;

  wire m6502_cs = (m6502_addr[15:12] == 4'h1);
  reg [15:0] addr_d;
  reg        rwn_d;
  wire trigger = m6502_cs && ((m6502_addr != addr_d) || (m6502_rwn != rwn_d));
  wire [11:0] off_in = m6502_addr[11:0];

  reg [11:0] off; reg [7:0] din;

  function [14:0] prog_byte_addr; input [12:0] o13; begin
    prog_byte_addr = {2'd0, prog_off[12:0]} + {bank_reg[2:0], 12'd0} + {2'd0, o13};
  end endfunction
  function [7:0] lane8; input [31:0] w; input [1:0] sel; begin
    lane8 = (sel==2'd0) ? w[7:0] : (sel==2'd1) ? w[15:8] : (sel==2'd2) ? w[23:16] : w[31:24];
  end endfunction
  function [12:0] ds_ptr_word; input [7:0] stream; begin
    ds_ptr_word = ds_base[14:2] + {5'd0, stream};
  end endfunction
  function [12:0] ds_inc_word; input [7:0] stream; begin
    ds_inc_word = ds_inc_base[14:2] + {5'd0, stream};
  end endfunction

  function [14:0] disp_byte_addr; input [31:0] ptr; reg [15:0] idx; begin
    idx = is_plus ? ptr[31:16] : {4'd0, ptr[31:20]};
    disp_byte_addr = 15'd2048 + idx[14:0];
  end endfunction
  function disp_ok; input [31:0] ptr; begin
    disp_ok = is_plus ? (ptr[31:16] < (RAM_DEPTH-2048)) : 1'b1;
  end endfunction

  function [14:0] wf_disp_byte; input [31:0] wfp; input [31:0] cnt; input [7:0] sz;
    reg [31:0] offw; reg [31:0] idx; begin
    offw = wfp - 32'h40000800;
    if (!is_plus && offw >= 32'd4096) offw = offw & 32'd4095;
    if (is_plus && offw >= (RAM_DEPTH-2048)) offw = 32'd0;
    idx = offw + (cnt >> sz[4:0]);
    wf_disp_byte = 15'd2048 + idx[14:0];
  end endfunction

  localparam [5:0]
    S_IDLE = 6'd0,
    S_R1   = 6'd1,  S_R2  = 6'd2,  S_DEC  = 6'd3,
    S_DS0  = 6'd4,  S_DS1 = 6'd5,  S_DS2  = 6'd6,  S_DS3 = 6'd7,
    S_DS4  = 6'd8,  S_DS5 = 6'd9,  S_DS6  = 6'd10,
    S_JP0  = 6'd11, S_JP1 = 6'd12, S_JP2  = 6'd13, S_JP3 = 6'd14,
    S_CW0  = 6'd15, S_CW1 = 6'd16, S_CW2  = 6'd17, S_CW3 = 6'd18,
    S_FF0  = 6'd19, S_FF1 = 6'd20, S_FF2  = 6'd21, S_FF3 = 6'd22,
    S_BG0  = 6'd23, S_BG1 = 6'd24, S_BG2  = 6'd25, S_BG3 = 6'd26,
    S_BG4  = 6'd27, S_BG5 = 6'd28, S_BG6  = 6'd29, S_BG7 = 6'd30,
    S_BG8  = 6'd31, S_BG9 = 6'd32,
    S_BGD0 = 6'd33, S_BGD1 = 6'd34, S_BGD2 = 6'd35, S_BGD3 = 6'd36,

    S_DWAIT = 6'd37,

    S_CWAIT = 6'd38;

  reg [5:0] state;

  reg        arsp_hold;
  reg [17:0] arsp_cnt;
  reg [17:0] cwait_cnt;
  reg [11:0] cwait_off;
  reg [7:0]  cwait_din;

  assign ds_wait = (state == S_DWAIT) || arsp_hold;

  assign cmd_hold = (state == S_CWAIT) && (cwait_cnt < CWAIT_BUDGET);

  reg [17:0] dwait_cnt;
  reg serving_fj;

  reg [7:0] serve_stream;
  reg [7:0] rb_lat, b1_lat;
  reg [31:0] ptr_lat, inc_lat;
  reg is_dsptr;
  reg [31:0] wf_lat [0:2];
  reg [7:0] samp_lat [0:1];
  reg [31:0] dig_addr;

  reg [7:0] rbv, normv, sv;
  reg [14:0] dba;
  reg hitv, jpmatch;

  task do_bank; input [11:0] o; begin
    case (o)
      12'hff4: bank_reg <= is_plus ? 4'd0 : 4'd6;
      12'hff5: bank_reg <= is_plus ? 4'd1 : 4'd0;
      12'hff6: bank_reg <= is_plus ? 4'd2 : 4'd1;
      12'hff7: bank_reg <= is_plus ? 4'd3 : 4'd2;
      12'hff8: bank_reg <= is_plus ? 4'd4 : 4'd3;
      12'hff9: bank_reg <= is_plus ? 4'd5 : 4'd4;
      12'hffa: bank_reg <= is_plus ? 4'd6 : 4'd5;
      12'hffb: bank_reg <= is_plus ? 4'd0 : 4'd6;
      default: ;
    endcase
  end endtask

  function ff_hit; input [7:0] b; begin
    ff_hit = fast_fetch_en && lda_valid && ({1'b0,off} == lda_addr) &&
             ((ff_offset != 16'd0) ? ((b >= ff_val) &&
                                      ({1'b0,b} <= ({1'b0,ff_val} + {1'b0,amp_stream})))
                                   : (b <= amp_stream));
  end endfunction
  function [7:0] ff_norm; input [7:0] b; begin
    ff_norm = (ff_offset != 16'd0) ? (b - ff_val) : b;
  end endfunction

  task peek_tail; input [7:0] b; begin
    lda_valid <= 1'b0;
    fj_operand <= 13'd0;
    do_bank(off);
    if (fast_fetch_en && (b == 8'hA9 ||
                          (ldx_en && b == 8'hA2) ||
                          (ldy_en && b == 8'hA0))) begin
      lda_valid <= 1'b1;
      lda_addr <= {1'b0,off} + 13'd1;
    end
    m6502_dout <= b;
  end endtask

  wire [14:0] pba_in = prog_byte_addr({1'b0, off_in});
  wire [14:0] pba_cur = prog_byte_addr({1'b0, off});
  wire [14:0] pba_p1 = prog_byte_addr({1'b0, off} + 13'd1);
  wire [14:0] pba_p2 = prog_byte_addr({1'b0, off} + 13'd2);

  integer k;
  always @(posedge clk) begin
    callfn <= 1'b0;
    harmony_we_b <= 1'b0;
    if (rst) begin
      state <= S_IDLE; addr_d <= 16'hFFFF; rwn_d <= 1'b1; dwait_cnt <= 18'd0;
      bank_reg <= {1'b0, start_bank}; mode_reg <= 8'hFF;
      lda_valid <= 0; lda_addr <= 0; fj_active <= 0; fj_operand <= 0; fj_stream <= 0;
      amp_cached <= 0; m6502_dout <= 0; mus_div <= 0; ff_val <= 0;
      off <= 0; din <= 0; serving_fj <= 0; serve_stream <= 0;
      rb_lat <= 0; b1_lat <= 0; ptr_lat <= 0; inc_lat <= 0; is_dsptr <= 0;
      dig_addr <= 0;
      rom_addr_b <= 0; harmony_addr_b <= 0; harmony_be_b <= 0; harmony_wdata_b <= 0;
      callfn_val <= 0;
      arsp_hold <= 1'b0; arsp_cnt <= 18'd0;
      cwait_cnt <= 18'd0; cwait_off <= 12'd0; cwait_din <= 8'd0;
      cb_ack <= 0; cb_ret <= 0;
      for (k = 0; k < 3; k = k + 1) begin
        music_freq[k] <= 32'd0; music_cnt[k] <= 32'd0; wave_size[k] <= 8'd27;
        wf_lat[k] <= 32'd0;
      end
      samp_lat[0] <= 0; samp_lat[1] <= 0;
    end else begin
      addr_d <= m6502_addr;
      rwn_d  <= m6502_rwn;

      if (mus_div == 10'd715) begin
        mus_div <= 0;
        for (k = 0; k < 3; k = k + 1) music_cnt[k] <= music_cnt[k] + music_freq[k];
      end else mus_div <= mus_div + 1'd1;

      if (cb_req && !cb_ack) begin
        cb_ack <= 1'b1;
        cb_ret <= 32'd0;
        if (cb_v1 < 3) begin
          case (cb_id)
            2'd0: music_freq[cb_v1[1:0]] <= cb_v2;
            2'd1: music_cnt[cb_v1[1:0]]  <= 32'd0;
            2'd2: cb_ret <= music_cnt[cb_v1[1:0]];
            2'd3: wave_size[cb_v1[1:0]]  <= cb_v2[7:0];
          endcase
        end
      end else if (!cb_req) cb_ack <= 1'b0;

      if (!arsp_hold) begin
        arsp_cnt <= 18'd0;
        if (ARSP_EN && (is_plus || !ARSP_PLUS_ONLY) &&
            trigger && !m6502_rwn && (off_in == 12'hff1) && arm_run_now)
          arsp_hold <= 1'b1;
      end else begin
        arsp_cnt <= arsp_cnt + 1'b1;
        if (!arm_run_now || arsp_cnt >= ARSP_BUDGET) arsp_hold <= 1'b0;
      end

      if (trigger) begin
        off <= off_in; din <= m6502_din;
        if (m6502_rwn) begin
          rom_addr_b <= pba_in[14:2];
          state <= S_R1;
        end else begin
          state <= S_IDLE;
          case (off_in)
            12'hff0, 12'hff1: begin

              if (CWAIT_EN && arm_run_any) begin
                cwait_off <= off_in; cwait_din <= m6502_din;
                cwait_cnt <= 18'd0;
                state <= S_CWAIT;
              end else begin
                harmony_addr_b <= ds_ptr_word(COMMSTREAM);
                is_dsptr <= (off_in == 12'hff1); state <= S_CW0;
              end
            end
            12'hff2: mode_reg <= m6502_din;
            12'hff3: begin callfn <= 1'b1; callfn_val <= m6502_din; end
            default: do_bank(off_in);
          endcase
        end
      end else begin
        case (state)

          S_IDLE: begin
            if (ff_offset != 16'd0) begin
              harmony_addr_b <= ff_offset[14:2];
              state <= S_FF0;
            end else state <= S_BG0;
          end

          S_R1: state <= S_DEC;
          S_R2: state <= S_DEC;
          S_DEC: begin
            rbv = lane8(rom_q_b, pba_cur[1:0]);
            rb_lat <= rbv;
            if (fj_active != 2'd0 && {1'b0,off} == fj_operand && fj_operand != 13'd0) begin

              serving_fj <= 1'b1;
              serve_stream <= fj_stream;
              fj_active <= fj_active - 1'd1;
              fj_operand <= fj_operand + 1'd1;
              harmony_addr_b <= ds_ptr_word(fj_stream);
              state <= S_DS0;
            end else if (fast_fetch_en && rbv == 8'h4C) begin

              rom_addr_b <= pba_p1[14:2];
              harmony_addr_b <= ds_ptr_word(ff_norm(rbv));
              m6502_dout <= rbv;
              state <= S_JP0;
            end else if (ff_hit(rbv)) begin

              lda_valid <= 1'b0;
              normv = ff_norm(rbv);
              if (normv == amp_stream) begin
                m6502_dout <= amp_cached;
                state <= S_IDLE;
              end else begin
                serving_fj <= 1'b0;
                serve_stream <= normv;
                harmony_addr_b <= ds_ptr_word(normv);

                dwait_cnt <= 18'd0;
                state <= (is_plus || !ds_wait_arm) ? S_DS0 : S_DWAIT;
              end
            end else begin
              peek_tail(rbv);
              state <= S_IDLE;
            end
          end

          S_DWAIT: begin
            harmony_addr_b <= ds_ptr_word(serve_stream);
            dwait_cnt <= dwait_cnt + 1'b1;

            if (!ds_wait_arm || dwait_cnt >= DWAIT_BUDGET ||
                dwait_cnt >= WAIT_MAX)                 state <= S_DS0;
            else                                       state <= S_DWAIT;
          end

          S_DS0: begin
            harmony_addr_b <= ds_inc_word(serve_stream);
            state <= S_DS2;
          end
          S_DS1: state <= S_DS2;
          S_DS2: begin
            ptr_lat <= harmony_q_b;
            dba = disp_byte_addr(harmony_q_b);
            harmony_addr_b <= dba[14:2];
            state <= S_DS3;
          end

          S_DS3: begin
            inc_lat <= harmony_q_b;
            harmony_addr_b <= ds_ptr_word(serve_stream);
            harmony_wdata_b <= serving_fj
              ? (ptr_lat + (is_plus ? 32'h00010000 : 32'h00100000))
              : (ptr_lat + (is_plus ? {harmony_q_b[23:0], 8'd0}
                                    : {harmony_q_b[19:0], 12'd0}));
            harmony_be_b <= 4'b1111; harmony_we_b <= 1'b1;
            state <= S_DS6;
          end

          S_DS4: begin
            harmony_addr_b <= ds_ptr_word(serve_stream);
            harmony_wdata_b <= serving_fj
              ? (ptr_lat + (is_plus ? 32'h00010000 : 32'h00100000))
              : (ptr_lat + (is_plus ? {inc_lat[23:0], 8'd0} : {inc_lat[19:0], 12'd0}));
            harmony_be_b <= 4'b1111; harmony_we_b <= 1'b1;
            state <= S_DS6;
          end
          S_DS5: state <= S_DS6;
          S_DS6: begin
            dba = disp_byte_addr(ptr_lat);
            m6502_dout <= disp_ok(ptr_lat) ? lane8(harmony_q_b, dba[1:0]) : 8'd0;
            state <= S_IDLE;
          end

          S_JP0: begin
            rom_addr_b <= pba_p2[14:2];
            harmony_addr_b <= ds_inc_word(ff_norm(rb_lat));
            state <= S_JP2;
          end
          S_JP1: state <= S_JP2;
          S_JP2: begin
            b1_lat <= lane8(rom_q_b, pba_p1[1:0]);
            ptr_lat <= harmony_q_b;
            state <= S_JP3;
          end
          S_JP3: begin
            jpmatch = ((b1_lat & jump_mask) == 8'd0) &&
                      (lane8(rom_q_b, pba_p2[1:0]) == 8'd0);
            if (jpmatch) begin
              fj_active <= 2'd2;
              fj_operand <= {1'b0,off} + 13'd1;
              fj_stream <= b1_lat + JUMPSTREAM_BASE;

              state <= S_IDLE;
            end else if (ff_hit(rb_lat)) begin

              lda_valid <= 1'b0;
              normv = ff_norm(rb_lat);
              if (normv == amp_stream) begin
                m6502_dout <= amp_cached;
                state <= S_IDLE;
              end else begin
                inc_lat <= harmony_q_b;
                dba = disp_byte_addr(ptr_lat);
                harmony_addr_b <= dba[14:2];
                serving_fj <= 1'b0;
                serve_stream <= normv;
                state <= S_DS4;
              end
            end else begin
              peek_tail(rb_lat);
              state <= S_IDLE;
            end
          end

          S_CWAIT: begin
            cwait_cnt <= cwait_cnt + 1'b1;
            if (!arm_run_any || cwait_cnt >= CWAIT_BUDGET) begin
              off <= cwait_off; din <= cwait_din;
              harmony_addr_b <= ds_ptr_word(COMMSTREAM);
              is_dsptr <= (cwait_off == 12'hff1);
              state <= S_CW0;
            end
          end
          S_CW0: state <= S_CW2;
          S_CW1: state <= S_CW2;
          S_CW2: begin
            ptr_lat <= harmony_q_b;
            if (is_dsptr) begin
              harmony_addr_b <= ds_ptr_word(COMMSTREAM);
              harmony_wdata_b <= is_plus
                ? (({harmony_q_b[23:0], 8'd0} & 32'hff000000) | {8'd0, din, 16'd0})
                : (({harmony_q_b[23:0], 8'd0} & 32'hf0000000) | {4'd0, din, 20'd0});
              harmony_be_b <= 4'b1111; harmony_we_b <= 1'b1;
              state <= S_IDLE;
            end else begin
              if (disp_ok(harmony_q_b)) begin
                dba = disp_byte_addr(harmony_q_b);
                harmony_addr_b <= dba[14:2];
                harmony_wdata_b <= {4{din}};
                harmony_be_b <= 4'b0001 << dba[1:0];
                harmony_we_b <= 1'b1;
              end
              state <= S_CW3;
            end
          end
          S_CW3: begin
            harmony_addr_b <= ds_ptr_word(COMMSTREAM);
            harmony_wdata_b <= ptr_lat + (is_plus ? 32'h00010000 : 32'h00100000);
            harmony_be_b <= 4'b1111; harmony_we_b <= 1'b1;
            state <= S_IDLE;
          end

          S_FF0: state <= S_FF2;
          S_FF1: state <= S_FF2;
          S_FF2: begin
            ff_val <= lane8(harmony_q_b, ff_offset[1:0]);
            state <= S_BG0;
          end
          S_FF3: state <= S_BG0;

          S_BG0: begin harmony_addr_b <= wf_base[14:2];          state <= S_BG1; end
          S_BG1: begin harmony_addr_b <= wf_base[14:2] + 13'd1;  state <= S_BG2; end
          S_BG2: begin
            wf_lat[0] <= harmony_q_b;
            harmony_addr_b <= wf_base[14:2] + 13'd2;
            state <= S_BG3;
          end
          S_BG3: begin
            wf_lat[1] <= harmony_q_b;
            if (digital_audio_en) begin
              dig_addr <= wf_lat[0] + (music_cnt[0] >> (is_plus ? 5'd13 : 5'd21));
              state <= S_BGD0;
            end else begin
              dba = wf_disp_byte(wf_lat[0], music_cnt[0], wave_size[0]);
              harmony_addr_b <= dba[14:2];
              state <= S_BG4;
            end
          end
          S_BG4: begin
            wf_lat[2] <= harmony_q_b;
            dba = wf_disp_byte(wf_lat[1], music_cnt[1], wave_size[1]);
            harmony_addr_b <= dba[14:2];
            state <= S_BG5;
          end
          S_BG5: begin
            dba = wf_disp_byte(wf_lat[0], music_cnt[0], wave_size[0]);
            samp_lat[0] <= lane8(harmony_q_b, dba[1:0]);
            dba = wf_disp_byte(wf_lat[2], music_cnt[2], wave_size[2]);
            harmony_addr_b <= dba[14:2];
            state <= S_BG6;
          end
          S_BG6: begin
            dba = wf_disp_byte(wf_lat[1], music_cnt[1], wave_size[1]);
            samp_lat[1] <= lane8(harmony_q_b, dba[1:0]);
            state <= S_BG7;
          end
          S_BG7: begin
            dba = wf_disp_byte(wf_lat[2], music_cnt[2], wave_size[2]);
            amp_cached <= samp_lat[0] + samp_lat[1] + lane8(harmony_q_b, dba[1:0]);
            state <= S_IDLE;
          end
          S_BG8: state <= S_IDLE;
          S_BG9: state <= S_IDLE;

          S_BGD0: begin

            if (dig_addr < {13'd0, rom_bytes}) begin
              rom_addr_b <= dig_addr[16:2];
              state <= S_BGD1;
            end else if (dig_addr[31:28] == 4'h4) begin

              harmony_addr_b <= dig_addr[14:2];
              state <= S_BGD1;
            end else begin
              amp_cached <= 8'd0;
              state <= S_IDLE;
            end
          end
          S_BGD1: state <= S_BGD3;
          S_BGD2: state <= S_BGD3;
          S_BGD3: begin

            sv = (dig_addr < {13'd0, rom_bytes}) ? lane8(rom_q_b, dig_addr[1:0])
                                                 : lane8(harmony_q_b, dig_addr[1:0]);
            if ((music_cnt[0] & (32'd1 << (is_plus ? 5'd12 : 5'd20))) == 32'd0) sv = sv >> 4;
            amp_cached <= sv & 8'h0F;
            state <= S_IDLE;
          end

          default: state <= S_IDLE;
        endcase
      end
    end
  end

  reg arm_p1; reg [3:0] arm_region_d;
  reg  bus_ack_r;
  wire bus_first = bus_req && !arm_p1 && !bus_ack_r;

  reg [31:0] pre_addr_d;
  reg        pre_armed_d;
  always @(posedge clk_vid) begin
    if (rst_vid) begin pre_armed_d <= 1'b0; pre_addr_d <= 32'd0; end
    else         begin pre_armed_d <= bus_req_pre; pre_addr_d <= bus_addr_pre; end
  end
  wire pre_hit = bus_req && pre_armed_d && !bus_we &&
                 (bus_addr[31:28] == 4'h4) &&
                 (pre_addr_d == {bus_addr[31:2], 2'b00});
  assign bus_ack = (bus_we || pre_hit) ? bus_first : bus_ack_r;
  reg [31:0] t1tcr, t1tc, systick_ctrl, systick_reload, systick_count, mamcr;
  reg [31:0] periph_rdata;
  always @(posedge clk_vid) begin
    if (rst_vid) begin
      arm_p1 <= 0; bus_ack_r <= 0; arm_region_d <= 0;
      t1tcr <= 0; t1tc <= 0; systick_ctrl <= 32'h4; systick_reload <= 0;
      systick_count <= 0; mamcr <= 0; periph_rdata <= 0;
    end else begin
      if (t1tcr[0]) t1tc <= t1tc + 1'd1;
      if (systick_ctrl[0]) begin
        if (systick_count == 0) systick_count <= systick_reload;
        else systick_count <= systick_count - 1'd1;
      end

      bus_ack_r <= bus_first && !bus_we && !pre_hit;
      arm_p1 <= 1'b0;
      if (bus_first) begin
        arm_region_d <= bus_addr[31:28];

        if (bus_we) begin
          if      (bus_addr == 32'hE0008004) t1tcr <= bus_wdata;
          else if (bus_addr == 32'hE0008008) t1tc <= bus_wdata;
          else if (bus_addr == 32'hE000E010) systick_ctrl <= {systick_ctrl[31:17], bus_wdata[16], systick_ctrl[15:3], bus_wdata[2:0]};
          else if (bus_addr == 32'hE000E014) systick_reload <= bus_wdata & 32'h00FFFFFF;
          else if (bus_addr == 32'hE000E018) systick_count <= bus_wdata & 32'h00FFFFFF;
          else if (bus_addr == 32'hE01FC000) mamcr <= bus_wdata;
        end else begin
          if      (bus_addr == 32'hE0008004) periph_rdata <= t1tcr;
          else if (bus_addr == 32'hE0008008) periph_rdata <= t1tc;
          else if (bus_addr == 32'hE000E010) periph_rdata <= systick_ctrl;
          else if (bus_addr == 32'hE000E014) periph_rdata <= systick_reload;
          else if (bus_addr == 32'hE000E018) periph_rdata <= systick_count;
          else if (bus_addr == 32'hE01FC000) periph_rdata <= mamcr;
          else                                periph_rdata <= 32'd0;
        end
      end
    end
  end

  wire [3:0] region_now = pre_hit ? 4'h4 : arm_region_d;
  assign bus_rdata = (region_now == 4'h0) ? rom_q_a :
                     (region_now == 4'h4) ? harmony_q_a : periph_rdata;

  assign bus_rdata_next    = rom_q_a_next;
  assign bus_rdata_next_ok = (arm_region_d == 4'h0);

endmodule
`default_nettype wire

