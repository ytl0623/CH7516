// =============================================================================
// File: ch7516_regs.h
// Description: Memory-Mapped Register Definitions for CH7516 DP to LVDS Bridge
//              Target Architecture: RISC-V (RV32 / RV64) in Chipyard SoC
// =============================================================================

#ifndef CH7516_REGS_H
#define CH7516_REGS_H

#include <stdint.h>

#define CH7516_BASE_ADDR        0x20000000UL

// Register Byte Offsets
#define CH7516_REG_CR           0x00  // Control Register
#define CH7516_REG_SR           0x04  // Status Register (Read-Only)
#define CH7516_REG_HTIMING0     0x08  // H_ACTIVE [15:0], H_FP [31:16]
#define CH7516_REG_HTIMING1     0x0C  // H_SYNC [15:0], H_BP [31:16]
#define CH7516_REG_VTIMING0     0x10  // V_ACTIVE [15:0], V_FP [31:16]
#define CH7516_REG_VTIMING1     0x14  // V_SYNC [15:0], V_BP [31:16]
#define CH7516_REG_TOTAL_TIMING 0x18  // H_TOTAL [15:0], V_TOTAL [31:16]
#define CH7516_REG_IER          0x1C  // Interrupt Enable Register
#define CH7516_REG_ISR          0x20  // Interrupt Status Register (W1C)

// Control Register (CR) Bit Fields
#define CH7516_CR_EN            (1U << 0) // Core Enable
#define CH7516_CR_SOFT_RST      (1U << 1) // Soft Reset
#define CH7516_CR_AGMODE        (1U << 2) // AGMODE: 1=BIST Color Bar, 0=Black Panel
#define CH7516_CR_LVDS_JEIDA    (1U << 3) // LVDS Format: 0=VESA 8-bit, 1=JEIDA 8-bit
#define CH7516_CR_SCRAMBLE_EN   (1U << 4) // DP Descrambler Enable

// Status Register (SR) Bit Fields
#define CH7516_SR_HPD           (1U << 0) // Hot Plug Detect Status
#define CH7516_SR_FAIL_FLAG     (1U << 1) // Signal Loss / Failure Flag
#define CH7516_SR_LINK_LOCKED   (1U << 2) // DP Link Framing Locked
#define CH7516_SR_STREAM_ACTIVE (1U << 3) // Video Stream Active

// Hardware MMIO Access Macros
#define CH7516_REG(offset) (*(volatile uint32_t *)((uintptr_t)(CH7516_BASE_ADDR + (offset))))

#endif // CH7516_REGS_H
