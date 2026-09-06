// xrc_abi.h — ArcDemo 与注入器（inject.py）共享的 ABI 契约。
// 未来抽取到 projects/core 的候选文件：slot 布局 + handler 签名。
#pragma once

#include <stdint.h>

// __xrc_slots 段内每桩点 16 字节。
// handler = 0 时 trampoline 原样直通（行为与未注入一致）。
struct xrc_slot {
    void    *handler;   // dylib 运行时注册；完全接管，不调原函数
    void    *orig;      // 注入器写入原入口；dylib 只读
};

// 改判 handler（完全接管 sub_1009D9ED8 的语义）。
// ABI（7.0.255 已确认）：X0=note 指针，X8=out 指针，无 sret，返回 X0。
// 版本相关输入只有 note 字段偏移（XRCProfile.h），逻辑版本无关。
typedef uint64_t (*xrc_judge_handler_t)(uint64_t note, void *out);
