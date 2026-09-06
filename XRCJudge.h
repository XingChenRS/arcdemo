// XRCJudge.h — 改判：slot 注册 + 完全接管 handler。
#pragma once

#include <stdint.h>

// 在找到 __xrc_slots（桩点注入后）时注册 handler。slot_off 来自 profile。
// 返回是否注册成功（未打桩的版本返回 false，静默降级）。
bool xrc_judge_install(uint64_t image_base);

// 配置窗口（由 XRCConfig 调用）：max/pure/far/lost ms。
void xrc_judge_set_windows(int max_ms, int pure_ms, int far_ms, int lost_ms);

// 当前生效窗口（UI 显示用）。
void xrc_judge_get_windows(int *max_ms, int *pure_ms, int *far_ms, int *lost_ms);
