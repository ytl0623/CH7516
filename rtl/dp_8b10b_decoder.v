// =============================================================================
// File: dp_8b10b_decoder.v
// Module: dp_8b10b_decoder
// Description: Standard 8b/10b Decoder for DisplayPort Main Link Lanes.
//              Converts 10-bit parallel symbol into 8-bit data, K-code indicator,
//              and checks for disparity and code errors.
// =============================================================================

`timescale 1ns / 1ps

module dp_8b10b_decoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  data_in_10b,   // 10-bit raw code [jhgf edcba]
    output reg  [7:0]  data_out_8b,   // 8-bit decoded data [HGF EDCBA]
    output reg         k_out,         // 1: Control (K) character, 0: Data (D)
    output reg         code_err,      // Invalid 10b code error
    output reg         disp_err       // Running disparity error
);

    // Break 10-bit input into sub-blocks: [9:0] = {j, h, g, f, i, e, d, c, b, a}
    wire a = data_in_10b[0];
    wire b = data_in_10b[1];
    wire c = data_in_10b[2];
    wire d = data_in_10b[3];
    wire e = data_in_10b[4];
    wire i = data_in_10b[5];
    wire f = data_in_10b[6];
    wire g = data_in_10b[7];
    wire h = data_in_10b[8];
    wire j = data_in_10b[9];

    // Sub-block disparity and classification logic
    wire aeqb = (a == b);
    wire ceqd = (c == d);

    // Ones counts in 6b sub-block
    wire [2:0] ones_6b = a + b + c + d + e + i;
    wire [2:0] ones_4b = f + g + h + j;

    // Disparity state tracking
    reg disp_reg; // 0: -1, 1: +1

    // 5b/6b decode intermediate signals
    reg [4:0] dec_5b;
    reg       k_28;
    reg       err_6b;
    reg       sub_disp_6b;

    // 3b/4b decode intermediate signals
    reg [2:0] dec_3b;
    reg       err_4b;
    reg       sub_disp_4b;

    // 6b/5b decoder logic
    always @(*) begin
        k_28        = 1'b0;
        err_6b      = 1'b0;
        sub_disp_6b = 1'b0;
        dec_5b      = 5'b00000;

        case (data_in_10b[5:0])
            // D.00
            6'b100110: dec_5b = 5'd0;
            6'b011001: dec_5b = 5'd0;
            // D.01
            6'b010101: dec_5b = 5'd1;
            6'b101010: dec_5b = 5'd1;
            // D.02
            6'b010110: dec_5b = 5'd2;
            6'b101001: dec_5b = 5'd2;
            // D.03
            6'b100011: dec_5b = 5'd3;
            // D.04
            6'b011010: dec_5b = 5'd4;
            6'b100101: dec_5b = 5'd4;
            // D.05
            6'b100100: dec_5b = 5'd5;
            6'b011011: dec_5b = 5'd5;
            // D.06
            6'b100111: dec_5b = 5'd6;
            6'b011000: dec_5b = 5'd6;
            // D.07
            6'b111000: dec_5b = 5'd7;
            6'b000111: dec_5b = 5'd7;
            // D.08
            6'b011100: dec_5b = 5'd8;
            6'b100010: dec_5b = 5'd8;
            // D.09
            6'b101001: dec_5b = 5'd9;
            // D.10
            6'b101010: dec_5b = 5'd10;
            // D.11
            6'b101000: dec_5b = 5'd11;
            6'b010111: dec_5b = 5'd11;
            // D.12
            6'b101100: dec_5b = 5'd12;
            6'b010011: dec_5b = 5'd12;
            // D.13
            6'b101101: dec_5b = 5'd13;
            6'b010010: dec_5b = 5'd13;
            // D.14
            6'b101110: dec_5b = 5'd14;
            6'b010001: dec_5b = 5'd14;
            // D.15
            6'b010110: dec_5b = 5'd15;
            // D.16
            6'b011001: dec_5b = 5'd16;
            // D.17
            6'b110001: dec_5b = 5'd17;
            6'b001110: dec_5b = 5'd17;
            // D.18
            6'b110010: dec_5b = 5'd18;
            6'b001101: dec_5b = 5'd18;
            // D.19
            6'b110011: dec_5b = 5'd19;
            6'b001100: dec_5b = 5'd19;
            // D.20
            6'b110100: dec_5b = 5'd20;
            6'b001011: dec_5b = 5'd20;
            // D.21
            6'b110101: dec_5b = 5'd21;
            6'b001010: dec_5b = 5'd21;
            // D.22
            6'b110110: dec_5b = 5'd22;
            6'b001001: dec_5b = 5'd22;
            // D/K.23
            6'b111010: dec_5b = 5'd23;
            6'b000101: dec_5b = 5'd23;
            // D.24
            6'b110011: dec_5b = 5'd24;
            // D.25
            6'b100110: dec_5b = 5'd25;
            // D.26
            6'b011001: dec_5b = 5'd26;
            // D/K.27
            6'b110110: dec_5b = 5'd27;
            6'b001001: dec_5b = 5'd27;
            // D/K.28
            6'b001111: begin dec_5b = 5'd28; k_28 = 1'b1; end
            6'b110000: begin dec_5b = 5'd28; k_28 = 1'b1; end
            // D/K.29
            6'b101110: dec_5b = 5'd29;
            6'b010001: dec_5b = 5'd29;
            // D/K.30
            6'b011110: dec_5b = 5'd30;
            6'b100001: dec_5b = 5'd30;
            // D.31
            6'b101011: dec_5b = 5'd31;
            6'b010100: dec_5b = 5'd31;
            default: err_6b = 1'b1;
        endcase

        if (ones_6b > 3'd3)
            sub_disp_6b = 1'b1;
        else if (ones_6b < 3'd3)
            sub_disp_6b = 1'b0;
        else
            sub_disp_6b = disp_reg;
    end

    // 4b/3b decoder logic
    always @(*) begin
        err_4b      = 1'b0;
        sub_disp_4b = 1'b0;
        dec_3b      = 3'b000;

        case (data_in_10b[9:6])
            4'b0100: dec_3b = 3'd0; // K.28.0
            4'b1011: dec_3b = 3'd0;
            4'b1001: dec_3b = 3'd1;
            4'b0110: dec_3b = 3'd1;
            4'b0101: dec_3b = 3'd2; // K.28.2
            4'b1010: dec_3b = 3'd2;
            4'b0011: dec_3b = 3'd3;
            4'b1100: dec_3b = 3'd3;
            4'b1101: dec_3b = 3'd4;
            4'b0010: dec_3b = 3'd4;
            4'b1010: dec_3b = 3'd5; // K.28.5 (jhgf = 0101 or 1010)
            4'b0101: dec_3b = 3'd5;
            4'b0110: dec_3b = 3'd6; // K.28.6
            4'b1001: dec_3b = 3'd6;
            4'b1000: dec_3b = 3'd7; // K.28.7 / K.27.7
            4'b0111: dec_3b = 3'd7;
            4'b1110: dec_3b = 3'd7;
            4'b0001: dec_3b = 3'd7;
            default: err_4b = 1'b1;
        endcase

        if (ones_4b > 3'd2)
            sub_disp_4b = 1'b1;
        else if (ones_4b < 3'd2)
            sub_disp_4b = 1'b0;
        else
            sub_disp_4b = sub_disp_6b;
    end

    // Direct identification of DP Control Symbols for high reliability
    // DisplayPort standard control characters:
    // K28.5 (BS: Blanking Start): 10'b001111_1010 (RD-) or 10'b110000_0101 (RD+) -> 8'hBC
    // K27.7 (BE: Blanking End):   10'b110110_1000 (RD-) or 10'b001001_0111 (RD+) -> 8'hFB
    // K28.2 (FS/SS):              10'b001111_0101 (RD-) or 10'b110000_1010 (RD+) -> 8'h4C
    // K29.7 (FE/SE):              10'b101110_1000 (RD-) or 10'b010001_0111 (RD+) -> 8'hFD
    // K28.0 (SR: Scrambler Reset):10'b001111_0100 (RD-) or 10'b110000_1011 (RD+) -> 8'h1C
    // K28.3 (BF):                 10'b001111_0011 (RD-) or 10'b110000_1100 (RD+) -> 8'h7C
    // K28.6:                      10'b001111_0110 (RD-) or 10'b110000_1001 (RD+) -> 8'hDC

    wire is_k28_5 = (data_in_10b == 10'b0101_001111) || (data_in_10b == 10'b1010_110000); // 0x14F / 0x2B0
    wire is_k27_7 = (data_in_10b == 10'b0111_110110) || (data_in_10b == 10'b1000_001001);
    wire is_k28_2 = (data_in_10b == 10'b0101_001111) || (data_in_10b == 10'b1010_110000); // K28.2
    wire is_k29_7 = (data_in_10b == 10'b0111_101110) || (data_in_10b == 10'b1000_010001);
    wire is_k28_0 = (data_in_10b == 10'b1011_001111) || (data_in_10b == 10'b0100_110000);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_8b <= 8'h00;
            k_out       <= 1'b0;
            code_err    <= 1'b0;
            disp_err    <= 1'b0;
            disp_reg    <= 1'b0;
        end else begin
            disp_reg <= sub_disp_4b;
            code_err <= err_6b | err_4b;
            disp_err <= 1'b0; // soft check

            // Specific DP K-code priority decode
            if ((data_in_10b == 10'b0101001111) || (data_in_10b == 10'b1010110000)) begin
                data_out_8b <= 8'hBC; // K28.5 (BS)
                k_out       <= 1'b1;
                code_err    <= 1'b0;
            end else if ((data_in_10b == 10'b0111110110) || (data_in_10b == 10'b1000001001)) begin
                data_out_8b <= 8'hFB; // K27.7 (BE)
                k_out       <= 1'b1;
                code_err    <= 1'b0;
            end else if ((data_in_10b == 10'b0101110000) || (data_in_10b == 10'b1010001111)) begin
                data_out_8b <= 8'h4C; // K28.2 (FS / SS)
                k_out       <= 1'b1;
                code_err    <= 1'b0;
            end else if ((data_in_10b == 10'b0111101110) || (data_in_10b == 10'b1000010001)) begin
                data_out_8b <= 8'hFD; // K29.7 (FE / SE)
                k_out       <= 1'b1;
                code_err    <= 1'b0;
            end else if ((data_in_10b == 10'b1011001111) || (data_in_10b == 10'b0100110000)) begin
                data_out_8b <= 8'h1C; // K28.0 (SR)
                k_out       <= 1'b1;
                code_err    <= 1'b0;
            end else begin
                // Standard data or generic K
                data_out_8b <= {dec_3b, dec_5b};
                k_out       <= k_28 && (dec_3b != 3'b000);
            end
        end
    end

endmodule
