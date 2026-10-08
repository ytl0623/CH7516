// =============================================================================
// File: lvds_formatter_vesa8.v
// Module: lvds_formatter_vesa8
// Description: Formats 24-bit RGB pixel data + syncs into 7-bit parallel words
//              for 4 LVDS data lanes + 1 clock lane.
//              Supports both VESA (SPWG) 8-bit and JEIDA (OpenLDI) 8-bit modes.
// =============================================================================

`timescale 1ns / 1ps

module lvds_formatter_vesa8 #(
    parameter [6:0] LVDS_CLK_PATTERN = 7'b1100011 // OpenLDI standard clock
)(
    input  wire        clk,            // pixel_clk
    input  wire        rst_n,
    input  wire        cfg_is_jeida,   // 0: VESA 8-bit (default), 1: JEIDA 8-bit

    // Incoming Video Stream
    input  wire [7:0]  r_in,
    input  wire [7:0]  g_in,
    input  wire [7:0]  b_in,
    input  wire        de_in,
    input  wire        hsync_in,
    input  wire        vsync_in,

    // 7-Bit Parallel LVDS Words for Serializer (bit 0 serialized first)
    output reg  [6:0]  lvds_d0,
    output reg  [6:0]  lvds_d1,
    output reg  [6:0]  lvds_d2,
    output reg  [6:0]  lvds_d3,
    output reg  [6:0]  lvds_clk_word
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lvds_d0       <= 7'd0;
            lvds_d1       <= 7'd0;
            lvds_d2       <= 7'd0;
            lvds_d3       <= 7'd0;
            lvds_clk_word <= LVDS_CLK_PATTERN;
        end else begin
            lvds_clk_word <= LVDS_CLK_PATTERN;

            if (!cfg_is_jeida) begin
                // -------------------------------------------------------------
                // Standard VESA (SPWG) 8-bit Mapping:
                // D0: [0]=R0, [1]=R1, [2]=R2, [3]=R3, [4]=R4, [5]=R5, [6]=G0
                // D1: [0]=G1, [1]=G2, [2]=G3, [3]=G4, [4]=G5, [5]=B0, [6]=B1
                // D2: [0]=B2, [1]=B3, [2]=B4, [3]=B5, [4]=HS, [5]=VS, [6]=DE
                // D3: [0]=R6, [1]=R7, [2]=G6, [3]=G7, [4]=B6, [5]=B7, [6]=0
                // -------------------------------------------------------------
                lvds_d0 <= {g_in[0], r_in[5], r_in[4], r_in[3], r_in[2], r_in[1], r_in[0]};
                lvds_d1 <= {b_in[1], b_in[0], g_in[5], g_in[4], g_in[3], g_in[2], g_in[1]};
                lvds_d2 <= {de_in, vsync_in, hsync_in, b_in[5], b_in[4], b_in[3], b_in[2]};
                lvds_d3 <= {1'b0, b_in[7], b_in[6], g_in[7], g_in[6], r_in[7], r_in[6]};
            end else begin
                // -------------------------------------------------------------
                // JEIDA (OpenLDI) 8-bit Mapping:
                // D0: [0]=R2, [1]=R3, [2]=R4, [3]=R5, [4]=R6, [5]=R7, [6]=G2
                // D1: [0]=G3, [1]=G4, [2]=G5, [3]=G6, [4]=G7, [5]=B2, [6]=B3
                // D2: [0]=B4, [1]=B5, [2]=B6, [3]=B7, [4]=HS, [5]=VS, [6]=DE
                // D3: [0]=R0, [1]=R1, [2]=G0, [3]=G1, [4]=B0, [5]=B1, [6]=0
                // -------------------------------------------------------------
                lvds_d0 <= {g_in[2], r_in[7], r_in[6], r_in[5], r_in[4], r_in[3], r_in[2]};
                lvds_d1 <= {b_in[3], b_in[2], g_in[7], g_in[6], g_in[5], g_in[4], g_in[3]};
                lvds_d2 <= {de_in, vsync_in, hsync_in, b_in[7], b_in[6], b_in[5], b_in[4]};
                lvds_d3 <= {1'b0, b_in[1], b_in[0], g_in[1], g_in[0], r_in[1], r_in[0]};
            end
        end
    end

endmodule
