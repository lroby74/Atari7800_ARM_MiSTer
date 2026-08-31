`default_nettype none

module atari2600_arm_subsystem (
    input  wire        clk,
    input  wire        clk_vid,
    input  wire        reset,
    input  wire        arm_enable,
    input  wire [4:0]  mapper,
    input  wire [1:0]  cdf_family,

    input  wire [12:0] a_in,
    input  wire [7:0]  d_in,
    input  wire        rwn,
    output wire [7:0]  d_out,

    input  wire        cart_download,
    input  wire [18:0] ioctl_addr,
    input  wire [7:0]  ioctl_dout,
    input  wire        ioctl_wr,

    input  wire        e_sel,
    input  wire [16:0] e_addr,
    input  wire  [7:0] e_data,
    input  wire        e_wren,
    output wire  [7:0] e_q,

    input  wire [7:0]  rom_do,
    input  wire [18:0] rom_size,
    output wire [18:0] rom_a,
    output wire        rom_read,

    input  wire        vblank_sw,

    output wire        ds_wait,

    input  wire [12:0] dpcrom_addr_a,
    output wire [31:0] dpcrom_q_a,
    input  wire [14:0] dpcrom_addr_b,
    output wire  [7:0] dpcrom_q_b,

    output wire        cmd_hold,

    output wire        busy,
    output wire        done,
    output wire [7:0]  audio_mix_out,

    output wire        arm_rst_vid,
    output wire [31:0] arm_bus_addr,
    output wire [31:0] arm_bus_wdata,
    output wire [3:0]  arm_bus_be,
    output wire        arm_bus_we,
    output wire        arm_bus_req_dpcp,

    output wire [31:0] arm_bus_addr_pre,
    output wire        arm_bus_req_pre,
    input  wire [31:0] arm_bus_rdata_dpcp,
    input  wire        arm_bus_ack_dpcp,

    input  wire        dpcp_callfn,
    input  wire [7:0]  dpcp_callfn_val,
    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_r0,

    output wire [2:0]  dbg_pp
);

    wire is_cdf_mapper = (mapper == 5'd23);
    wire subsys_active = arm_enable & is_cdf_mapper;
    wire core_reset    = reset | (~subsys_active) | cart_download;

    wire is_dpcp = (mapper == 5'd21);

    wire arm_core_active = arm_enable & (is_cdf_mapper | is_dpcp);
    wire arm_core_reset  = reset | (~arm_core_active) | cart_download;
    wire [1:0]  family_sel = is_dpcp ? 2'b00 : cdf_family;
    wire is_plus_fam = (family_sel == 2'b10);

    reg [23:0] dw3;
    reg [31:0] cstack_img, cbase_img;
    reg        ldx_seen, ldy_seen;
    reg [15:0] ff_offset_r;
    wire [31:0] dw_full = {ioctl_dout, dw3};

    always @(posedge clk) begin
        if (cart_download && ioctl_wr) begin

            dw3 <= {ioctl_dout, dw3[23:8]};
            if (ioctl_addr[1:0] == 2'b11 && ioctl_addr < 19'h800) begin
                if (dw_full == 32'h135200A2) ldx_seen <= 1'b1;
                if (dw_full == 32'h135200A0) ldy_seen <= 1'b1;
                if ((dw_full & 32'hFFFFFF00) == 32'hE2422000)
                    ff_offset_r <= {ioctl_addr[15:2], 2'b00};
            end
            if (ioctl_addr == 19'h17F7) cstack_img <= dw_full;
            if (ioctl_addr == 19'h17FB) cbase_img  <= dw_full;
        end
        if (reset && !cart_download) begin

        end
        if (cart_download && ioctl_wr && ioctl_addr == 19'd0) begin
            ldx_seen <= 1'b0; ldy_seen <= 1'b0; ff_offset_r <= 16'd0;
            cstack_img <= 32'h40001FFC; cbase_img <= 32'h00000800;
        end
    end

    wire [31:0] arm_start_pc = is_dpcp     ? 32'h00000c08 :
                               is_plus_fam ? (cbase_img & 32'hFFFFFFFE) :
                                             32'h00000808;
    wire [31:0] arm_start_sp = is_dpcp     ? 32'h40001ffc :
                               is_plus_fam ? cstack_img :
                                             32'h40001ffc;
    wire [31:0] arm_start_lr = is_dpcp     ? 32'h00000c00 :
                               is_plus_fam ? (cbase_img & 32'hFFFFFFFE) :
                                             32'h00000800;

    wire [31:0] bus_addr, bus_wdata, bus_rdata;

    wire [31:0] bus_addr_pre;
    wire [31:0] bus_addr_pre_nx;
    wire        bus_req_pre;
    wire [3:0]  bus_be;
    wire        bus_we;
    wire [1:0]  bus_sz;
    wire        bus_req, bus_ack;

    wire [31:0] bus_rdata_cdf, bus_rdata_dpcp;
    wire        bus_ack_cdf,   bus_ack_dpcp;

    wire [31:0] bus_rdata_next_cdf;
    wire        bus_rdata_next_ok_cdf;
    wire [31:0] bus_rdata_next    = bus_rdata_next_cdf;
    wire        bus_rdata_next_ok = is_cdf_mapper & bus_rdata_next_ok_cdf;
    wire        cb_req_raw;
    wire        cb_ack_raw;

    wire [7:0]  bridge_dout;
    wire        callfn;
    wire [7:0]  callfn_val;
    wire [1:0]  cb_id;
    wire [31:0] cb_v1, cb_v2, cb_ret;
    wire        arm_halted;

    wire [15:0] m6502_addr_full = {3'b000, a_in[12:0]};

    wire [31:0] cb0, cb1, cb2, cb3;
    wire [15:0] p_nc0, p_nc1, p_nc2, p_nc3;
    wire [7:0]  p_nc4, p_nc5; wire p_nc6; wire [2:0] p_nc7;
    cdf_family_params params_cb (
        .family_sel(family_sel),
        .ds_base(p_nc0), .ds_inc_base(p_nc1), .wf_base(p_nc2), .prog_off(p_nc3),
        .amp_stream(p_nc4), .jump_mask(p_nc5), .is_plus(p_nc6), .start_bank(p_nc7),
        .cb0(cb0), .cb1(cb1), .cb2(cb2), .cb3(cb3)
    );

    wire       arm_callfn     = is_dpcp ? dpcp_callfn     : callfn;
    wire [7:0] arm_callfn_val = is_dpcp ? dpcp_callfn_val : callfn_val;

    reg callfn_toggle;
    always @(posedge clk) begin
        if (arm_core_reset) callfn_toggle <= 1'b0;
        else if (arm_callfn && (arm_callfn_val == 8'd254 || arm_callfn_val == 8'd255))
            callfn_toggle <= ~callfn_toggle;
    end

    wire core_reset_vid;
    cdc_sync2 u_sync_reset_vid (.dst_clk(clk_vid), .d(arm_core_reset), .q(core_reset_vid));

    wire callfn_toggle_vid;
    cdc_sync2 u_sync_callfn_vid (.dst_clk(clk_vid), .d(callfn_toggle), .q(callfn_toggle_vid));
    reg callfn_toggle_vid_d;
    wire callfn_pulse_vid = callfn_toggle_vid ^ callfn_toggle_vid_d;

    reg arm_start_pending;
    wire arm_start = arm_start_pending & arm_halted;
    always @(posedge clk_vid) begin
        callfn_toggle_vid_d <= callfn_toggle_vid;
        if (core_reset_vid) arm_start_pending <= 1'b0;
        else begin
            if (callfn_pulse_vid)
                arm_start_pending <= 1'b1;
            else if (arm_start)
                arm_start_pending <= 1'b0;
        end
    end

    wire arm_halted_sync;
    cdc_sync2 u_sync_halted_sys (.dst_clk(clk), .d(arm_halted), .q(arm_halted_sync));

    reg disp_bank;
    reg swap_pending;
    reg arm_halted_sync_d, vblank_sw_d;
    wire arm_halt_rising = arm_halted_sync & ~arm_halted_sync_d;
    wire vblank_start     = vblank_sw & ~vblank_sw_d;

    assign dbg_pp = {swap_pending, arm_halt_rising, vblank_start};
    always @(posedge clk) begin
        arm_halted_sync_d <= arm_halted_sync;
        vblank_sw_d       <= vblank_sw;
        if (core_reset) begin
            disp_bank <= 1'b0; swap_pending <= 1'b0;
        end else begin

            disp_bank    <= 1'b0;
            swap_pending <= 1'b0;
        end
    end

    wire arm_running  = ~arm_halted_sync;
    wire ds_wait_arm  = ~vblank_sw & arm_running;

    reg [1:0]  shim_cb_id; reg [31:0] shim_cb_v1, shim_cb_v2;
    reg        cb_req_toggle;
    reg        cb_req_raw_d;
    wire       new_cb_req = cb_req_raw && !cb_req_raw_d;
    always @(posedge clk_vid) begin
        cb_req_raw_d <= cb_req_raw;
        if (core_reset_vid) cb_req_toggle <= 1'b0;
        else if (new_cb_req) begin
            shim_cb_id <= cb_id; shim_cb_v1 <= cb_v1; shim_cb_v2 <= cb_v2;
            cb_req_toggle <= ~cb_req_toggle;
        end
    end

    wire cb_req_toggle_sys;
    cdc_sync2 u_sync_cbreqtog_sys (.dst_clk(clk), .d(cb_req_toggle), .q(cb_req_toggle_sys));
    reg cb_req_toggle_sys_d;
    wire cb_req_edge_sys = cb_req_toggle_sys ^ cb_req_toggle_sys_d;

    reg        cbreq_active;
    reg [31:0] cbreq_ret_lat;
    reg        cb_ack_toggle;
    always @(posedge clk) begin
        cb_req_toggle_sys_d <= cb_req_toggle_sys;
        if (core_reset) begin
            cbreq_active <= 1'b0; cb_ack_toggle <= 1'b0;
        end else begin
            if (cb_req_edge_sys && !cbreq_active) cbreq_active <= 1'b1;
            if (cbreq_active && cb_ack_raw) begin
                cbreq_active  <= 1'b0;
                cbreq_ret_lat <= cb_ret;
                cb_ack_toggle <= ~cb_ack_toggle;
            end
        end
    end
    wire cb_req_sys = cbreq_active;

    wire cb_ack_toggle_vid;
    cdc_sync2 u_sync_cbacktog_vid (.dst_clk(clk_vid), .d(cb_ack_toggle), .q(cb_ack_toggle_vid));
    reg cb_ack_toggle_vid_d;
    always @(posedge clk_vid) cb_ack_toggle_vid_d <= cb_ack_toggle_vid;
    wire cb_ack_vid = cb_ack_toggle_vid ^ cb_ack_toggle_vid_d;
    wire [31:0] cb_ret_vid = cbreq_ret_lat;

    wire [14:0] cdfrom_addr_a, cdfrom_addr_a_nx, cdfrom_addr_b;
    wire [31:0] cdfrom_q_a, cdfrom_q_a_next, cdfrom_data_b, cdfrom_q_b;
    wire  [3:0] cdfrom_be_b;
    wire        cdfrom_wren_b;

    arm_cart_rom u_arm_cart_rom (
        .clk_a         (clk_vid),
        .clk_b         (clk),
        .dpc_sel       (is_dpcp),
        .cart_download (cart_download),
        .c_addr_a      (cdfrom_addr_a),
        .c_addr_a_nx   (cdfrom_addr_a_nx),
        .c_q_a         (cdfrom_q_a),
        .c_q_a_next    (cdfrom_q_a_next),
        .c_addr_b      (cdfrom_addr_b),
        .c_data_b      (cdfrom_data_b),
        .c_byteena_b   (cdfrom_be_b),
        .c_wren_b      (cdfrom_wren_b),
        .c_q_b         (cdfrom_q_b),
        .d_addr_a      (dpcrom_addr_a),
        .d_q_a         (dpcrom_q_a),
        .d_addr_b      (dpcrom_addr_b),
        .d_q_b         (dpcrom_q_b),
        .e_sel         (e_sel),
        .e_addr        (e_addr),
        .e_data        (e_data),
        .e_wren        (e_wren),
        .e_q           (e_q)
    );

    cdf_bridge #(
        .ROM_DEPTH (32768),
        .RAM_DEPTH (32768)
    ) u_cdf_bridge (
        .clk          (clk),
        .clk_vid      (clk_vid),
        .rst          (core_reset),
        .rst_vid      (core_reset_vid),
        .m6502_addr   (m6502_addr_full),
        .m6502_din    (d_in),
        .m6502_rwn    (rwn),
        .m6502_dout   (bridge_dout),

        .bus_addr     (bus_addr),
        .bus_addr_pre (bus_addr_pre),
        .bus_addr_pre_nx (bus_addr_pre_nx),
        .bus_req_pre  (bus_req_pre),
        .bus_wdata    (bus_wdata),
        .bus_rdata    (bus_rdata_cdf),
        .bus_be       (bus_be),
        .bus_we       (bus_we),
        .bus_sz       (bus_sz),
        .bus_req      (bus_req & subsys_active),
        .bus_ack      (bus_ack_cdf),
        .bus_rdata_next    (bus_rdata_next_cdf),
        .bus_rdata_next_ok (bus_rdata_next_ok_cdf),
        .callfn       (callfn),
        .callfn_val   (callfn_val),
        .cb_req       (cb_req_sys),
        .cb_id        (shim_cb_id),
        .cb_v1        (shim_cb_v1),
        .cb_v2        (shim_cb_v2),
        .cb_ret       (cb_ret),
        .cb_ack       (cb_ack_raw),
        .family_sel   (family_sel),
        .ldx_en       (is_plus_fam & ldx_seen),
        .ldy_en       (is_plus_fam & ldy_seen),
        .ff_offset    (is_plus_fam ? ff_offset_r : 16'd0),
        .disp_bank    (disp_bank),
        .ds_wait_arm  (ds_wait_arm),
        .arm_run_now  (arm_running & vblank_sw),
        .arm_run_any  (arm_running),
        .cmd_hold     (cmd_hold),
        .ds_wait      (ds_wait),

        .rom_load_we  (cart_download & ioctl_wr & (ioctl_addr < 19'd131072)),
        .rom_load_addr(ioctl_addr[16:0]),
        .rom_bytes    (rom_size),
        .rom_load_data(ioctl_dout),
        .rom_addr_a_o   (cdfrom_addr_a),
        .rom_addr_a_nx_o(cdfrom_addr_a_nx),
        .rom_q_a_i      (cdfrom_q_a),
        .rom_q_a_next_i (cdfrom_q_a_next),
        .rom_addr_b_o   (cdfrom_addr_b),
        .rom_data_b_o   (cdfrom_data_b),
        .rom_be_b_o     (cdfrom_be_b),
        .rom_wren_b_o   (cdfrom_wren_b),
        .rom_q_b_i      (cdfrom_q_b),
        .dbg_bank      (),
        .dbg_mode      (),
        .dbg_lda_valid (),
        .dbg_lda_addr  (),
        .dbg_ff_val    ()
    );

    thumb3_shim u_arm_core (
        .clk      (clk_vid),
        .rst      (core_reset_vid),
        .start    (arm_start),
        .start_pc (arm_start_pc),
        .start_sp (arm_start_sp),
        .start_lr (arm_start_lr),
        .halted   (arm_halted),

        .cb_addr0 (is_dpcp ? 32'hFFFFFFF1 : cb0),
        .cb_addr1 (is_dpcp ? 32'hFFFFFFF3 : cb1),
        .cb_addr2 (is_dpcp ? 32'hFFFFFFF5 : cb2),
        .cb_addr3 (is_dpcp ? 32'hFFFFFFF7 : cb3),
        .cb_req   (cb_req_raw),
        .cb_id    (cb_id),
        .cb_v1    (cb_v1),
        .cb_v2    (cb_v2),
        .cb_ack   (cb_ack_vid),
        .cb_ret   (cb_ret_vid),
        .bus_addr (bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_be   (bus_be),
        .bus_we   (bus_we),
        .bus_sz   (bus_sz),
        .bus_req  (bus_req),
        .bus_ack  (bus_ack),
        .bus_rdata_next    (bus_rdata_next),
        .bus_rdata_next_ok (bus_rdata_next_ok),
        .bus_addr_pre (bus_addr_pre),
        .bus_addr_pre_nx (bus_addr_pre_nx),
        .bus_req_pre  (bus_req_pre),
        .dbg_pc   (dbg_pc),
        .dbg_r0   (dbg_r0)
    );

    assign bus_rdata = is_cdf_mapper ? bus_rdata_cdf :
                       is_dpcp       ? bus_rdata_dpcp : 32'd0;
    assign bus_ack   = is_cdf_mapper ? bus_ack_cdf :
                       is_dpcp       ? bus_ack_dpcp : 1'b0;

    assign arm_rst_vid      = core_reset_vid;
    assign arm_bus_addr     = bus_addr;
    assign arm_bus_addr_pre = bus_addr_pre;

    assign arm_bus_req_pre  = bus_req_pre & arm_enable & is_dpcp;
    assign arm_bus_wdata    = bus_wdata;
    assign arm_bus_be       = bus_be;
    assign arm_bus_we       = bus_we;
    assign arm_bus_req_dpcp = bus_req & arm_enable & is_dpcp;
    assign bus_rdata_dpcp   = arm_bus_rdata_dpcp;
    assign bus_ack_dpcp     = arm_bus_ack_dpcp;

    assign d_out = subsys_active ? bridge_dout : 8'h00;

    assign busy  = ~arm_halted_sync;
    assign done  = arm_halted_sync;
    assign audio_mix_out = 8'd0;

    assign rom_a = 19'd0;
    assign rom_read = 1'b0;

endmodule

