// =============================================================================
// File: video_bist_pattern.v
// Module: video_bist_pattern
// Description: Built-In Self-Test (BIST) Pattern Generator per CH7516 spec.
//              - AGMODE = 1: 8-bar standard Color Bar pattern
//              - AGMODE = 0: Solid Black panel during invalid input / failure
// =============================================================================

`timescale 1ns / 1ps

module video_bist_pattern #(
    parameter H_ACTIVE = 16'd1036,
    parameter V_ACTIVE = 16'd660
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] h_count,
    input  wire [15:0] v_count,
    input  wire        de,
    input  wire        agmode,        // 1: BIST Color Bar, 0: Black Panel
    output reg  [23:0] rgb_out        // {R[7:0], G[7:0], B[7:0]}
);

    // 8 Color Bars width = 1036 / 8 = 129.5 -> boundary threshold table
    // 0: 0..129 (White)
    // 1: 130..259 (Yellow)
    // 2: 260..388 (Cyan)
    // 3: 389..518 (Green)
    // 4: 519..647 (Magenta)
    // 5: 648..777 (Red)
    // 6: 778..906 (Blue)
    // 7: 907..1035 (Black)

    wire [2:0] bar_idx = (h_count < 16'd130) ? 3'd0 :
                         (h_count < 16'd260) ? 3'd1 :
                         (h_count < 16'd389) ? 3'd2 :
                         (h_count < 16'd519) ? 3'd3 :
                         (h_count < 16'd648) ? 3'd4 :
                         (h_count < 16'd778) ? 3'd5 :
                         (h_count < 16'd907) ? 3'd6 : 3'd7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rgb_out <= 24'h000000;
        end else if (de) begin
            if (agmode) begin
                // BIST 8-Color Bar Pattern
                case (bar_idx)
                    3'd0: rgb_out <= {8'hFF, 8'hFF, 8'hFF}; // White
                    3'd1: rgb_out <= {8'hFF, 8'hFF, 8'h00}; // Yellow
                    3'd2: rgb_out <= {8'h00, 8'hFF, 8'hFF}; // Cyan
                    3'd3: rgb_out <= {8'h00, 8'hFF, 8'h00}; // Green
                    3'd4: rgb_out <= {8'hFF, 8'h00, 8'hFF}; // Magenta
                    3'd5: rgb_out <= {8'hFF, 8'h00, 8'h00}; // Red
                    3'd6: rgb_out <= {8'h00, 8'h00, 8'hFF}; // Blue
                    3'd7: rgb_out <= {8'h00, 8'h00, 8'h00}; // Black
                endcase
            end else begin
                // Black panel during invalid input / failure
                rgb_out <= 24'h000000;
            end
        end else begin
            rgb_out <= 24'h000000;
        end
    end

endmodule
