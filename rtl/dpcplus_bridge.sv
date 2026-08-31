`default_nettype none
module dpcplus_bridge #(
  parameter ROM_FILE = "", parameter RAM_FILE = ""
)(
  input  wire        clk,

  input  wire        clk_vid,
  input  wire        rst,
  input  wire [15:0] m6502_addr,
  input  wire [7:0]  m6502_din,
  input  wire        m6502_rwn,
  output reg  [7:0]  m6502_dout,
  output wire [14:0] rom_a,
  output reg         callfn,
  output reg  [7:0]  callfn_val,
  input  wire        rom_load_we,
  input  wire [14:0] rom_load_addr,
  input  wire [7:0]  rom_load_data,

  output wire [12:0] rom_addr_a_o,
  input  wire [31:0] rom_q_a_i,
  output wire [14:0] rom_addr_b_o,
  input  wire  [7:0] rom_q_b_i,

  input  wire        rst_vid,
  input  wire [31:0] bus_addr,
  input  wire [31:0] bus_wdata,
  output wire [31:0] bus_rdata,
  input  wire [3:0]  bus_be,
  input  wire        bus_we,
  input  wire        bus_req,
  output wire        bus_ack,

  input  wire [31:0] bus_addr_pre,
  input  wire        bus_req_pre,
  output wire [2:0]  dbg_bank,
  output wire [7:0]  dbg_ff
);

  localparam [15:0] PROG_SIZE = 16'd29696;
  localparam [12:0] DISP_SIZE = 13'd4096;
  localparam [14:0] PROG_BASE = 15'd3072;
  localparam [12:0] DISP_BASE = 13'd3072;

  wire [31:0] arm_ram_q;

  wire       arm_is_ram = (bus_addr[31:28] == 4'h4);

  wire [31:0] arm_addr_eff = bus_req_pre ? bus_addr_pre : bus_addr;

  wire       arm_is_periph = (bus_addr[31:28] == 4'hE);

  reg  [14:0] rom_addr_r;

  assign rom_addr_a_o = bus_addr[14:2];
  assign rom_addr_b_o = rom_addr_r;
  wire [31:0] arm_rom_q = rom_q_a_i;
  wire  [7:0] rom_q     = rom_q_b_i;

  wire arm_wr_word = bus_req & bus_we & arm_is_ram & ~bus_ack_r;

  localparam [14:0] DPCRAM_ZERO_BYTES = 15'd8192;
  localparam [14:0] DISP_SRC_BASE     = 15'd27648;
  wire        ram_init_copy = rom_load_we && (rom_load_addr >= DISP_SRC_BASE);
  wire        ram_init_zero = rom_load_we && (rom_load_addr <  DPCRAM_ZERO_BYTES);
  wire        ram_init_we   = ram_init_zero | ram_init_copy;
  wire [12:0] ram_init_addr = rom_load_addr[12:0];
  wire [7:0]  ram_init_data = ram_init_copy ? rom_load_data : 8'd0;

  localparam [14:0] DRIVER_BYTES = 15'd3072;

  localparam [31:0] CRC_DRIVER_STABLE_A = 32'hA45A045F;
  localparam [31:0] CRC_DRIVER_STABLE_B = 32'h5F942217;

  function [31:0] crc32_byte;
    input [31:0] c; input [7:0] d;
    integer n; reg [31:0] x;
    begin
      x = c ^ {24'd0, d};
      for (n = 0; n < 8; n = n + 1)
        x = x[0] ? ((x >> 1) ^ 32'hEDB88320) : (x >> 1);
      crc32_byte = x;
    end
  endfunction

  reg [31:0] drv_crc;
  always @(posedge clk) begin
    if (rom_load_we) begin
      if (rom_load_addr == 15'd0)          drv_crc <= crc32_byte(32'hFFFFFFFF, rom_load_data);
      else if (rom_load_addr < DRIVER_BYTES) drv_crc <= crc32_byte(drv_crc, rom_load_data);
    end
  end
  wire frac_stable = ((~drv_crc) == CRC_DRIVER_STABLE_A) ||
                     ((~drv_crc) == CRC_DRIVER_STABLE_B);

  reg  [12:0] ram_addr_a; reg [7:0] ram_wdata_a; reg ram_we_a;
  wire [7:0]  ram_q_a;
  dpcp_ram_m10k #(.INIT_FILE(RAM_FILE)) ram_i (
    .clk_a(clk_vid), .addr_a(arm_addr_eff[12:2]), .data_a(bus_wdata),
    .be_a(bus_be), .wren_a(arm_wr_word), .q_a(arm_ram_q),
    .clk_b(clk),
    .addr_b (ram_init_we ? ram_init_addr : ram_addr_a),
    .data_b (ram_init_we ? ram_init_data : ram_wdata_a),
    .wren_b (ram_init_we | ram_we_a),
    .q_b    (ram_q_a)
  );

  reg        arm_p1;
  reg [3:0]  arm_region_d;

  reg        bus_ack_r;
  reg [31:0] pre_addr_d;
  reg        pre_armed_d;
  always @(posedge clk_vid) begin
    if (rst_vid) begin pre_armed_d <= 1'b0; pre_addr_d <= 32'd0; end
    else         begin pre_armed_d <= bus_req_pre; pre_addr_d <= bus_addr_pre; end
  end
  wire pre_hit = bus_req && pre_armed_d && !bus_we &&
                 (bus_addr[31:28] == 4'h4) &&
                 (pre_addr_d == {bus_addr[31:2], 2'b00});
  wire bus_first = bus_req && !arm_p1 && !bus_ack_r;
  assign bus_ack = pre_hit ? bus_first : bus_ack_r;
  reg [31:0] t1tcr, t1tc, systick_ctrl, systick_reload, systick_count, mamcr;
  reg [31:0] periph_rdata;
  always @(posedge clk_vid) begin
    if (rst_vid) begin
      bus_ack_r <= 1'b0; arm_p1 <= 1'b0; arm_region_d <= 4'd0;
      periph_rdata <= 32'd0;
      t1tcr <= 32'd0; t1tc <= 32'd0; mamcr <= 32'd0;
      systick_ctrl <= 32'h4; systick_reload <= 32'd0; systick_count <= 32'd0;
    end else begin

      if (t1tcr[0]) t1tc <= t1tc + 1'd1;
      if (systick_ctrl[0]) begin
        if (systick_count == 32'd0) systick_count <= systick_reload;
        else                        systick_count <= systick_count - 1'd1;
      end

      bus_ack_r <= bus_first && !pre_hit;
      arm_p1  <= 1'b0;
      if (bus_first) begin
        arm_region_d <= bus_addr[31:28];
        if (arm_is_periph) begin

          if (bus_we) begin
            if      (bus_addr == 32'hE0008004) t1tcr <= bus_wdata;
            else if (bus_addr == 32'hE0008008) t1tc  <= bus_wdata;
            else if (bus_addr == 32'hE000E010) systick_ctrl <= {systick_ctrl[31:17], bus_wdata[16], systick_ctrl[15:3], bus_wdata[2:0]};
            else if (bus_addr == 32'hE000E014) systick_reload <= bus_wdata & 32'h00FFFFFF;
            else if (bus_addr == 32'hE000E018) systick_count  <= bus_wdata & 32'h00FFFFFF;
            else if (bus_addr == 32'hE01FC000) mamcr <= bus_wdata;
          end else begin
            if      (bus_addr == 32'hE0008004) periph_rdata <= t1tcr;
            else if (bus_addr == 32'hE0008008) periph_rdata <= t1tc;
            else if (bus_addr == 32'hE000E010) periph_rdata <= systick_ctrl;
            else if (bus_addr == 32'hE000E014) periph_rdata <= systick_reload;
            else if (bus_addr == 32'hE000E018) periph_rdata <= systick_count;
            else if (bus_addr == 32'hE01FC000) periph_rdata <= mamcr;
            else                               periph_rdata <= 32'd0;
          end
        end
      end
    end
  end

  wire [3:0] region_now = pre_hit ? 4'h4 : arm_region_d;
  assign bus_rdata = (region_now == 4'h0) ? arm_rom_q :
                     (region_now == 4'h4) ? arm_ram_q : periph_rdata;

  reg [7:0]  tops [0:7];
  reg [7:0]  bots [0:7];
  reg [11:0] cnt  [0:7];
  reg [19:0] fcnt [0:7];
  reg [7:0]  finc [0:7];
  reg [2:0]  bank_reg;
  reg        fast_fetch;
  reg        lda_imm;
  reg [3:0]  param_ptr;
  reg [7:0]  param [0:7];

  assign dbg_bank = bank_reg;

  assign dbg_ff   = {3'd0, pend_idx, lda_imm, fast_fetch};
  assign rom_a    = rom_addr_r;

  wire        cs      = (m6502_addr[15:12] == 4'h1);
  wire [11:0] off     = m6502_addr[11:0];
  reg  [15:0] addr_d;
  reg         rwn_d;

`ifdef DPCP_OLD_TRIGGER

  wire        trigger = cs && (m6502_addr != addr_d);
`else
  wire        trigger = cs && ((m6502_addr != addr_d) || (m6502_rwn != rwn_d));
`endif

  wire [2:0] w_index = off[2:0];
  wire [3:0] w_func  = off[6:3] - 4'd5;
  wire       is_reg_w = (off >= 12'h028) && (off < 12'h080);
  wire       is_hot   = (off >= 12'hFF6) && (off <= 12'hFFB);

  reg [11:0] off_l;
  wire is_hot_l = (off_l >= 12'hFF6) && (off_l <= 12'hFFB);

  function [8:0] cp_limit;
    input [15:0] src; input [11:0] dst; input [7:0] n;
    reg [15:0] lr; reg [12:0] ld; reg [8:0] r;
    begin

      lr = PROG_SIZE - src;
      ld = DISP_SIZE - {1'b0, dst};
      r  = {1'b0, n};
      if (lr < {7'd0, r})         r = lr[8:0];
      if ({3'd0, ld} < {7'd0, r}) r = ld[8:0];
      cp_limit = (src >= PROG_SIZE || {1'b0, dst} >= DISP_SIZE) ? 9'd0 : r;
    end
  endfunction

  function [8:0] cp_limit_fill;
    input [11:0] dst; input [7:0] n;
    reg [12:0] ld; reg [8:0] r;
    begin

      ld = DISP_SIZE - {1'b0, dst};
      r  = {1'b0, n};
      if ({3'd0, ld} < {7'd0, r}) r = ld[8:0];
      cp_limit_fill = ({1'b0, dst} >= DISP_SIZE) ? 9'd0 : r;
    end
  endfunction

  reg        cp_busy, cp_isrom;
  reg [15:0] cp_src;
  reg [11:0] cp_dst;
  reg [8:0]  cp_len, cp_rd, cp_wr;
  reg [7:0]  cp_val;

  reg  [31:0] rng;
  wire [31:0] rng_x    = 32'h10adab1e ^ rng;
  wire [31:0] rng_next = (rng[10] ? 32'h10adab1e : 32'd0) ^ {rng[10:0], rng[31:11]};
  wire [31:0] rng_prev = rng[31] ? {rng_x[20:0], rng_x[31:21]}
                                 : {rng[20:0],   rng[31:21]};

  localparam [12:0] FREQ_BASE = 13'd7168;
  localparam [24:0] OSC_DIV   = 25'd14318181;
  localparam [24:0] OSC_INC   = 25'd20000;

  reg [6:0]  mus_wave [0:2];
  reg [31:0] mus_freq [0:2];
  reg [31:0] mus_cnt  [0:2];
  reg [7:0]  mus_amp;
  reg [24:0] osc_acc;
  wire       osc_tick = (osc_acc >= OSC_DIV);

  reg        mus_busy;
  reg [1:0]  mus_ch;
  reg [2:0]  mus_ph;
  reg [7:0]  mus_sum;
  reg [31:0] mus_tmp;
  reg [1:0]  mus_nb;
  reg [7:0]  mus_nval;
  reg        note_pend;
  reg [1:0]  note_ch;

  wire [11:0] amp_idx = {mus_wave[mus_ch], 5'd0} + {7'd0, mus_cnt[mus_ch][31:27]};

  localparam [2:0] S_IDLE=3'd0, S_R1=3'd1, S_R2=3'd2, S_RD=3'd3,
                   S_M1=3'd4,   S_M2=3'd5, S_MD=3'd6;
  reg [2:0] state;

  reg [2:0] pend_fn, pend_idx;
  reg [7:0] pend_flag;

  wire       ff_redir = fast_fetch && lda_imm && (rom_q < 8'h28);
  wire [7:0] eff_addr = ff_redir ? rom_q : off_l[7:0];
  wire       eff_isreg = ff_redir || (off_l < 12'h028);
  wire [2:0] eff_idx  = eff_addr[2:0];
  wire [2:0] eff_fn   = eff_addr[5:3];

  integer i;
  always @(posedge clk) begin
    ram_we_a <= 1'b0;
    callfn   <= 1'b0;

    if (rst) begin
      state <= S_IDLE; addr_d <= 16'hFFFF; rwn_d <= 1'b1; bank_reg <= 3'd5;
      fast_fetch <= 1'b0; lda_imm <= 1'b0; param_ptr <= 4'd0;
      m6502_dout <= 8'd0; cp_busy <= 1'b0;
      rng <= 32'h2B435044;
      osc_acc <= 25'd0; mus_amp <= 8'd0; mus_busy <= 1'b0; note_pend <= 1'b0;
      mus_ph <= 3'd0; mus_ch <= 2'd0; mus_sum <= 8'd0;
      mus_nb <= 2'd0; mus_tmp <= 32'd0; mus_nval <= 8'd0; note_ch <= 2'd0;
      for (i = 0; i < 3; i = i + 1) begin
        mus_wave[i] <= 7'd0; mus_freq[i] <= 32'd0; mus_cnt[i] <= 32'd0;
      end
      for (i = 0; i < 8; i = i + 1) begin
        tops[i] <= 8'd0; bots[i] <= 8'd0; cnt[i] <= 12'd0;
        fcnt[i] <= 20'd0; finc[i] <= 8'd0;
      end
    end else begin

      if (osc_tick) begin
        osc_acc <= osc_acc - OSC_DIV + OSC_INC;
        for (i = 0; i < 3; i = i + 1) mus_cnt[i] <= mus_cnt[i] + mus_freq[i];
        if (!mus_busy) begin
          mus_busy <= 1'b1;
          mus_ch <= 2'd0; mus_ph <= 3'd0; mus_sum <= 8'd0;
        end
      end else osc_acc <= osc_acc + OSC_INC;

      if (trigger) begin addr_d <= m6502_addr; rwn_d <= m6502_rwn; end

      if (trigger && mus_busy) mus_ph <= 3'd0;

      if (trigger && m6502_rwn) begin

        off_l      <= off;
        rom_addr_r <= PROG_BASE + {bank_reg, 12'd0} + {3'd0, off};
        if (cp_busy) cp_rd <= cp_wr;
        state <= S_R1;
      end

      else if (trigger && !m6502_rwn) begin
        if (is_reg_w) begin
          case (w_func)

            4'd0: fcnt[w_index] <= frac_stable
                    ? {fcnt[w_index][19:16], m6502_din, 8'd0}
                    : {fcnt[w_index][19:16], m6502_din, fcnt[w_index][7:0]};
            4'd1: fcnt[w_index] <= {m6502_din[3:0], fcnt[w_index][15:0]};
            4'd2: begin finc[w_index] <= m6502_din;
                        fcnt[w_index] <= {fcnt[w_index][19:8], 8'd0}; end
            4'd3: tops[w_index] <= m6502_din;
            4'd4: bots[w_index] <= m6502_din;
            4'd5: cnt[w_index]  <= {cnt[w_index][11:8], m6502_din};
            4'd6: case (w_index)
                    3'd0: fast_fetch <= (m6502_din == 8'd0);
                    3'd1: if (param_ptr < 4'd8) begin
                            param[param_ptr[2:0]] <= m6502_din;
                            param_ptr <= param_ptr + 4'd1;
                          end
                    3'd2: begin

                            case (m6502_din)
                              8'd0: param_ptr <= 4'd0;
                              8'd1, 8'd2: begin

                                param_ptr <= 4'd0;
                                if (!cp_busy) begin
                                  cp_isrom <= (m6502_din == 8'd1);
                                  cp_src   <= {param[1], param[0]};
                                  cp_dst   <= cnt[param[2][2:0]];
                                  cp_val   <= param[0];
                                  cp_rd    <= 9'd0; cp_wr <= 9'd0;
                                  cp_len   <= (m6502_din == 8'd1)
                                    ? cp_limit({param[1], param[0]},
                                               cnt[param[2][2:0]], param[3])
                                    : cp_limit_fill(cnt[param[2][2:0]], param[3]);
                                  cp_busy  <= 1'b1;
                                end
                              end
                              8'hFE, 8'hFF: begin
                                callfn <= 1'b1; callfn_val <= m6502_din;
                              end
                              default: ;
                            endcase
                          end
                    3'd5, 3'd6, 3'd7:
                      mus_wave[w_index - 3'd5] <= m6502_din[6:0];
                    default: ;
                  endcase
            4'd7: begin
                    cnt[w_index] <= cnt[w_index] - 12'd1;
                    ram_addr_a  <= DISP_BASE + {1'b0, cnt[w_index] - 12'd1};
                    ram_wdata_a <= m6502_din; ram_we_a <= 1'b1;
                  end
            4'd8: cnt[w_index] <= {m6502_din[3:0], cnt[w_index][7:0]};
            4'd9: case (w_index)
                    3'd0: rng <= 32'h2B435044;
                    3'd1: rng <= {rng[31:8],  m6502_din};
                    3'd2: rng <= {rng[31:16], m6502_din, rng[7:0]};
                    3'd3: rng <= {rng[31:24], m6502_din, rng[15:0]};
                    3'd4: rng <= {m6502_din,  rng[23:0]};
                    3'd5, 3'd6, 3'd7: begin
                      note_pend <= 1'b1;
                      note_ch   <= w_index[1:0] - 2'd1;
                      mus_nval  <= m6502_din;
                      mus_nb    <= 2'd0;

                      mus_ph    <= 3'd0; mus_ch <= 2'd0; mus_sum <= 8'd0;
                    end
                    default: ;
                  endcase
            4'd10: begin
                    ram_addr_a  <= DISP_BASE + {1'b0, cnt[w_index]};
                    ram_wdata_a <= m6502_din; ram_we_a <= 1'b1;
                    cnt[w_index] <= cnt[w_index] + 12'd1;
                  end
            default: ;
          endcase
          if (cp_busy) cp_rd <= cp_wr;
          state <= S_IDLE;
        end else begin
          if (is_hot) bank_reg <= off[2:0] - 3'd6;
          state <= S_IDLE;
        end
      end

      else begin
        case (state)
          S_R1: state <= S_R2;
          S_R2: state <= S_RD;
          S_RD: begin
            lda_imm <= 1'b0;
            if (eff_isreg) begin
              pend_idx <= eff_idx; pend_fn <= eff_fn;
              case (eff_fn)
                3'd1, 3'd2: begin
                  ram_addr_a <= DISP_BASE + {1'b0, cnt[eff_idx]};

                  pend_flag <= (((tops[eff_idx] - cnt[eff_idx][7:0]) >
                                 (tops[eff_idx] - bots[eff_idx])) ? 8'hFF : 8'h00);
                  cnt[eff_idx] <= cnt[eff_idx] + 12'd1;
                  state <= S_M1;
                end
                3'd3: begin
                  ram_addr_a <= DISP_BASE + {1'b0, fcnt[eff_idx][19:8]};
                  fcnt[eff_idx] <= fcnt[eff_idx] + {12'd0, finc[eff_idx]};
                  state <= S_M1;
                end
                3'd4: begin
                  m6502_dout <= (eff_idx < 3'd4) ?
                    (((tops[eff_idx] - cnt[eff_idx][7:0]) >
                      (tops[eff_idx] - bots[eff_idx])) ? 8'hFF : 8'h00) : 8'd0;
                  state <= S_IDLE;
                end
                3'd0: begin

                  case (eff_idx)
                    3'd0: begin rng <= rng_next; m6502_dout <= rng_next[7:0]; end
                    3'd1: begin rng <= rng_prev; m6502_dout <= rng_prev[7:0]; end
                    3'd2: m6502_dout <= rng[15:8];
                    3'd3: m6502_dout <= rng[23:16];
                    3'd4: m6502_dout <= rng[31:24];
                    3'd5: m6502_dout <= mus_amp;
                    default: m6502_dout <= 8'd0;
                  endcase
                  state <= S_IDLE;
                end
                default: begin
                  m6502_dout <= 8'd0;
                  state <= S_IDLE;
                end
              endcase
            end else begin
              m6502_dout <= rom_q;
              if (is_hot_l) bank_reg <= off_l[2:0] - 3'd6;
              if (fast_fetch) lda_imm <= (rom_q == 8'hA9);
              state <= S_IDLE;
            end
          end
          S_M1: state <= S_M2;
          S_M2: state <= S_MD;
          S_MD: begin
            m6502_dout <= (pend_fn == 3'd2) ? (ram_q_a & pend_flag) : ram_q_a;
            state <= S_IDLE;
          end

          default: begin
          if (cp_busy) begin

            if (cp_isrom) begin

              if (cp_rd < cp_len + 9'd3) cp_rd <= cp_rd + 9'd1;
              if (cp_rd < cp_len)
                rom_addr_r <= PROG_BASE + cp_src[14:0] + {6'd0, cp_rd};
              if ((cp_rd >= cp_wr + 9'd3) && (cp_wr < cp_len)) begin
                ram_addr_a  <= DISP_BASE + {1'b0, cp_dst} + {4'd0, cp_wr};
                ram_wdata_a <= rom_q; ram_we_a <= 1'b1;
                cp_wr <= cp_wr + 9'd1;
              end
            end else begin
              if (cp_wr < cp_len) begin
                ram_addr_a  <= DISP_BASE + {1'b0, cp_dst} + {4'd0, cp_wr};
                ram_wdata_a <= cp_val; ram_we_a <= 1'b1;
                cp_wr <= cp_wr + 9'd1;
              end
            end
            if (cp_wr >= cp_len) cp_busy <= 1'b0;
          end

          else if (note_pend) begin
            case (mus_ph)
              3'd0: begin
                ram_addr_a <= FREQ_BASE + {3'd0, mus_nval, 2'd0} + {11'd0, mus_nb};
                mus_ph <= 3'd1;
              end
              3'd3: begin
                case (mus_nb)
                  2'd0: mus_tmp[7:0]   <= ram_q_a;
                  2'd1: mus_tmp[15:8]  <= ram_q_a;
                  2'd2: mus_tmp[23:16] <= ram_q_a;
                  default: begin
                    mus_freq[note_ch] <= {ram_q_a, mus_tmp[23:0]};
                    note_pend <= 1'b0;
                  end
                endcase
                mus_nb <= mus_nb + 2'd1;
                mus_ph <= 3'd0;
              end
              default: mus_ph <= mus_ph + 3'd1;
            endcase
          end
          else if (mus_busy) begin
            case (mus_ph)
              3'd0: begin
                ram_addr_a <= DISP_BASE + {1'b0, amp_idx};
                mus_ph <= 3'd1;
              end
              3'd3: begin
                if (mus_ch == 2'd2) begin
                  mus_amp  <= mus_sum + ram_q_a;
                  mus_busy <= 1'b0;
                end else begin
                  mus_sum <= mus_sum + ram_q_a;
                  mus_ch  <= mus_ch + 2'd1;
                end
                mus_ph <= 3'd0;
              end
              default: mus_ph <= mus_ph + 3'd1;
            endcase
          end
          end
        endcase
      end
    end
  end

endmodule

module dpcp_rom_m10k #(parameter INIT_FILE = "")(
  input  wire        clk_a,
  input  wire [12:0] addr_a,
  output wire [31:0] q_a,
  input  wire        clk_b,
  input  wire [14:0] addr_b,
  input  wire [7:0]  data_b,
  input  wire        wren_b,
  output wire [7:0]  q_b
);
  altsyncram #(
    .intended_device_family("Cyclone V"), .lpm_type("altsyncram"),
    .operation_mode("BIDIR_DUAL_PORT"), .ram_block_type("M10K"),
    .width_a(32), .widthad_a(13), .numwords_a(8192),  .width_byteena_a(1),
    .width_b(8),  .widthad_b(15), .numwords_b(32768), .width_byteena_b(1),

    .outdata_reg_a("UNREGISTERED"),
    .outdata_reg_b("CLOCK1"), .address_reg_b("CLOCK1"), .indata_reg_b("CLOCK1"),
    .wrcontrol_wraddress_reg_b("CLOCK1"), .byteena_reg_b("CLOCK1"),
    .read_during_write_mode_port_a("DONT_CARE"),
    .read_during_write_mode_port_b("DONT_CARE"),
    .read_during_write_mode_mixed_ports("DONT_CARE"),
    .power_up_uninitialized("FALSE"), .init_file(INIT_FILE)
  ) ram_i (
    .clock0(clk_a), .clock1(clk_b),
    .address_a(addr_a), .data_a(32'd0), .byteena_a(1'b1), .wren_a(1'b0),  .q_a(q_a),
    .address_b(addr_b), .data_b(data_b), .byteena_b(1'b1), .wren_b(wren_b), .q_b(q_b),
    .aclr0(1'b0), .aclr1(1'b0), .addressstall_a(1'b0), .addressstall_b(1'b0),
    .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
    .rden_a(1'b1), .rden_b(1'b1), .eccstatus()
  );
endmodule

module dpcp_ram_m10k #(parameter INIT_FILE = "")(
  input  wire        clk_a,
  input  wire [10:0] addr_a,
  input  wire [31:0] data_a,
  input  wire [3:0]  be_a,
  input  wire        wren_a,
  output wire [31:0] q_a,
  input  wire        clk_b,
  input  wire [12:0] addr_b,
  input  wire [7:0]  data_b,
  input  wire        wren_b,
  output wire [7:0]  q_b
);
  wire [31:0] qa_all, qb_all;
  assign q_a = qa_all;

  reg [1:0] selb1, selb2;
  always @(posedge clk_b) begin selb1 <= addr_b[1:0]; selb2 <= selb1; end
  assign q_b = qb_all[selb2*8 +: 8];

  genvar g;
  generate for (g = 0; g < 4; g = g + 1) begin : lane
    altsyncram #(
      .intended_device_family("Cyclone V"), .lpm_type("altsyncram"),
      .operation_mode("BIDIR_DUAL_PORT"), .ram_block_type("M10K"),
      .width_a(8), .widthad_a(11), .numwords_a(2048), .width_byteena_a(1),
      .width_b(8), .widthad_b(11), .numwords_b(2048), .width_byteena_b(1),

      .outdata_reg_a("UNREGISTERED"),
      .outdata_reg_b("CLOCK1"), .address_reg_b("CLOCK1"), .indata_reg_b("CLOCK1"),
      .wrcontrol_wraddress_reg_b("CLOCK1"), .byteena_reg_b("CLOCK1"),
      .read_during_write_mode_port_a("DONT_CARE"),
      .read_during_write_mode_port_b("DONT_CARE"),
      .read_during_write_mode_mixed_ports("DONT_CARE"),
      .power_up_uninitialized("FALSE"), .init_file(INIT_FILE)
    ) ram_i (
      .clock0(clk_a), .clock1(clk_b),
      .address_a(addr_a),      .data_a(data_a[g*8 +: 8]), .byteena_a(1'b1),
      .wren_a(wren_a & be_a[g]),  .q_a(qa_all[g*8 +: 8]),
      .address_b(addr_b[12:2]), .data_b(data_b), .byteena_b(1'b1),
      .wren_b(wren_b & (addr_b[1:0] == g[1:0])), .q_b(qb_all[g*8 +: 8]),
      .aclr0(1'b0), .aclr1(1'b0), .addressstall_a(1'b0), .addressstall_b(1'b0),
      .clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
      .rden_a(1'b1), .rden_b(1'b1), .eccstatus()
    );
  end endgenerate
endmodule
`default_nettype wire

