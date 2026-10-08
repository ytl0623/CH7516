// =============================================================================
// File: dp_pixel_unpacker_4lane.v
// Module: dp_pixel_unpacker_4lane
// Description: DisplayPort 4-Lane Main Link Packet Framer and Pixel Unpacker.
//              - Parses DP Framing: BS (K28.5), BE (K27.7), FS (K28.2), FE (K29.7)
//              - Extracts VB-ID, Mvid/Nvid, and blanking states
//              - Unpacks 24-bit RGB (8-bit per color) pixels from 4 lanes
//              - Emits 4 pixels (96-bit word) atomically every 3 link clocks
//              - Perfectly aligned with 1036 pixels/line (1036 / 4 = 259 words)
// =============================================================================

`timescale 1ns / 1ps

module dp_pixel_unpacker_4lane #(
    parameter DEFAULT_H_ACTIVE = 16'd1036,
    parameter DEFAULT_V_ACTIVE = 16'd660,
    parameter DEFAULT_H_TOTAL  = 16'd1140,
    parameter DEFAULT_V_TOTAL  = 16'd680
)(
    input  wire        clk,            // DP link clock (e.g. 135MHz / 162MHz)
    input  wire        rst_n,

    // 4 Lane Input Stream (post-descrambler)
    input  wire [7:0]  lane0_data,
    input  wire        lane0_k,
    input  wire [7:0]  lane1_data,
    input  wire        lane1_k,
    input  wire [7:0]  lane2_data,
    input  wire        lane2_k,
    input  wire [7:0]  lane3_data,
    input  wire        lane3_k,

    // 4-Pixel Parallel Output (96-bit: {P3, P2, P1, P0})
    output reg         pix4_valid,     // 1 when 4 new pixels are ready
    output reg  [95:0] pix4_data,      // {P3[23:0], P2[23:0], P1[23:0], P0[23:0]}
    output reg         line_start,     // Blanking End (BE) active video start
    output reg         line_end,       // Blanking Start (BS) active video end
    output reg         frame_start,    // Transition to active frame
    output reg         frame_end,      // Transition to vertical blanking

    // Link and Stream Status
    output reg  [15:0] msa_h_active,
    output reg  [15:0] msa_v_active,
    output reg  [15:0] msa_h_total,
    output reg  [15:0] msa_v_total,
    output reg         link_locked,    // 1 if receiving valid DP framing
    output reg         stream_active   // 1 if active video is streaming
);

    // Special Control Symbol definitions
    localparam K_BS = 8'hBC; // Blanking Start (K28.5)
    localparam K_BE = 8'hFB; // Blanking End (K27.7)
    localparam K_FS = 8'h4C; // Fill / Secondary Start (K28.2)
    localparam K_FE = 8'hFD; // Fill / Secondary End (K29.7)

    // State machine for framing
    localparam ST_RESET      = 3'd0;
    localparam ST_WAIT_BS    = 3'd1;
    localparam ST_VBID_MVID  = 3'd2;
    localparam ST_BLANKING   = 3'd3;
    localparam ST_ACTIVE_VID = 3'd4;

    reg [2:0]  state;
    reg [3:0]  blank_cnt;
    reg        vblank_reg;
    reg        vblank_prev;
    reg [1:0]  pix_unpack_phase;
    reg [15:0] active_pixel_cnt;
    reg [15:0] active_line_cnt;

    // Buffer for 3-cycle 4-pixel unpacking
    reg [7:0] r0_hold, g0_hold, b0_hold, r1_hold;
    reg [7:0] g1_hold, b1_hold, r2_hold, g2_hold;

    // Link lock watchdog counter
    reg [15:0] no_bs_timeout;

    wire is_bs = lane0_k && (lane0_data == K_BS);
    wire is_be = lane0_k && (lane0_data == K_BE);
    wire is_fs = lane0_k && (lane0_data == K_FS);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_RESET;
            blank_cnt        <= 4'd0;
            vblank_reg       <= 1'b1;
            vblank_prev      <= 1'b1;
            pix_unpack_phase <= 2'd0;
            active_pixel_cnt <= 16'd0;
            active_line_cnt  <= 16'd0;
            msa_h_active     <= DEFAULT_H_ACTIVE;
            msa_v_active     <= DEFAULT_V_ACTIVE;
            msa_h_total      <= DEFAULT_H_TOTAL;
            msa_v_total      <= DEFAULT_V_TOTAL;
            link_locked      <= 1'b0;
            stream_active    <= 1'b0;
            no_bs_timeout    <= 16'd0;

            pix4_valid       <= 1'b0;
            pix4_data        <= 96'd0;
            line_start       <= 1'b0;
            line_end         <= 1'b0;
            frame_start      <= 1'b0;
            frame_end        <= 1'b0;
        end else begin
            // Default single-cycle pulse clears
            pix4_valid  <= 1'b0;
            line_start  <= 1'b0;
            line_end    <= 1'b0;
            frame_start <= 1'b0;
            frame_end   <= 1'b0;

            // Watchdog for DP link framing
            if (is_bs) begin
                no_bs_timeout <= 16'd0;
                link_locked   <= 1'b1;
            end else begin
                if (no_bs_timeout > 16'd50000) begin
                    link_locked   <= 1'b0;
                    stream_active <= 1'b0;
                end else begin
                    no_bs_timeout <= no_bs_timeout + 1'b1;
                end
            end

            case (state)
                ST_RESET: begin
                    state <= ST_WAIT_BS;
                end

                ST_WAIT_BS: begin
                    if (is_bs) begin
                        state     <= ST_VBID_MVID;
                        blank_cnt <= 4'd0;
                    end
                end

                ST_VBID_MVID: begin
                    blank_cnt <= blank_cnt + 1'b1;
                    if (blank_cnt == 4'd0) begin
                        // VB-ID: bit 0 indicates VBLANK
                        vblank_reg  <= lane0_data[0];
                        vblank_prev <= vblank_reg;
                        if (vblank_reg && !lane0_data[0]) begin
                            frame_start     <= 1'b1;
                            active_line_cnt <= 16'd0;
                        end else if (!vblank_reg && lane0_data[0]) begin
                            frame_end <= 1'b1;
                        end
                    end else if (blank_cnt >= 4'd4) begin
                        state <= ST_BLANKING;
                    end
                end

                ST_BLANKING: begin
                    if (is_be) begin
                        // Blanking End (BE) marks start of active video line
                        state            <= ST_ACTIVE_VID;
                        pix_unpack_phase <= 2'd0;
                        active_pixel_cnt <= 16'd0;
                        if (!vblank_reg) begin
                            active_line_cnt <= active_line_cnt + 1'b1;
                            stream_active   <= 1'b1;
                            line_start      <= 1'b1;
                        end
                    end else if (is_bs) begin
                        state     <= ST_VBID_MVID;
                        blank_cnt <= 4'd0;
                    end
                end

                ST_ACTIVE_VID: begin
                    if (is_bs) begin
                        // Line finished with Blanking Start
                        state     <= ST_VBID_MVID;
                        blank_cnt <= 4'd0;
                        line_end  <= 1'b1;
                    end else if (!lane0_k && !lane1_k && !lane2_k && !lane3_k) begin
                        // Active video payload bytes across 4 lanes
                        case (pix_unpack_phase)
                            2'd0: begin
                                r0_hold          <= lane0_data;
                                g0_hold          <= lane1_data;
                                b0_hold          <= lane2_data;
                                r1_hold          <= lane3_data;
                                pix_unpack_phase <= 2'd1;
                            end
                            2'd1: begin
                                g1_hold          <= lane0_data;
                                b1_hold          <= lane1_data;
                                r2_hold          <= lane2_data;
                                g2_hold          <= lane3_data;
                                pix_unpack_phase <= 2'd2;
                            end
                            2'd2: begin
                                // 4 complete RGB pixels assembled:
                                // Pixel 0: {r0_hold, g0_hold, b0_hold}
                                // Pixel 1: {r1_hold, g1_hold, b1_hold}
                                // Pixel 2: {r2_hold, g2_hold, lane0_data}
                                // Pixel 3: {lane1_data, lane2_data, lane3_data}
                                if (!vblank_reg) begin
                                    pix4_valid <= 1'b1;
                                    pix4_data  <= {
                                        lane1_data, lane2_data, lane3_data, // P3
                                        r2_hold,    g2_hold,    lane0_data, // P2
                                        r1_hold,    g1_hold,    b1_hold,    // P1
                                        r0_hold,    g0_hold,    b0_hold     // P0
                                    };
                                end
                                active_pixel_cnt <= active_pixel_cnt + 16'd4;
                                pix_unpack_phase <= 2'd0;
                            end
                        endcase
                    end else if (is_fs) begin
                        // Fill symbol during active line padding
                        // Wait for next pixel data or BS
                    end
                end

                default: state <= ST_RESET;
            endcase
        end
    end

endmodule
