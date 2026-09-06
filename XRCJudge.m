// XRCJudge.m — 改判：slot 注册 + 完全接管 handler。
// 完全接管 sub_1009D9ED8（7.0.255，ABI 已确认：X0=note，X8=out，无 sret）。
// 逻辑版本无关：note 字段偏移从 XRCProfile.h 读取。
// TODO(v1.1)：窗口值语义按表 B 消费格式完成（replay-chain 笔记 §9 待解码后实现）。

#import <Foundation/Foundation.h>
#import "AccCommon.h"    // acc_flog
#include "XRCJudge.h"
#include "XRCProfile.h"
#include "XRCRuntime.h"
#include "xrc_abi.h"

static _Atomic(int) s_win_max  = 25;
static _Atomic(int) s_win_pure = 50;
static _Atomic(int) s_win_far  = 100;
static _Atomic(int) s_win_lost = 120;

// ---- 完全接管 handler（X0=note, X8=out）----
// 7.0.255 窗口求值器输出语义（IDA 已确认）：*out = 单个 f32 窗口值（ms），
// caller 把它加到特效时间基上（sub_100BB5508 L115 vadd_f32）。
// handler 采用"缩放"路线：调原函数拿基准窗口 → 乘用户缩放 → 写回。
// 无需复刻表 B（note 类型分派原函数自己做）。
#if XRC_HAS_JUDGE_STUB
// 原函数入口（安装时从 g_xrc.judge_entry 取——运行时重定位值）。
static uint64_t (*s_orig_judge)(uint64_t note, void *out) = NULL;
static _Atomic(float) s_window_scale = 1.0f;

static uint64_t s_xrc_judge_handler(uint64_t note, void *out) {
    if (!s_orig_judge || !out) {
        if (out) *(uint64_t *)out = 0;
        return 0;
    }
    uint64_t r = s_orig_judge(note, out);
    float scale = atomic_load(&s_window_scale);
    if (scale < 0.999f || scale > 1.001f) {
        float w = *(float *)out;
        *(float *)out = w * scale;
    }
    return r;
}
#endif

// 窗口缩放（由配置四档换算：scale = (max+pure+far+lost)/270.0，默认 25/50/100/120）
void xrc_judge_set_scale(float scale) {
    if (scale < 0.1f) scale = 0.1f;
    if (scale > 5.0f) scale = 5.0f;
    atomic_store(&s_window_scale, scale);
}

float xrc_judge_get_scale(void) {
    return atomic_load(&s_window_scale);
}

static _Atomic(bool) s_judge_active = false;

bool xrc_judge_is_active(void) {
    return atomic_load(&s_judge_active);
}

bool xrc_judge_install(uint64_t image_base) {
#if XRC_HAS_JUDGE_STUB
    uint64_t slot_va = g_xrc.judge_slot;
    if (!slot_va) {
        acc_flog(@"judge stub: slot anchor missing (stub not injected?)");
        return false;
    }
    struct xrc_slot *slot = (struct xrc_slot *)slot_va;
    // slot.orig 是注入器写的静态地址（未重定位）；ASLR 下必须手动重定位。
    // 正确值也以 g_xrc.judge_entry（info blob 重定位）为准。
    s_orig_judge = (uint64_t (*)(uint64_t, void *))(g_xrc.judge_entry);
    if (!s_orig_judge || (uint64_t)s_orig_judge < 0x100000000ULL) {
        acc_flog(@"judge stub: judge_entry anchor invalid (%p)", (void *)s_orig_judge);
        return false;
    }
    // 完全接管：写 handler 指针即接管；写 0 即原生直通（trampoline 保证）。
    slot->handler = (void *)&s_xrc_judge_handler;
    atomic_store(&s_judge_active, true);
    acc_flog(@"judge handler installed at slot %p (orig=%p)", (void *)slot, (void *)s_orig_judge);
    return true;
#else
    (void)image_base;
    return false;
#endif
}

void xrc_judge_set_windows(int max_ms, int pure_ms, int far_ms, int lost_ms) {
    atomic_store(&s_win_max,  max_ms);
    atomic_store(&s_win_pure, pure_ms);
    atomic_store(&s_win_far,  far_ms);
    atomic_store(&s_win_lost, lost_ms);
}

void xrc_judge_get_windows(int *max_ms, int *pure_ms, int *far_ms, int *lost_ms) {
    if (max_ms)  *max_ms  = atomic_load(&s_win_max);
    if (pure_ms) *pure_ms = atomic_load(&s_win_pure);
    if (far_ms)  *far_ms  = atomic_load(&s_win_far);
    if (lost_ms) *lost_ms = atomic_load(&s_win_lost);
}
