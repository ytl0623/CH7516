// =============================================================================
// File: ch7516_dp_to_lvds_top.v
// Module: ch7516_dp_to_lvds_top
// Description: Top-Level DisplayPort to 4-Channel LVDS Converter Core
//              Referenced from Chrontel CH7516A Datasheet architecture.
//              - DP Receiver: 4 Main Link Lanes, Descrambler, Framing, Unpacker
//              - Video Subsystem: CDC Asynchronous FIFO, Raster Timing Gen, BIST
//              - LVDS Transmitter: VESA 8-bit Formatter (SPWG), 7:1 Serializer
//              - Default resolution: 1036x660 @ 120Hz VESA 8-bit
// =============================================================================

`timescale 1ns / 1ps

module ch7516_dp_to_lvds_top #(
    // Video Timing Parameters: 1036x660 @ 120Hz
    parameter H_ACTIVE          = 16'd1036,
    parameter H_FRONT_PORCH     = 16'd24,
    parameter H_SYNC_WIDTH      = 16'd32,
    parameter H_BACK_PORCH      = 16'd48,
    parameter H_TOTAL           = 16'd1140, // 1036 + 24 + 32 + 48

    parameter V_ACTIVE          = 16'd660,
    parameter V_FRONT_PORCH     = 16'd3,
    parameter V_SYNC_WIDTH      = 16'd5,
    parameter V_BACK_PORCH      = 16'd12,
    parameter V_TOTAL           = 16'd680,  // 660 + 3 + 5 + 12

    parameter USE_RAW_10B_INPUT = 1'b0      // 1: 10b raw SERDES input, 0: 8b+k input
)(
    // Clocks and Reset (Pin 1 RSTB)
    input  wire        rst_n,           // Active-low asynchronous reset
    input  wire        dp_link_clk,     // DP Main link clock (e.g. 135MHz / 162MHz)
    input  wire        pixel_clk,       // Pixel clock (~93.024MHz for 1036x660@120Hz)
    input  wire        lvds_bit_clk,    // 7x pixel clock (~651.168MHz)

    // CH7516 Control & Configuration Pins
    input  wire        agmode,          // Pin 5: 1: BIST Pattern, 0: Black Pattern
    input  wire        cfg_lvds_format, // 0: VESA 8-bit (default), 1: JEIDA 8-bit
    input  wire        cfg_scramble_en, // 1: Descrambler enable, 0: bypass
    output wire        hpd,             // Pin 19: Hot Plug Detect output
    output wire        fail_flag_out,   // Pin 33: Fail flag output

    // DisplayPort 4 Main Link Lanes (Pins 9,10,12..15,17,18)
    // Mode 0: 8b + K-character decoded inputs
    input  wire [7:0]  dp_lane0_data,
    input  wire        dp_lane0_k,
    input  wire [7:0]  dp_lane1_data,
    input  wire        dp_lane1_k,
    input  wire [7:0]  dp_lane2_data,
    input  wire        dp_lane2_k,
    input  wire [7:0]  dp_lane3_data,
    input  wire        dp_lane3_k,

    // Mode 1: 10-bit raw SERDES inputs (optional)
    input  wire [9:0]  dp_lane0_raw10b,
    input  wire [9:0]  dp_lane1_raw10b,
    input  wire [9:0]  dp_lane2_raw10b,
    input  wire [9:0]  dp_lane3_raw10b,

    // The First Channel LVDS Outputs (ALVTX[3:0], ALVTXCLK)
    output wire        alvtx0_p,        // Pin 45, 46
    output wire        alvtx0_n,
    output wire        alvtx1_p,        // Pin 43, 44
    output wire        alvtx1_n,
    output wire        alvtx2_p,        // Pin 40, 41
    output wire        alvtx2_n,
    output wire        alvtx3_p,        // Pin 37, 38
    output wire        alvtx3_n,
    output wire        alvtxclk_p,      // Pin 39
    output wire        alvtxclk_n,

    // Diagnostic and Status Outputs
    output wire        link_locked,
    output wire        stream_active
);

    // Drive Hot Plug Detect (HPD) high once reset is released
    assign hpd = rst_n;

    // =========================================================================
    // 1. 8b/10b Decoders (Active when USE_RAW_10B_INPUT is enabled)
    // =========================================================================
    wire [7:0] dec0_data, dec1_data, dec2_data, dec3_data;
    wire       dec0_k,    dec1_k,    dec2_k,    dec3_k;

    dp_8b10b_decoder u_dec0 (
        .clk(dp_link_clk), .rst_n(rst_n),
        .data_in_10b(dp_lane0_raw10b),
        .data_out_8b(dec0_data), .k_out(dec0_k),
        .code_err(), .disp_err()
    );
    dp_8b10b_decoder u_dec1 (
        .clk(dp_link_clk), .rst_n(rst_n),
        .data_in_10b(dp_lane1_raw10b),
        .data_out_8b(dec1_data), .k_out(dec1_k),
        .code_err(), .disp_err()
    );
    dp_8b10b_decoder u_dec2 (
        .clk(dp_link_clk), .rst_n(rst_n),
        .data_in_10b(dp_lane2_raw10b),
        .data_out_8b(dec2_data), .k_out(dec2_k),
        .code_err(), .disp_err()
    );
    dp_8b10b_decoder u_dec3 (
        .clk(dp_link_clk), .rst_n(rst_n),
        .data_in_10b(dp_lane3_raw10b),
        .data_out_8b(dec3_data), .k_out(dec3_k),
        .code_err(), .disp_err()
    );

    wire [7:0] rx_l0_data = USE_RAW_10B_INPUT ? dec0_data : dp_lane0_data;
    wire       rx_l0_k    = USE_RAW_10B_INPUT ? dec0_k    : dp_lane0_k;
    wire [7:0] rx_l1_data = USE_RAW_10B_INPUT ? dec1_data : dp_lane1_data;
    wire       rx_l1_k    = USE_RAW_10B_INPUT ? dec1_k    : dp_lane1_k;
    wire [7:0] rx_l2_data = USE_RAW_10B_INPUT ? dec2_data : dp_lane2_data;
    wire       rx_l2_k    = USE_RAW_10B_INPUT ? dec2_k    : dp_lane2_k;
    wire [7:0] rx_l3_data = USE_RAW_10B_INPUT ? dec3_data : dp_lane3_data;
    wire       rx_l3_k    = USE_RAW_10B_INPUT ? dec3_k    : dp_lane3_k;

    // =========================================================================
    // 2. DisplayPort Descramblers (Lanes 0..3)
    // =========================================================================
    wire [7:0] desc_l0_data, desc_l1_data, desc_l2_data, desc_l3_data;
    wire       desc_l0_k,    desc_l1_k,    desc_l2_k,    desc_l3_k;

    dp_descrambler #(.LANE_INDEX(2'd0)) u_desc0 (
        .clk(dp_link_clk), .rst_n(rst_n), .enable(1'b1),
        .bypass(~cfg_scramble_en),
        .data_in(rx_l0_data), .k_in(rx_l0_k),
        .data_out(desc_l0_data), .k_out(desc_l0_k)
    );
    dp_descrambler #(.LANE_INDEX(2'd1)) u_desc1 (
        .clk(dp_link_clk), .rst_n(rst_n), .enable(1'b1),
        .bypass(~cfg_scramble_en),
        .data_in(rx_l1_data), .k_in(rx_l1_k),
        .data_out(desc_l1_data), .k_out(desc_l1_k)
    );
    dp_descrambler #(.LANE_INDEX(2'd2)) u_desc2 (
        .clk(dp_link_clk), .rst_n(rst_n), .enable(1'b1),
        .bypass(~cfg_scramble_en),
        .data_in(rx_l2_data), .k_in(rx_l2_k),
        .data_out(desc_l2_data), .k_out(desc_l2_k)
    );
    dp_descrambler #(.LANE_INDEX(2'd3)) u_desc3 (
        .clk(dp_link_clk), .rst_n(rst_n), .enable(1'b1),
        .bypass(~cfg_scramble_en),
        .data_in(rx_l3_data), .k_in(rx_l3_k),
        .data_out(desc_l3_data), .k_out(desc_l3_k)
    );

    // =========================================================================
    // 3. DisplayPort Framer & 4-Lane Pixel Unpacker
    // =========================================================================
    wire        pix4_valid;
    wire [95:0] pix4_data;
    wire        dp_line_start;
    wire        dp_line_end;
    wire        dp_frame_start;
    wire        dp_frame_end;

    dp_pixel_unpacker_4lane #(
        .DEFAULT_H_ACTIVE(H_ACTIVE),
        .DEFAULT_V_ACTIVE(V_ACTIVE),
        .DEFAULT_H_TOTAL(H_TOTAL),
        .DEFAULT_V_TOTAL(V_TOTAL)
    ) u_unpacker (
        .clk(dp_link_clk),
        .rst_n(rst_n),
        .lane0_data(desc_l0_data), .lane0_k(desc_l0_k),
        .lane1_data(desc_l1_data), .lane1_k(desc_l1_k),
        .lane2_data(desc_l2_data), .lane2_k(desc_l2_k),
        .lane3_data(desc_l3_data), .lane3_k(desc_l3_k),

        .pix4_valid(pix4_valid),
        .pix4_data(pix4_data),
        .line_start(dp_line_start),
        .line_end(dp_line_end),
        .frame_start(dp_frame_start),
        .frame_end(dp_frame_end),

        .msa_h_active(),
        .msa_v_active(),
        .msa_h_total(),
        .msa_v_total(),
        .link_locked(link_locked),
        .stream_active(stream_active)
    );

    // =========================================================================
    // 4. Asynchronous Dual-Clock Video FIFO (CDC)
    // =========================================================================
    wire [95:0] fifo_rd_data;
    wire        fifo_empty;
    wire [9:0]  fifo_level;
    reg         fifo_rd_en;

    video_async_fifo #(
        .DATA_WIDTH(96),
        .ADDR_WIDTH(9) // 512 words capacity = 2048 pixels
    ) u_video_fifo (
        .wr_clk(dp_link_clk),
        .wr_rst_n(rst_n),
        .wr_en(pix4_valid),
        .wr_data(pix4_data),
        .wr_full(),

        .rd_clk(pixel_clk),
        .rd_rst_n(rst_n),
        .rd_en(fifo_rd_en),
        .rd_data(fifo_rd_data),
        .rd_empty(fifo_empty),
        .rd_level(fifo_level)
    );

    // =========================================================================
    // 5. Video Timing Generator (1036x660 @ 120Hz VESA standard)
    // =========================================================================
    wire [15:0] h_cnt, v_cnt;
    wire        timing_de;
    wire        timing_hsync;
    wire        timing_vsync;
    wire        timing_line_start;
    wire        timing_frame_start;

    video_timing_generator #(
        .H_ACTIVE(H_ACTIVE),
        .H_FRONT_PORCH(H_FRONT_PORCH),
        .H_SYNC_WIDTH(H_SYNC_WIDTH),
        .H_BACK_PORCH(H_BACK_PORCH),
        .H_TOTAL(H_TOTAL),

        .V_ACTIVE(V_ACTIVE),
        .V_FRONT_PORCH(V_FRONT_PORCH),
        .V_SYNC_WIDTH(V_SYNC_WIDTH),
        .V_BACK_PORCH(V_BACK_PORCH),
        .V_TOTAL(V_TOTAL),

        .H_SYNC_POL(1'b1),
        .V_SYNC_POL(1'b1)
    ) u_timing_gen (
        .clk(pixel_clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .sync_reset(1'b0),

        .h_count(h_cnt),
        .v_count(v_cnt),
        .de(timing_de),
        .hsync(timing_hsync),
        .vsync(timing_vsync),
        .line_start(timing_line_start),
        .frame_start(timing_frame_start)
    );

    // =========================================================================
    // 6. BIST Pattern Generator (Color Bar & Black Panel per CH7516 specs)
    // =========================================================================
    wire [23:0] bist_rgb;

    video_bist_pattern #(
        .H_ACTIVE(H_ACTIVE),
        .V_ACTIVE(V_ACTIVE)
    ) u_bist_gen (
        .clk(pixel_clk),
        .rst_n(rst_n),
        .h_count(h_cnt),
        .v_count(v_cnt),
        .de(timing_de),
        .agmode(agmode),
        .rgb_out(bist_rgb)
    );

    // Fail Flag output: asserted when DP input is not active or locked
    assign fail_flag_out = ~(link_locked & stream_active);

    // =========================================================================
    // 7. Video Multiplexer & FIFO 4-Pixel Serializer in pixel_clk Domain
    // =========================================================================
    reg [1:0]  pix_sel;
    reg [23:0] dp_pixel_rgb;

    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            pix_sel    <= 2'd0;
            fifo_rd_en <= 1'b0;
        end else begin
            if (timing_de) begin
                if (pix_sel == 2'd3) begin
                    pix_sel    <= 2'd0;
                    fifo_rd_en <= 1'b1; // Advance FIFO to next 4-pixel word
                end else begin
                    pix_sel    <= pix_sel + 1'b1;
                    fifo_rd_en <= 1'b0;
                end
            end else begin
                pix_sel    <= 2'd0;
                fifo_rd_en <= 1'b0;
            end
        end
    end

    // Mux individual pixel from the 96-bit word {P3, P2, P1, P0}
    always @(*) begin
        case (pix_sel)
            2'd0: dp_pixel_rgb = fifo_rd_data[23:0];
            2'd1: dp_pixel_rgb = fifo_rd_data[47:24];
            2'd2: dp_pixel_rgb = fifo_rd_data[71:48];
            2'd3: dp_pixel_rgb = fifo_rd_data[95:72];
        endcase
    end

    // Video Mux: Select between DP Extracted Video and BIST/Black Pattern
    reg [23:0] mux_rgb;
    reg        mux_de;
    reg        mux_hsync;
    reg        mux_vsync;

    wire video_source_is_dp = (link_locked & stream_active & !fifo_empty);

    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            mux_rgb   <= 24'h000000;
            mux_de    <= 1'b0;
            mux_hsync <= 1'b0;
            mux_vsync <= 1'b0;
        end else begin
            mux_de    <= timing_de;
            mux_hsync <= timing_hsync;
            mux_vsync <= timing_vsync;

            if (video_source_is_dp && timing_de) begin
                mux_rgb <= dp_pixel_rgb;
            end else begin
                mux_rgb <= bist_rgb;
            end
        end
    end

    // =========================================================================
    // 8. LVDS Formatter: VESA (SPWG) 8-Bit & JEIDA 8-Bit Mapping
    // =========================================================================
    wire [6:0] lvds_d0_word;
    wire [6:0] lvds_d1_word;
    wire [6:0] lvds_d2_word;
    wire [6:0] lvds_d3_word;
    wire [6:0] lvds_clk_word;

    lvds_formatter_vesa8 #(
        .LVDS_CLK_PATTERN(7'b1100011)
    ) u_lvds_fmt (
        .clk(pixel_clk),
        .rst_n(rst_n),
        .cfg_is_jeida(cfg_lvds_format),

        .r_in(mux_rgb[23:16]),
        .g_in(mux_rgb[15:8]),
        .b_in(mux_rgb[7:0]),
        .de_in(mux_de),
        .hsync_in(mux_hsync),
        .vsync_in(mux_vsync),

        .lvds_d0(lvds_d0_word),
        .lvds_d1(lvds_d1_word),
        .lvds_d2(lvds_d2_word),
        .lvds_d3(lvds_d3_word),
        .lvds_clk_word(lvds_clk_word)
    );

    // =========================================================================
    // 9. 7:1 LVDS Differential Serializer
    // =========================================================================
    lvds_serializer_7to1 u_lvds_ser (
        .pixel_clk(pixel_clk),
        .lvds_bit_clk(lvds_bit_clk),
        .rst_n(rst_n),

        .d0_par(lvds_d0_word),
        .d1_par(lvds_d1_word),
        .d2_par(lvds_d2_word),
        .d3_par(lvds_d3_word),
        .clk_par(lvds_clk_word),

        .tx0_p(alvtx0_p),
        .tx0_n(alvtx0_n),
        .tx1_p(alvtx1_p),
        .tx1_n(alvtx1_n),
        .tx2_p(alvtx2_p),
        .tx2_n(alvtx2_n),
        .tx3_p(alvtx3_p),
        .tx3_n(alvtx3_n),
        .txclk_p(alvtxclk_p),
        .txclk_n(alvtxclk_n)
    );

endmodule
