package chipyard.ch7516

import chisel3._
import chisel3.util._
import org.chipsalliance.cde.config.{Parameters, Field}
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.prci._

// -----------------------------------------------------------------------------
// Parameters for CH7516 Peripheral
// -----------------------------------------------------------------------------
case class CH7516Params(
  address: BigInt = 0x20000000L,
  size: BigInt = 0x1000L // 4KB MMIO space
)

case object CH7516Key extends Field[Option[CH7516Params]](None)

// -----------------------------------------------------------------------------
// LazyModule attaching to TileLink Periphery Bus
// -----------------------------------------------------------------------------
class CH7516TL(params: CH7516Params, beatBytes: Int)(implicit p: Parameters) extends LazyModule {
  val node = TLRegisterNode(
    address = Seq(AddressSet(params.address, params.size - 1)),
    device = new SimpleDevice("ch7516-dp-lvds", Seq("chrontel,ch7516a")),
    beatBytes = beatBytes
  )

  lazy val module = new Impl
  class Impl extends LazyModuleImp(this) {
    val io = IO(new Bundle {
      val dp_link_clk  = Input(Clock())
      val pixel_clk    = Input(Clock())
      val lvds_bit_clk = Input(Clock())

      val dp           = new CH7516DisplayPortIO
      val lvds         = new CH7516LVDSIO
      val interrupt    = Output(Bool())
    })

    val (tl, edge) = node.in(0)

    val blackbox = Module(new ch7516_tilelink_mmio(
      addrWidth = 16,
      dataWidth = 32,
      sourceWidth = edge.bundle.sourceBits,
      sizeWidth = edge.bundle.sizeBits
    ))

    blackbox.io.clock        := clock
    blackbox.io.reset        := reset
    blackbox.io.dp_link_clk  := io.dp_link_clk
    blackbox.io.pixel_clk    := io.pixel_clk
    blackbox.io.lvds_bit_clk := io.lvds_bit_clk

    // TileLink A Channel
    blackbox.io.tl_a_valid   := tl.a.valid
    tl.a.ready               := blackbox.io.tl_a_ready
    blackbox.io.tl_a_opcode  := tl.a.bits.opcode
    blackbox.io.tl_a_param   := tl.a.bits.param
    blackbox.io.tl_a_size    := tl.a.bits.size
    blackbox.io.tl_a_source  := tl.a.bits.source
    blackbox.io.tl_a_address := tl.a.bits.address(15, 0)
    blackbox.io.tl_a_mask    := tl.a.bits.mask
    blackbox.io.tl_a_data    := tl.a.bits.data

    // TileLink D Channel
    tl.d.valid               := blackbox.io.tl_d_valid
    blackbox.io.tl_d_ready   := tl.d.ready
    tl.d.bits.opcode         := blackbox.io.tl_d_opcode
    tl.d.bits.param          := blackbox.io.tl_d_param
    tl.d.bits.size           := blackbox.io.tl_d_size
    tl.d.bits.source         := blackbox.io.tl_d_source
    tl.d.bits.sink           := blackbox.io.tl_d_sink
    tl.d.bits.data           := blackbox.io.tl_d_data
    tl.d.bits.corrupt        := blackbox.io.tl_d_error
    tl.d.bits.denied         := blackbox.io.tl_d_error

    // DisplayPort and LVDS IO
    blackbox.io.dp           <> io.dp
    io.lvds                  <> blackbox.io.lvds
    io.interrupt             := blackbox.io.interrupt
  }
}

// -----------------------------------------------------------------------------
// Subsystem Integration Trait
// -----------------------------------------------------------------------------
trait CanHavePeripheryCH7516 { this: BaseSubsystem =>
  val ch7516Node = p(CH7516Key).map { params =>
    val ch7516 = LazyModule(new CH7516TL(params, pbus.beatBytes)(p))
    pbus.coupleTo("ch7516") { ch7516.node := TLFragmenter(pbus.beatBytes, pbus.blockBytes) := _ }
    ch7516
  }
}

trait CanHavePeripheryCH7516ModuleImp extends LazyModuleImp {
  val outer: CanHavePeripheryCH7516
  val ch7516_io = outer.ch7516Node.map { ch7516 =>
    val io = IO(new Bundle {
      val dp_link_clk  = Input(Clock())
      val pixel_clk    = Input(Clock())
      val lvds_bit_clk = Input(Clock())

      val dp           = new CH7516DisplayPortIO
      val lvds         = new CH7516LVDSIO
      val interrupt    = Output(Bool())
    })
    io.dp_link_clk  := ch7516.module.io.dp_link_clk
    io.pixel_clk    := ch7516.module.io.pixel_clk
    io.lvds_bit_clk := ch7516.module.io.lvds_bit_clk
    ch7516.module.io.dp <> io.dp
    io.lvds         <> ch7516.module.io.lvds
    io.interrupt    := ch7516.module.io.interrupt
    io
  }
}
