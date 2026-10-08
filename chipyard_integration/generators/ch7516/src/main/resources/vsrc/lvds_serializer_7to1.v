// =============================================================================
// File: lvds_serializer_7to1.v
// Module: lvds_serializer_7to1
// Description: 7:1 LVDS Serializer for 4 Data Lanes + 1 Clock Lane.
//              Converts 7-bit parallel words into serial differential pairs.
//              Runs on lvds_bit_clk (7x pixel_clk) and synchronizes to pixel_clk.
// =============================================================================

`timescale 1ns / 1ps

module lvds_serializer_7to1 (
    input  wire       pixel_clk,     // Pixel clock (~93.024 MHz)
    input  wire       lvds_bit_clk,  // High-speed bit clock (7x pixel_clk)
    input  wire       rst_n,

    // 7-Bit Parallel Inputs
    input  wire [6:0] d0_par,
    input  wire [6:0] d1_par,
    input  wire [6:0] d2_par,
    input  wire [6:0] d3_par,
    input  wire [6:0] clk_par,

    // Differential LVDS Outputs
    output wire       tx0_p,
    output wire       tx0_n,
    output wire       tx1_p,
    output wire       tx1_n,
    output wire       tx2_p,
    output wire       tx2_n,
    output wire       tx3_p,
    output wire       tx3_n,
    output wire       txclk_p,
    output wire       txclk_n
);

    // Detect pixel_clk edge in lvds_bit_clk domain for phase sync
    reg [2:0] pclk_sync;
    wire pclk_rise = (pclk_sync[2:1] == 2'b01);

    always @(posedge lvds_bit_clk or negedge rst_n) begin
        if (!rst_n) begin
            pclk_sync <= 3'b000;
        end else begin
            pclk_sync <= {pclk_sync[1:0], pixel_clk};
        end
    end

    // Modulo-7 phase counter
    reg [2:0] phase;
    reg [6:0] latch_d0;
    reg [6:0] latch_d1;
    reg [6:0] latch_d2;
    reg [6:0] latch_d3;
    reg [6:0] latch_clk;

    always @(posedge lvds_bit_clk or negedge rst_n) begin
        if (!rst_n) begin
            phase     <= 3'd0;
            latch_d0  <= 7'd0;
            latch_d1  <= 7'd0;
            latch_d2  <= 7'd0;
            latch_d3  <= 7'd0;
            latch_clk <= 7'd0;
        end else begin
            if (pclk_rise) begin
                phase     <= 3'd0;
                latch_d0  <= d0_par;
                latch_d1  <= d1_par;
                latch_d2  <= d2_par;
                latch_d3  <= d3_par;
                latch_clk <= clk_par;
            end else begin
                if (phase == 3'd6) begin
                    phase <= 3'd0;
                end else begin
                    phase <= phase + 1'b1;
                end
            end
        end
    end

    // Registered differential serial outputs
    reg s_tx0, s_tx1, s_tx2, s_tx3, s_txclk;

    always @(posedge lvds_bit_clk or negedge rst_n) begin
        if (!rst_n) begin
            s_tx0   <= 1'b0;
            s_tx1   <= 1'b0;
            s_tx2   <= 1'b0;
            s_tx3   <= 1'b0;
            s_txclk <= 1'b0;
        end else begin
            s_tx0   <= latch_d0[phase];
            s_tx1   <= latch_d1[phase];
            s_tx2   <= latch_d2[phase];
            s_tx3   <= latch_d3[phase];
            s_txclk <= latch_clk[phase];
        end
    end

    // Differential output buffers
    assign tx0_p   =  s_tx0;
    assign tx0_n   = ~s_tx0;
    assign tx1_p   =  s_tx1;
    assign tx1_n   = ~s_tx1;
    assign tx2_p   =  s_tx2;
    assign tx2_n   = ~s_tx2;
    assign tx3_p   =  s_tx3;
    assign tx3_n   = ~s_tx3;
    assign txclk_p =  s_txclk;
    assign txclk_n = ~s_txclk;

endmodule
