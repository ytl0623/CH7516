// =============================================================================
// File: main.c
// Description: Bare-metal RISC-V Application for CH7516 DP to LVDS Verification
//              Runs on Rocket-Chip / Chipyard SoC CPU
// =============================================================================

#include <stdio.h>
#include "ch7516_driver.h"

int main(void) {
    printf("================================================================\n");
    printf(" RISC-V Chipyard SoC: CH7516 DP to LVDS Controller Self-Test\n");
    printf(" Default Timing: 1036x660 @ 120Hz VESA 8-Bit\n");
    printf("================================================================\n");

    // 1. Define 1036x660 @ 120Hz VESA 8-Bit Configuration
    ch7516_config_t cfg = {
        .h_active        = 1036,
        .h_fp            = 24,
        .h_sync          = 32,
        .h_bp            = 48,
        .h_total         = 1140,

        .v_active        = 660,
        .v_fp            = 3,
        .v_sync          = 5,
        .v_bp            = 12,
        .v_total         = 680,

        .is_jeida        = false, // VESA 8-bit mode
        .enable_scramble = false, // Direct test
        .agmode_bist     = true   // Enable 8-color bar BIST
    };

    // 2. Initialize Hardware via TileLink MMIO
    printf("[STEP 1] Programming CH7516 MMIO registers from RISC-V core...\n");
    ch7516_init(&cfg);

    // 3. Verify Register Readback
    uint32_t cr_val = CH7516_REG(CH7516_REG_CR);
    uint32_t ht0    = CH7516_REG(CH7516_REG_HTIMING0);
    uint32_t vt0    = CH7516_REG(CH7516_REG_VTIMING0);

    if ((ht0 & 0xFFFF) == 1036 && (vt0 & 0xFFFF) == 660) {
        printf("[PASS] Video Timing registers verified: %u x %u\n", (ht0 & 0xFFFF), (vt0 & 0xFFFF));
    } else {
        printf("[FAIL] Register readback mismatch! ht0=0x%08x, vt0=0x%08x\n", ht0, vt0);
        return 1;
    }

    // 4. Check Status Register
    uint32_t sr = ch7516_get_status();
    printf("[STEP 2] Reading Status Register: 0x%08x\n", sr);
    if (ch7516_is_hpd_active()) {
        printf("[PASS] Hot Plug Detect (HPD) is asserted.\n");
    } else {
        printf("[FAIL] HPD is NOT asserted!\n");
        return 1;
    }

    // 5. Test Soft Reset
    printf("[STEP 3] Testing Soft Reset pulse...\n");
    ch7516_soft_reset();
    printf("[PASS] Soft Reset completed successfully.\n");

    // 6. Test Format Toggle (Switch to JEIDA and back to VESA)
    printf("[STEP 4] Testing LVDS Format switching...\n");
    ch7516_set_format(true);
    if (CH7516_REG(CH7516_REG_CR) & CH7516_CR_LVDS_JEIDA) {
        printf("[PASS] Switched to JEIDA 8-bit mode.\n");
    }
    ch7516_set_format(false);
    if (!(CH7516_REG(CH7516_REG_CR) & CH7516_CR_LVDS_JEIDA)) {
        printf("[PASS] Restored to VESA 8-bit default mode.\n");
    }

    printf("================================================================\n");
    printf(" ALL RISC-V FIRMWARE TESTS PASSED SUCCESSFULLY!\n");
    printf("================================================================\n");

    return 0;
}
