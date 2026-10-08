// =============================================================================
// File: ch7516_driver.h
// Description: C Driver API for CH7516 DP to LVDS Controller on RISC-V SoC
// =============================================================================

#ifndef CH7516_DRIVER_H
#define CH7516_DRIVER_H

#include "ch7516_regs.h"
#include <stdbool.h>

typedef struct {
    uint16_t h_active;
    uint16_t h_fp;
    uint16_t h_sync;
    uint16_t h_bp;
    uint16_t h_total;

    uint16_t v_active;
    uint16_t v_fp;
    uint16_t v_sync;
    uint16_t v_bp;
    uint16_t v_total;

    bool is_jeida;
    bool enable_scramble;
    bool agmode_bist;
} ch7516_config_t;

void ch7516_init(const ch7516_config_t *cfg);
void ch7516_soft_reset(void);
void ch7516_set_bist_mode(bool enable_bist);
void ch7516_set_format(bool is_jeida);
uint32_t ch7516_get_status(void);
bool ch7516_is_hpd_active(void);
bool ch7516_is_link_locked(void);
bool ch7516_is_stream_active(void);
bool ch7516_is_fail_detected(void);

#endif // CH7516_DRIVER_H
