// =============================================================================
// File: ch7516_driver.c
// Description: C Driver Implementation for CH7516 DP to LVDS Controller
// =============================================================================

#include "ch7516_driver.h"

void ch7516_init(const ch7516_config_t *cfg) {
    if (!cfg) return;

    // 1. Program Horizontal Timing
    CH7516_REG(CH7516_REG_HTIMING0) = ((uint32_t)cfg->h_fp << 16) | (uint32_t)cfg->h_active;
    CH7516_REG(CH7516_REG_HTIMING1) = ((uint32_t)cfg->h_bp << 16) | (uint32_t)cfg->h_sync;

    // 2. Program Vertical Timing
    CH7516_REG(CH7516_REG_VTIMING0) = ((uint32_t)cfg->v_fp << 16) | (uint32_t)cfg->v_active;
    CH7516_REG(CH7516_REG_VTIMING1) = ((uint32_t)cfg->v_bp << 16) | (uint32_t)cfg->v_sync;

    // 3. Program Total Raster Timing
    CH7516_REG(CH7516_REG_TOTAL_TIMING) = ((uint32_t)cfg->v_total << 16) | (uint32_t)cfg->h_total;

    // 4. Configure Control Register
    uint32_t cr = CH7516_CR_EN;
    if (cfg->is_jeida)         cr |= CH7516_CR_LVDS_JEIDA;
    if (cfg->enable_scramble)  cr |= CH7516_CR_SCRAMBLE_EN;
    if (cfg->agmode_bist)      cr |= CH7516_CR_AGMODE;

    CH7516_REG(CH7516_REG_CR) = cr;
}

void ch7516_soft_reset(void) {
    uint32_t cr = CH7516_REG(CH7516_REG_CR);
    CH7516_REG(CH7516_REG_CR) = cr | CH7516_CR_SOFT_RST;
    CH7516_REG(CH7516_REG_CR) = cr & ~CH7516_CR_SOFT_RST;
}

void ch7516_set_bist_mode(bool enable_bist) {
    uint32_t cr = CH7516_REG(CH7516_REG_CR);
    if (enable_bist) {
        cr |= CH7516_CR_AGMODE;
    } else {
        cr &= ~CH7516_CR_AGMODE;
    }
    CH7516_REG(CH7516_REG_CR) = cr;
}

void ch7516_set_format(bool is_jeida) {
    uint32_t cr = CH7516_REG(CH7516_REG_CR);
    if (is_jeida) {
        cr |= CH7516_CR_LVDS_JEIDA;
    } else {
        cr &= ~CH7516_CR_LVDS_JEIDA;
    }
    CH7516_REG(CH7516_REG_CR) = cr;
}

uint32_t ch7516_get_status(void) {
    return CH7516_REG(CH7516_REG_SR);
}

bool ch7516_is_hpd_active(void) {
    return (CH7516_REG(CH7516_REG_SR) & CH7516_SR_HPD) != 0;
}

bool ch7516_is_link_locked(void) {
    return (CH7516_REG(CH7516_REG_SR) & CH7516_SR_LINK_LOCKED) != 0;
}

bool ch7516_is_stream_active(void) {
    return (CH7516_REG(CH7516_REG_SR) & CH7516_SR_STREAM_ACTIVE) != 0;
}

bool ch7516_is_fail_detected(void) {
    return (CH7516_REG(CH7516_REG_SR) & CH7516_SR_FAIL_FLAG) != 0;
}
