// XRCJudge.m — 改判：slot 注册 + 完全接管 handler。
// 完全接管 sub_1009D9ED8（7.0.255，ABI 已确认：X0=note，X8=out，无 sret）。
// 逻辑版本无关：note 字段偏移从 XRCProfile.h 读取。
// TODO(v1.1)：窗口值语义按表 B 消费格式完成（replay-chain 笔记 §9 待解码后实现）。

#import <Foundation/Foundation.h>
#import "AccCommon.h"    // acc_flog
#include "XRCJudge.h"
#include "XRCProfile.h"
#include "xrc_abi.h"

static _Atomic(int) s_win_max  = 25;
static _Atomic(int) s_win_pure = 50;
static _Atomic(int) s_win_far  = 100;
static _Atomic(int) s_win_lost = 120;

// ---- 完全接管 handler（X0=note, X8=out）----
#if XRC_HAS_JUDGE_STUB
static uint64_t s_xrc_judge_handler(uint64_t note, void *out) {
    if (!note || !out) return 0;
    // note 字段（profile 行）：
    int32_t type = *(int32_t *)(note + XRC_NOTE_TYPE_OFF);
    // TODO(v1.1)：按表 B 消费格式写窗口值对到 *out。
    // 当前骨架：写 0 占位（等于原函数入口的 *out=0 语义），handler 通路验证用。
    (void)type;
    *(uint64_t *)out = 0;
    return 0;
}
#endif

bool xrc_judge_install(uint64_t image_base) {
#if XRC_HAS_JUDGE_STUB
    if (!XRC_JUDGE_SLOT_OFF) {
        acc_flog(@"judge stub: slot offset not filled (injector not run?)");
        return false;
    }
    struct xrc_slot *slot = (struct xrc_slot *)(image_base + XRC_JUDGE_SLOT_OFF);
    // 完全接管：写 handler 指针即接管；写 0 即原生直通（trampoline 保证）。
    slot->handler = (void *)&s_xrc_judge_handler;
    acc_flog(@"judge handler installed at slot %p", (void *)slot);
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
