// xrc_abi.h — ArcDemo 与注入器（inject.py）共享的 ABI 契约。
// 未来抽取到 projects/core 的候选文件：slot 布局 + info blob + handler 签名。
#pragma once

#include <stdint.h>

#define XRC_MAGIC 0x58424331  // 'XRC1'

// __xrc_slots 段内每桩点 16 字节。
// handler = 0 时 trampoline 原样直通（行为与未注入一致）。
struct xrc_slot {
    void    *handler;   // dylib 运行时注册；完全接管，不调原函数
    void    *orig;      // 注入器写入原入口（未重定位）；运行时 = image_base + (off)
};

// info blob（__DATA 零填充区，dyld 不 rebase）：
// dylib 启动扫描 magic → 用 *静态偏移* 手动重定位所有 VA。
// 这是"桩点回报信息"机制：运行时提取的地址比静态逆向准确。
struct xrc_info {
    uint32_t magic;          // XRC_MAGIC
    uint32_t version;        // 1
    uint64_t judge_entry_off;// sub_1009D9ED8 静态偏移
    uint64_t judge_slot_off; // slot 静态偏移
    uint64_t gp_vtable_off;  // GameScene vtable 静态偏移
    uint64_t gp_update_off;  // 槽 103 每帧函数静态偏移
    uint64_t mtp_vtable_off; // MTP vtable 静态偏移
    uint64_t mtp_getpos_off; // 槽 7 静态偏移
    uint64_t reserved[8];    // 未来桩点/锚点
};

// 改判 handler（完全接管 sub_1009D9ED8 的语义）。
// ABI（7.0.255 已确认）：X0=note 指针，X8=out 指针，无 sret，返回 X0。
// 版本相关输入只有 note 字段偏移（XRCProfile.h），逻辑版本无关。
typedef uint64_t (*xrc_judge_handler_t)(uint64_t note, void *out);
