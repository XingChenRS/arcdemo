// XRCGameplay.h — gp.update hook + 谱面钟 retime + seek + 转场重放。
#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <limits.h>

// vtable swizzle（PAC 感知；6.13 验证过的实现迁入）。
// 返回槽号，INT_MIN 失败。out_orig 为剥离签名的原函数指针。
int xrc_swizzle_vtable(uint64_t vtable_addr, uint64_t orig_fn_off, void *new_fn, void **out_orig);

// 安装 gameplay vtable hook（换速 retime）。
void xrc_gameplay_install_hooks(uint64_t image_base);

// gp.update 替换实现（self = GameScene；7.0 单参）。
void xrc_gameplay_update(void *self);

// seek：音频 seek + 谱面钟平移（6.13 已验证语义）。
void xrc_seek_ms(uint32_t ms);

// 读取谱面钟当前值（按 XRCProfile 的 clock 布局）。
int32_t xrc_chart_clock_ms(void *note_group);

// 转场重放（7.0 转场机制；XRC_HAS_TRANSITION=0 的版本无实现）。
// resume: 是否带进度重开（a2=1）。
bool xrc_transition_resume(void *gameplay, bool resume);
// A-B 循环状态：dylib 侧存 A/B；由 gp.update 内部轮询触发（无需外部调用）。
bool xrc_loop_get_enabled(void);
void xrc_loop_set_range(uint32_t a_ms, uint32_t b_ms);
// gp.update 内部调用（7.0 转场版本才有实现）。
void xrc_loop_tick(void *gameplay, uint32_t pos_ms);
