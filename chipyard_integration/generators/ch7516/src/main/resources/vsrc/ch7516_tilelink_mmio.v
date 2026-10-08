// =============================================================================
// File: ch7516_tilelink_mmio.v
// Module: ch7516_tilelink_mmio
// Description: TileLink-UL (TL-UL) MMIO Peripheral for CH7516 DP to LVDS Bridge.
//              Integrates with RISC-V Rocket-Chip / Chipyard SoC architecture.
//              - Channel A: Request (Get, PutFullData, PutPartialData)
//              - Channel D: Response (AccessAck, AccessAckData)
//              - Memory-mapped registers for 1036x660 @ 120Hz VESA 8-bit configuration
// =============================================================================

`timescale 1ns / 1ps

module ch7516_tilelink_mmio #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter SOURCE_WIDTH = 4,
    parameter SIZE_WIDTH = 3
)(
    // SoC System Clock & Reset
    input  wire                    clock,
    input  wire                    reset,      // Synchronous active-high reset

    // Clocks for Display Subsystem
    input  wire                    dp_link_clk,
    input  wire                    pixel_clk,
    input  wire                    lvds_bit_clk,

    // TileLink-UL Channel A (Request)
    input  wire                    tl_a_valid,
    output reg                     tl_a_ready,
    input  wire [2:0]              tl_a_opcode,
    input  wire [2:0]              tl_a_param,
    input  wire [SIZE_WIDTH-1:0]   tl_a_size,
    input  wire [SOURCE_WIDTH-1:0] tl_a_source,
    input  wire [ADDR_WIDTH-1:0]   tl_a_address,
    input  wire [3:0]              tl_a_mask,
    input  wire [DATA_WIDTH-1:0]   tl_a_data,

    // TileLink-UL Channel D (Response)
    output reg                     tl_d_valid,
    input  wire                    tl_d_ready,
    output reg  [2:0]              tl_d_opcode,
    output reg  [1:0]              tl_d_param,
    output reg  [SIZE_WIDTH-1:0]   tl_d_size,
    output reg  [SOURCE_WIDTH-1:0] tl_d_source,
    output reg                     tl_d_sink,
    output reg  [DATA_WIDTH-1:0]   tl_d_data,
    output reg                     tl_d_error,

    // External DisplayPort 4-Lane Inputs
    input  wire [7:0]              dp_lane0_data,
    input  wire                    dp_lane0_k,
    input  wire [7:0]              dp_lane1_data,
    input  wire                    dp_lane1_k,
    input  wire [7:0]              dp_lane2_data,
    input  wire                    dp_lane2_k,
    input  wire [7:0]              dp_lane3_data,
    input  wire                    dp_lane3_k,

    // External LVDS Differential Outputs
    output wire                    alvtx0_p,
    output wire                    alvtx0_n,
    output wire                    alvtx1_p,
    output wire                    alvtx1_n,
    output wire                    alvtx2_p,
    output wire                    alvtx2_n,
    output wire                    alvtx3_p,
    output wire                    alvtx3_n,
    output wire                    alvtxclk_p,
    output wire                    alvtxclk_n,

    // Chip-level Status & Interrupt to RISC-V PLIC
    output wire                    interrupt
);

    // TileLink Opcodes
    localparam TL_A_PUTFULLDATA    = 3'd0;
    localparam TL_A_PUTPARTIALDATA = 3'd1;
    localparam TL_A_GET            = 3'd4;

    localparam TL_D_ACCESSACK      = 3'd0;
    localparam TL_D_ACCESSACKDATA  = 3'd1;

    // Register Offsets (in bytes)
    localparam REG_CR              = 8'h00; // Control Register
    localparam REG_SR              = 8'h04; // Status Register (RO)
    localparam REG_HTIMING0        = 8'h08; // H_ACTIVE [15:0], H_FP [31:16]
    localparam REG_HTIMING1        = 8'h0C; // H_SYNC [15:0], H_BP [31:16]
    localparam REG_VTIMING0        = 8'h10; // V_ACTIVE [15:0], V_FP [31:16]
    localparam REG_VTIMING1        = 8'h14; // V_SYNC [15:0], V_BP [31:16]
    localparam REG_TOTAL_TIMING    = 8'h18; // H_TOTAL [15:0], V_TOTAL [31:16]
    localparam REG_IER             = 8'h1C; // Interrupt Enable Register
    localparam REG_ISR             = 8'h20; // Interrupt Status Register (W1C)

    // =========================================================================
    // Memory-Mapped Registers
    // =========================================================================
    // Default video timing: 1036x660 @ 120Hz
    reg [31:0] reg_cr;
    reg [31:0] reg_htim0;
    reg [31:0] reg_htim1;
    reg [31:0] reg_vtim0;
    reg [31:0] reg_vtim1;
    reg [31:0] reg_total;
    reg [31:0] reg_ier;
    reg [31:0] reg_isr;

    // Hardware status signals from core
    wire hpd;
    wire fail_flag_out;
    wire link_locked;
    wire stream_active;

    wire [31:0] reg_sr = {
        16'd0,
        8'd0,
        4'd0,
        stream_active,
        link_locked,
        fail_flag_out,
        hpd
    };

    // Interrupt generation (e.g. signal fail, link lock change)
    assign interrupt = |(reg_ier & reg_isr);

    // =========================================================================
    // TileLink-UL Bus FSM
    // =========================================================================
    localparam S_IDLE = 1'b0;
    localparam S_RESP = 1'b1;
    reg state;

    reg [ADDR_WIDTH-1:0]   req_addr;
    reg [SOURCE_WIDTH-1:0] req_source;
    reg [SIZE_WIDTH-1:0]   req_size;
    reg [2:0]              req_opcode;
    reg [DATA_WIDTH-1:0]   read_data;

    wire [7:0] reg_offset = req_addr[7:0];

    // Read Multiplexer
    always @(*) begin
        case (reg_offset)
            REG_CR:           read_data = reg_cr;
            REG_SR:           read_data = reg_sr;
            REG_HTIMING0:     read_data = reg_htim0;
            REG_HTIMING1:     read_data = reg_htim1;
            REG_VTIMING0:     read_data = reg_vtim0;
            REG_VTIMING1:     read_data = reg_vtim1;
            REG_TOTAL_TIMING: read_data = reg_total;
            REG_IER:          read_data = reg_ier;
            REG_ISR:          read_data = reg_isr;
            default:          read_data = 32'hDEADBEEF;
        endcase
    end

    // TileLink Bus Transactions
    always @(posedge clock) begin
        if (reset) begin
            state       <= S_IDLE;
            tl_a_ready  <= 1'b1;
            tl_d_valid  <= 1'b0;
            tl_d_opcode <= 3'd0;
            tl_d_param  <= 2'd0;
            tl_d_size   <= {SIZE_WIDTH{1'b0}};
            tl_d_source <= {SOURCE_WIDTH{1'b0}};
            tl_d_sink   <= 1'b0;
            tl_d_data   <= 32'd0;
            tl_d_error  <= 1'b0;

            // Register defaults for 1036x660 @ 120Hz
            reg_cr      <= 32'h00000001; // Core enabled, VESA 8-bit, AGMODE=0
            reg_htim0   <= {16'd24, 16'd1036}; // H_FP=24, H_ACTIVE=1036
            reg_htim1   <= {16'd48, 16'd32};   // H_BP=48, H_SYNC=32
            reg_vtim0   <= {16'd3,  16'd660};  // V_FP=3,  V_ACTIVE=660
            reg_vtim1   <= {16'd12, 16'd5};    // V_BP=12, V_SYNC=5
            reg_total   <= {16'd680, 16'd1140};// V_TOTAL=680, H_TOTAL=1140
            reg_ier     <= 32'd0;
            reg_isr     <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (tl_a_valid && tl_a_ready) begin
                        req_addr   <= tl_a_address;
                        req_source <= tl_a_source;
                        req_size   <= tl_a_size;
                        req_opcode <= tl_a_opcode;
                        tl_a_ready <= 1'b0;

                        // Write transaction handling
                        if (tl_a_opcode == TL_A_PUTFULLDATA || tl_a_opcode == TL_A_PUTPARTIALDATA) begin
                            case (tl_a_address[7:0])
                                REG_CR:           reg_cr    <= tl_a_data;
                                REG_HTIMING0:     reg_htim0 <= tl_a_data;
                                REG_HTIMING1:     reg_htim1 <= tl_a_data;
                                REG_VTIMING0:     reg_vtim0 <= tl_a_data;
                                REG_VTIMING1:     reg_vtim1 <= tl_a_data;
                                REG_TOTAL_TIMING: reg_total <= tl_a_data;
                                REG_IER:          reg_ier   <= tl_a_data;
                                REG_ISR:          reg_isr   <= reg_isr & ~tl_a_data; // W1C
                                default: ;
                            endcase
                        end

                        state <= S_RESP;
                    end else begin
                        tl_a_ready <= 1'b1;
                    end
                end

                S_RESP: begin
                    tl_d_valid  <= 1'b1;
                    tl_d_source <= req_source;
                    tl_d_size   <= req_size;
                    tl_d_error  <= 1'b0;

                    if (req_opcode == TL_A_GET) begin
                        tl_d_opcode <= TL_D_ACCESSACKDATA;
                        tl_d_data   <= read_data;
                    end else begin
                        tl_d_opcode <= TL_D_ACCESSACK;
                        tl_d_data   <= 32'd0;
                    end

                    if (tl_d_valid && tl_d_ready) begin
                        tl_d_valid <= 1'b0;
                        tl_a_ready <= 1'b1;
                        state      <= S_IDLE;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // Core CH7516 DP to LVDS Hardware Instantiation
    // =========================================================================
    wire core_rst_n = ~(reset | reg_cr[1]); // Active-low reset (HW reset or CR[1] soft reset)
    wire agmode_cfg = reg_cr[2];            // CR[2]: AGMODE (1: BIST, 0: Black)
    wire lvds_fmt   = reg_cr[3];            // CR[3]: 0: VESA 8-bit, 1: JEIDA
    wire scramble_en= reg_cr[4];            // CR[4]: Descrambler enable

    ch7516_dp_to_lvds_top #(
        .H_ACTIVE(16'd1036),
        .H_FRONT_PORCH(16'd24),
        .H_SYNC_WIDTH(16'd32),
        .H_BACK_PORCH(16'd48),
        .H_TOTAL(16'd1140),

        .V_ACTIVE(16'd660),
        .V_FRONT_PORCH(16'd3),
        .V_SYNC_WIDTH(16'd5),
        .V_BACK_PORCH(16'd12),
        .V_TOTAL(16'd680),

        .USE_RAW_10B_INPUT(1'b0)
    ) u_ch7516_core (
        .rst_n(core_rst_n),
        .dp_link_clk(dp_link_clk),
        .pixel_clk(pixel_clk),
        .lvds_bit_clk(lvds_bit_clk),

        .agmode(agmode_cfg),
        .cfg_lvds_format(lvds_fmt),
        .cfg_scramble_en(scramble_en),
        .hpd(hpd),
        .fail_flag_out(fail_flag_out),

        .dp_lane0_data(dp_lane0_data),
        .dp_lane0_k(dp_lane0_k),
        .dp_lane1_data(dp_lane1_data),
        .dp_lane1_k(dp_lane1_k),
        .dp_lane2_data(dp_lane2_data),
        .dp_lane2_k(dp_lane2_k),
        .dp_lane3_data(dp_lane3_data),
        .dp_lane3_k(dp_lane3_k),

        .dp_lane0_raw10b(10'd0),
        .dp_lane1_raw10b(10'd0),
        .dp_lane2_raw10b(10'd0),
        .dp_lane3_raw10b(10'd0),

        .alvtx0_p(alvtx0_p),
        .alvtx0_n(alvtx0_n),
        .alvtx1_p(alvtx1_p),
        .alvtx1_n(alvtx1_n),
        .alvtx2_p(alvtx2_p),
        .alvtx2_n(alvtx2_n),
        .alvtx3_p(alvtx3_p),
        .alvtx3_n(alvtx3_n),
        .alvtxclk_p(alvtxclk_p),
        .alvtxclk_n(alvtxclk_n),

        .link_locked(link_locked),
        .stream_active(stream_active)
    );

endmodule
