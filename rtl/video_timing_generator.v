// =============================================================================
// File: video_timing_generator.v
// Module: video_timing_generator
// Description: Video Raster Timing Generator for 1036x660 @ 120Hz VESA standard.
//              Generates DE, HSYNC, VSYNC, pixel coordinates, and line/frame syncs.
//              Can free-run or synchronize to incoming DP framing markers.
// =============================================================================

`timescale 1ns / 1ps

module video_timing_generator #(
    // Video Timing Parameters: 1036x660 @ 120Hz default
    parameter H_ACTIVE      = 16'd1036,
    parameter H_FRONT_PORCH = 16'd24,
    parameter H_SYNC_WIDTH  = 16'd32,
    parameter H_BACK_PORCH  = 16'd48,
    parameter H_TOTAL       = 16'd1140, // 1036 + 24 + 32 + 48

    parameter V_ACTIVE      = 16'd660,
    parameter V_FRONT_PORCH = 16'd3,
    parameter V_SYNC_WIDTH  = 16'd5,
    parameter V_BACK_PORCH  = 16'd12,
    parameter V_TOTAL       = 16'd680,  // 660 + 3 + 5 + 12

    parameter H_SYNC_POL    = 1'b1,     // 1: Active High, 0: Active Low
    parameter V_SYNC_POL    = 1'b1      // 1: Active High, 0: Active Low
)(
    input  wire        clk,        // pixel_clk (~93.024 MHz)
    input  wire        rst_n,
    input  wire        enable,
    input  wire        sync_reset, // External sync reset (e.g. from DP frame_start)

    output reg  [15:0] h_count,
    output reg  [15:0] v_count,
    output reg         de,
    output reg         hsync,
    output reg         vsync,
    output reg         line_start,
    output reg         frame_start
);

    // Raster coordinate counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 16'd0;
            v_count <= 16'd0;
        end else if (sync_reset) begin
            h_count <= 16'd0;
            v_count <= 16'd0;
        end else if (enable) begin
            if (h_count == H_TOTAL - 1'b1) begin
                h_count <= 16'd0;
                if (v_count == V_TOTAL - 1'b1) begin
                    v_count <= 16'd0;
                end else begin
                    v_count <= v_count + 1'b1;
                end
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    // Sync and DE Generation
    wire h_active_region = (h_count < H_ACTIVE);
    wire v_active_region = (v_count < V_ACTIVE);

    wire h_sync_region = (h_count >= (H_ACTIVE + H_FRONT_PORCH)) &&
                         (h_count <  (H_ACTIVE + H_FRONT_PORCH + H_SYNC_WIDTH));

    wire v_sync_region = (v_count >= (V_ACTIVE + V_FRONT_PORCH)) &&
                         (v_count <  (V_ACTIVE + V_FRONT_PORCH + V_SYNC_WIDTH));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            de          <= 1'b0;
            hsync       <= ~H_SYNC_POL;
            vsync       <= ~V_SYNC_POL;
            line_start  <= 1'b0;
            frame_start <= 1'b0;
        end else if (enable) begin
            de          <= h_active_region && v_active_region;
            hsync       <= h_sync_region ? H_SYNC_POL : ~H_SYNC_POL;
            vsync       <= v_sync_region ? V_SYNC_POL : ~V_SYNC_POL;
            line_start  <= (h_count == 16'd0);
            frame_start <= (h_count == 16'd0) && (v_count == 16'd0);
        end
    end

endmodule
