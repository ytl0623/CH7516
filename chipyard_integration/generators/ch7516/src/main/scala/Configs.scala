package chipyard.ch7516

import org.chipsalliance.cde.config.{Config, Parameters}

// -----------------------------------------------------------------------------
// Chipyard Configuration Fragment to include CH7516 Peripheral
// -----------------------------------------------------------------------------
class WithCH7516DPLVDS(address: BigInt = 0x20000000L) extends Config((site, here, up) => {
  case CH7516Key => Some(CH7516Params(address = address))
})
