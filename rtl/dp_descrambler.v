// =============================================================================
// File: dp_descrambler.v
// Module: dp_descrambler
// Description: DisplayPort LFSR Descrambler for one Main Link Lane.
//              Polynomial: G(X) = X^16 + X^15 + X^13 + X^4 + 1
//              Resets to lane-specific seed upon receiving BS (K28.5) or SR (K28.0).
//              Bypasses descrambling for K characters or when bypass signal is set.
// =============================================================================

`timescale 1ns / 1ps

module dp_descrambler #(
    parameter [1:0]  LANE_INDEX = 2'd0,
    parameter [15:0] SEED_INIT  = 16'hFFFF
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        bypass,        // 1: bypass descrambling, 0: perform descrambling
    input  wire [7:0]  data_in,
    input  wire        k_in,
    output reg  [7:0]  data_out,
    output reg         k_out
);

    reg [15:0] lfsr;

    // Reset seed selection based on lane index (Enhanced Framing Mode)
    wire [15:0] lane_seed = (LANE_INDEX == 2'd0) ? 16'hFFFF :
                            (LANE_INDEX == 2'd1) ? 16'hFFFE :
                            (LANE_INDEX == 2'd2) ? 16'hFFFD : 16'hFFFC;

    // Combinational 8-step LFSR advance function:
    // G(X) = X^16 + X^15 + X^13 + X^4 + 1
    function [15:0] next_lfsr_state;
        input [15:0] state;
        integer i;
        reg [15:0] s;
        reg fb;
        begin
            s = state;
            for (i = 0; i < 8; i = i + 1) begin
                fb = s[15] ^ s[14] ^ s[12] ^ s[3];
                s = {s[14:0], fb};
            end
            next_lfsr_state = s;
        end
    endfunction

    // 8-bit pseudo-random mask derived from the current LFSR state
    function [7:0] get_lfsr_mask;
        input [15:0] state;
        integer i;
        reg [15:0] s;
        reg [7:0] m;
        reg fb;
        begin
            s = state;
            for (i = 0; i < 8; i = i + 1) begin
                m[7-i] = s[15];
                fb = s[15] ^ s[14] ^ s[12] ^ s[3];
                s = {s[14:0], fb};
            end
            get_lfsr_mask = m;
        end
    endfunction

    wire is_bs = (k_in && (data_in == 8'hBC)); // K28.5 Blanking Start
    wire is_sr = (k_in && (data_in == 8'h1C)); // K28.0 Scrambler Reset

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr     <= lane_seed;
            data_out <= 8'h00;
            k_out    <= 1'b0;
        end else if (enable) begin
            k_out <= k_in;

            if (is_bs || is_sr) begin
                // Reset LFSR seed at BS / SR
                lfsr     <= lane_seed;
                data_out <= data_in;
            end else if (k_in || bypass) begin
                // K-characters and bypassed data are un-scrambled
                data_out <= data_in;
                // LFSR does not advance on framing symbols or is in bypass
            end else begin
                // Data byte descrambling: XOR with pseudo-random mask
                data_out <= data_in ^ get_lfsr_mask(lfsr);
                lfsr     <= next_lfsr_state(lfsr);
            end
        end
    end

endmodule
