// =============================================================================
// File: video_async_fifo.v
// Module: video_async_fifo
// Description: Parameterized Asynchronous Dual-Clock Video FIFO with Gray code
//              pointers and CDC synchronizers.
// =============================================================================

`timescale 1ns / 1ps

module video_async_fifo #(
    parameter DATA_WIDTH = 96,
    parameter ADDR_WIDTH = 9   // Depth = 2^9 = 512 words (2048 pixels)
)(
    // Write Domain (dp_link_clk)
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output reg                   wr_full,

    // Read Domain (pixel_clk)
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output reg                   rd_empty,
    output reg  [ADDR_WIDTH:0]   rd_level
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    // Dual-Port RAM storage
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write pointers
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    reg [ADDR_WIDTH:0] wr_ptr_gray;

    // Read pointers
    reg [ADDR_WIDTH:0] rd_ptr_bin;
    reg [ADDR_WIDTH:0] rd_ptr_gray;

    // Synchronizers: rd_ptr_gray into wr_clk domain
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;

    // Synchronizers: wr_ptr_gray into rd_clk domain
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;

    // -------------------------------------------------------------------------
    // Memory Write (wr_clk)
    // -------------------------------------------------------------------------
    always @(posedge wr_clk) begin
        if (wr_en && !wr_full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end

    // Memory Read (rd_clk)
    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    // -------------------------------------------------------------------------
    // Write Pointer & Full Generation
    // -------------------------------------------------------------------------
    wire [ADDR_WIDTH:0] wr_ptr_bin_next  = wr_ptr_bin + (wr_en && !wr_full);
    wire [ADDR_WIDTH:0] wr_ptr_gray_next = wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray <= {(ADDR_WIDTH+1){1'b0}};
            wr_full     <= 1'b0;
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            // Full condition: MSB different, 2nd MSB different, remaining bits match
            wr_full     <= (wr_ptr_gray_next == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                                                  rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});
        end
    end

    // Synchronize read pointer to write domain
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync1 <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray_sync2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    // -------------------------------------------------------------------------
    // Read Pointer & Empty Generation
    // -------------------------------------------------------------------------
    wire [ADDR_WIDTH:0] rd_ptr_bin_next  = rd_ptr_bin + (rd_en && !rd_empty);
    wire [ADDR_WIDTH:0] rd_ptr_gray_next = rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray <= {(ADDR_WIDTH+1){1'b0}};
            rd_empty    <= 1'b1;
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
            rd_empty    <= (rd_ptr_gray_next == wr_ptr_gray_sync2);
        end
    end

    // Synchronize write pointer to read domain
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync1 <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray_sync2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

    // Convert synchronized Gray write pointer back to binary to estimate rd_level
    function [ADDR_WIDTH:0] gray_to_bin;
        input [ADDR_WIDTH:0] g;
        integer b;
        reg [ADDR_WIDTH:0] res;
        begin
            res[ADDR_WIDTH] = g[ADDR_WIDTH];
            for (b = ADDR_WIDTH-1; b >= 0; b = b - 1) begin
                res[b] = res[b+1] ^ g[b];
            end
            gray_to_bin = res;
        end
    endfunction

    wire [ADDR_WIDTH:0] wr_ptr_bin_in_rd = gray_to_bin(wr_ptr_gray_sync2);

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_level <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rd_level <= wr_ptr_bin_in_rd - rd_ptr_bin;
        end
    end

endmodule
