package chipyard.ch7516

import chisel3._
import chisel3.util._

// -----------------------------------------------------------------------------
// IO Definition for CH7516 DisplayPort to LVDS Peripheral
// -----------------------------------------------------------------------------
class CH7516DisplayPortIO extends Bundle {
  val lane0_data = Input(UInt(8.W))
  val lane0_k    = Input(Bool())
  val lane1_data = Input(UInt(8.W))
  val lane1_k    = Input(Bool())
  val lane2_data = Input(UInt(8.W))
  val lane2_k    = Input(Bool())
  val lane3_data = Input(UInt(8.W))
  val lane3_k    = Input(Bool())
}

class CH7516LVDSIO extends Bundle {
  val alvtx0_p   = Output(Bool())
  val alvtx0_n   = Output(Bool())
  val alvtx1_p   = Output(Bool())
  val alvtx1_n   = Output(Bool())
  val alvtx2_p   = Output(Bool())
  val alvtx2_n   = Output(Bool())
  val alvtx3_p   = Output(Bool())
  val alvtx3_n   = Output(Bool())
  val alvtxclk_p = Output(Bool())
  val alvtxclk_n = Output(Bool())
}

// -----------------------------------------------------------------------------
// Chisel BlackBox referencing synthesizable Verilog implementation
// -----------------------------------------------------------------------------
class ch7516_tilelink_mmio(
  val addrWidth: Int = 16,
  val dataWidth: Int = 32,
  val sourceWidth: Int = 4,
  val sizeWidth: Int = 3
) extends BlackBox(Map(
  "ADDR_WIDTH" -> addrWidth,
  "DATA_WIDTH" -> dataWidth,
  "SOURCE_WIDTH" -> sourceWidth,
  "SIZE_WIDTH" -> sizeWidth
)) with HasBlackBoxResource {
  val io = IO(new Bundle {
    val clock        = Input(Clock())
    val reset        = Input(Reset())

    val dp_link_clk  = Input(Clock())
    val pixel_clk    = Input(Clock())
    val lvds_bit_clk = Input(Clock())

    // TileLink-UL Channel A
    val tl_a_valid   = Input(Bool())
    val tl_a_ready   = Output(Bool())
    val tl_a_opcode  = Input(UInt(3.W))
    val tl_a_param   = Input(UInt(3.W))
    val tl_a_size    = Input(UInt(sizeWidth.W))
    val tl_a_source  = Input(UInt(sourceWidth.W))
    val tl_a_address = Input(UInt(addrWidth.W))
    val tl_a_mask    = Input(UInt(4.W))
    val tl_a_data    = Input(UInt(dataWidth.W))

    // TileLink-UL Channel D
    val tl_d_valid   = Output(Bool())
    val tl_d_ready   = Input(Bool())
    val tl_d_opcode  = Output(UInt(3.W))
    val tl_d_param   = Output(UInt(2.W))
    val tl_d_size    = Output(UInt(sizeWidth.W))
    val tl_d_source  = Output(UInt(sourceWidth.W))
    val tl_d_sink    = Output(Bool())
    val tl_d_data    = Output(UInt(dataWidth.W))
    val tl_d_error   = Output(Bool())

    // DisplayPort Inputs
    val dp           = new CH7516DisplayPortIO

    // LVDS Differential Outputs
    val lvds         = new CH7516LVDSIO

    // Interrupt to PLIC
    val interrupt    = Output(Bool())
  })

  addResource("/vsrc/dp_8b10b_decoder.v")
  addResource("/vsrc/dp_descrambler.v")
  addResource("/vsrc/dp_pixel_unpacker_4lane.v")
  addResource("/vsrc/video_async_fifo.v")
  addResource("/vsrc/video_timing_generator.v")
  addResource("/vsrc/video_bist_pattern.v")
  addResource("/vsrc/lvds_formatter_vesa8.v")
  addResource("/vsrc/lvds_serializer_7to1.v")
  addResource("/vsrc/ch7516_dp_to_lvds_top.v")
  addResource("/vsrc/ch7516_tilelink_mmio.v")
}
