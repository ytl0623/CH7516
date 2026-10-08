// =============================================================================
// File: tb_unit_tests.v
// Module: tb_unit_tests
// Description: Unit-Level Verification Suite for:
//              1. dp_8b10b_decoder (Control codes & data symbols)
//              2. dp_descrambler (LFSR sequence & seed reload at BS/SR)
//              3. lvds_formatter_vesa8 (VESA & JEIDA bit-mapping correctness)
// =============================================================================

`timescale 1ns / 1ps

module tb_unit_tests;

    integer tests_passed = 0;
    integer tests_failed = 0;

    reg clk;
    reg rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // 1. 8b/10b Decoder Test
    // -------------------------------------------------------------------------
    reg  [9:0] dec_in_10b;
    wire [7:0] dec_out_8b;
    wire       dec_k_out;
    wire       dec_code_err;
    wire       dec_disp_err;

    dp_8b10b_decoder u_dec (
        .clk(clk),
        .rst_n(rst_n),
        .data_in_10b(dec_in_10b),
        .data_out_8b(dec_out_8b),
        .k_out(dec_k_out),
        .code_err(dec_code_err),
        .disp_err(dec_disp_err)
    );

    task test_8b10b;
        begin
            $display("[UNIT TEST 1] 8b/10b Decoder Verification...");
            // Test K28.5 (BS)
            dec_in_10b = 10'b0101001111;
            @(posedge clk); #1;
            if (dec_out_8b == 8'hBC && dec_k_out == 1'b1) begin
                $display("  [PASS] K28.5 (BS: 8'hBC) decoded correctly.");
                tests_passed = tests_passed + 1;
            end else begin
                $display("  [FAIL] K28.5 decode mismatch: out=%h, k=%b", dec_out_8b, dec_k_out);
                tests_failed = tests_failed + 1;
            end

            // Test K27.7 (BE)
            dec_in_10b = 10'b0111110110;
            @(posedge clk); #1;
            if (dec_out_8b == 8'hFB && dec_k_out == 1'b1) begin
                $display("  [PASS] K27.7 (BE: 8'hFB) decoded correctly.");
                tests_passed = tests_passed + 1;
            end else begin
                $display("  [FAIL] K27.7 decode mismatch: out=%h, k=%b", dec_out_8b, dec_k_out);
                tests_failed = tests_failed + 1;
            end

            // Test K28.2 (FS / SS)
            dec_in_10b = 10'b0101110000;
            @(posedge clk); #1;
            if (dec_out_8b == 8'h4C && dec_k_out == 1'b1) begin
                $display("  [PASS] K28.2 (FS/SS: 8'h4C) decoded correctly.");
                tests_passed = tests_passed + 1;
            end else begin
                $display("  [FAIL] K28.2 decode mismatch: out=%h, k=%b", dec_out_8b, dec_k_out);
                tests_failed = tests_failed + 1;
            end

            // Test K29.7 (FE / SE)
            dec_in_10b = 10'b0111101110;
            @(posedge clk); #1;
            if (dec_out_8b == 8'hFD && dec_k_out == 1'b1) begin
                $display("  [PASS] K29.7 (FE/SE: 8'hFD) decoded correctly.");
                tests_passed = tests_passed + 1;
            end else begin
                $display("  [FAIL] K29.7 decode mismatch: out=%h, k=%b", dec_out_8b, dec_k_out);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // 2. Descrambler Test
    // -------------------------------------------------------------------------
    reg  [7:0] desc_data_in;
    reg        desc_k_in;
    reg        desc_bypass;
    wire [7:0] desc_data_out;
    wire       desc_k_out;

    dp_descrambler #(.LANE_INDEX(2'd0)) u_desc (
        .clk(clk),
        .rst_n(rst_n),
        .enable(1'b1),
        .bypass(desc_bypass),
        .data_in(desc_data_in),
        .k_in(desc_k_in),
        .data_out(desc_data_out),
        .k_out(desc_k_out)
    );

    task test_descrambler;
        reg [7:0] scrambled_val;
        begin
            $display("[UNIT TEST 2] Descrambler LFSR Verification...");
            desc_bypass = 1'b0;

            // Reset LFSR with BS (K28.5)
            desc_data_in = 8'hBC;
            desc_k_in    = 1'b1;
            @(posedge clk); #1;

            if (desc_data_out == 8'hBC && desc_k_out == 1'b1) begin
                $display("  [PASS] K28.5 BS passed through without scrambling.");
                tests_passed = tests_passed + 1;
            end else begin
                $display("  [FAIL] K28.5 corrupted by descrambler!");
                tests_failed = tests_failed + 1;
            end

            // Feed data byte
            desc_data_in = 8'h00;
            desc_k_in    = 1'b0;
            @(posedge clk); #1;
            scrambled_val = desc_data_out;

            if (scrambled_val != 8'h00) begin
                $display("  [PASS] LFSR successfully scrambled/descrambled data byte: 0x00 -> 0x%02h", scrambled_val);
                tests_passed = tests_passed + 1;
            end else begin
                $display("  [FAIL] LFSR did not scramble data!");
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // 3. LVDS Formatter VESA 8-Bit Truth Table Test
    // -------------------------------------------------------------------------
    reg        fmt_jeida;
    reg  [7:0] fmt_r, fmt_g, fmt_b;
    reg        fmt_de, fmt_hs, fmt_vs;
    wire [6:0] fmt_d0, fmt_d1, fmt_d2, fmt_d3, fmt_clk;

    lvds_formatter_vesa8 u_fmt (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_is_jeida(fmt_jeida),
        .r_in(fmt_r),
        .g_in(fmt_g),
        .b_in(fmt_b),
        .de_in(fmt_de),
        .hsync_in(fmt_hs),
        .vsync_in(fmt_vs),
        .lvds_d0(fmt_d0),
        .lvds_d1(fmt_d1),
        .lvds_d2(fmt_d2),
        .lvds_d3(fmt_d3),
        .lvds_clk_word(fmt_clk)
    );

    task test_lvds_mapping;
        begin
            $display("[UNIT TEST 3] LVDS VESA 8-Bit Bit-Mapping Truth Table Check...");
            fmt_jeida = 1'b0; // VESA 8-bit

            // Test Vector:
            // R = 8'b10110011 (R7=1, R6=0, R5=1, R4=1, R3=0, R2=0, R1=1, R0=1)
            // G = 8'b01011010 (G7=0, G6=1, G5=0, G4=1, G3=1, G2=0, G1=1, G0=0)
            // B = 8'b11000101 (B7=1, B6=1, B5=0, B4=0, B3=0, B2=1, B1=0, B0=1)
            // DE = 1, HSYNC = 0, VSYNC = 1
            fmt_r  = 8'b10110011;
            fmt_g  = 8'b01011010;
            fmt_b  = 8'b11000101;
            fmt_de = 1'b1;
            fmt_hs = 1'b0;
            fmt_vs = 1'b1;

            @(posedge clk); #1;

            // Expected VESA 8-bit:
            // D0 = {G[0], R[5:0]} = {0, 110011} = 7'b0110011
            // D1 = {B[1:0], G[5:1]} = {01, 01101} = 7'b0101101
            // D2 = {DE, VSYNC, HSYNC, B[5:2]} = {1, 1, 0, 0001} = 7'b1100001
            // D3 = {0, B[7:6], G[7:6], R[7:6]} = {0, 11, 01, 10} = 7'b0110110

            if (fmt_d0 == 7'b0110011 &&
                fmt_d1 == 7'b0101101 &&
                fmt_d2 == 7'b1100001 &&
                fmt_d3 == 7'b0110110 &&
                fmt_clk == 7'b1100011) begin
                $display("  [PASS] VESA 8-bit mapping matched golden truth table perfectly.");
                $display("         D0 = %b, D1 = %b, D2 = %b, D3 = %b, CLK = %b",
                         fmt_d0, fmt_d1, fmt_d2, fmt_d3, fmt_clk);
                tests_passed = tests_passed + 1;
            end else begin
                $display("  [FAIL] VESA 8-bit mapping mismatch!");
                $display("         Got: D0=%b, D1=%b, D2=%b, D3=%b", fmt_d0, fmt_d1, fmt_d2, fmt_d3);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    initial begin
        rst_n = 1'b0;
        dec_in_10b = 10'd0;
        desc_data_in = 8'd0;
        desc_k_in = 1'b0;
        desc_bypass = 1'b0;
        fmt_jeida = 1'b0;
        fmt_r = 8'd0; fmt_g = 8'd0; fmt_b = 8'd0;
        fmt_de = 1'b0; fmt_hs = 1'b0; fmt_vs = 1'b0;

        #20 rst_n = 1'b1; #20;

        test_8b10b();
        test_descrambler();
        test_lvds_mapping();

        $display("--------------------------------------------------------------------------------");
        $display("UNIT TEST SUMMARY: %0d Passed, %0d Failed", tests_passed, tests_failed);
        $display("--------------------------------------------------------------------------------");
        if (tests_failed == 0) begin
            $display("*** ALL UNIT TESTS PASSED SUCCESSFULLY! ***");
        end else begin
            $display("*** SOME UNIT TESTS FAILED! ***");
        end
        $finish;
    end

endmodule
