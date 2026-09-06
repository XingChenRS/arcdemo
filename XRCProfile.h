// XRCProfile.h — 版本契约（Arcaea iOS 7.0.255）。
// 跨版本迁移只改本文件（+ 注入器侧 profiles/<version>.json）。
// 纪律：每个偏移必须有 research/notes 出处注释；禁止只改代码不加出处。
// 6.13 适配已废弃（见 DEVLOG 2026-09-06）；历史 6.13 偏移在 git 历史与
// research/notes/ios-6.13.10-stage1-patch-plan.md。
#pragma once

#include <stdint.h>
#include <stdbool.h>

// ---------------- 谱面钟对象布局 ----------------
// 出处: research/notes/ios-7.0.255-replay-chain.md §4
// （与 6.13 真机验证的布局逐字节一致；+45 标志/+40 base/+52 当前/-3000 前导）。
#define XRC_CLK_FLAG45_OFF        45   // =1 时走分段钟分支（读 +32）
#define XRC_CLK_BASE_OFF          40   // seek 平移目标（base_off）
#define XRC_CLK_ALT_START_OFF     32   // flag45=1 分支的起始值
#define XRC_CLK_CUR_OFF           52   // 非分段钟当前值（<=0 时 -3000 前导）
#define XRC_CLK_NEG_LEAD_MS       (-3000)

// gameplay 对象 → note group（6.13 称 logic）→ 谱面钟
#define XRC_GP_NOTEGROUP_OFF       928
#define XRC_CLOCK_IN_NOTEGROUP_OFF 48

// ---------------- GameScene ----------------
// 出处: research/notes/ios-7.0.255-replay-chain.md §2
// （vtable RTTI 名 9GameScene 已验；本文件所有值均为 image 偏移，
//   运行时地址 = image_base + offset）
#define XRC_OFF_GP_VTABLE          (0x151D8C0ULL)   // 绝对 VA 0x10151D8C0
#define XRC_OFF_GP_UPDATE_FN       (0xCA118CULL)    // vtable 槽 155：单参 (GameScene*)
                                                    // = 6.13 gp.update 等价物（内含 HUD syncer 调用 0x100ca368c）

// ---------------- 桩点（改判） ----------------
// 出处: 收敛版架构 spec §2（ABI 已确认：X0=note, X8=out_ptr, 无 sret）
#define XRC_HAS_JUDGE_STUB          1
#define XRC_JUDGE_STUB_ENTRY_OFF    (0x9D9ED8ULL)   // sub_1009D9ED8（判定区间求值器，表 B 消费点）
#define XRC_JUDGE_SLOT_OFF          0   // TODO: 注入后由 inject.py 回填 __xrc_slots 运行时偏移

// note 字段（改判 handler 读；replay-chain 笔记 §3.2）
#define XRC_NOTE_TYPE_OFF           28
#define XRC_NOTE_TIME_OFF           24
#define XRC_NOTE_PURE_OFF           32
#define XRC_NOTE_FAR_OFF            36
#define XRC_NOTE_LOST_OFF           40

// ---------------- 转场重放 ----------------
// 出处: research/notes/ios-7.0.255-replay-chain.md §6（纯 dylib，零桩点）
#define XRC_HAS_TRANSITION          1
#define XRC_TRANSITION_VTABLE_SLOT  178
#define XRC_TRANSITION_FLAG_OFF     1144  // a2=1 转场标志
#define XRC_RESUME_POS_OFF          1140  // 新场景恢复位置（ms）

// ---------------- 音频链（seek/进度） ----------------
// 决策（2026-09-06）：不 hook FMOD/音频链，seek 与进度条在 7.0 降级为未就绪。
// 谱面/视觉变速与改判不受影响。若日后恢复音频 seek，先重定位以下四个
// 6.13 锚点（get_registry/get_current_sound/get_sound_length/ch_get_position）
// 与 MTP vtable，再填此表。
#define XRC_OFF_GET_REGISTRY        0
#define XRC_OFF_GET_CURRENT_SOUND   0
#define XRC_OFF_GET_SOUND_LENGTH    0
#define XRC_OFF_CH_GET_POSITION     0
#define XRC_OFF_MTP_VTABLE          0
#define XRC_OFF_MTP_GETPOS          0
#define XRC_PLAYER_SEEK_SLOT_OFF    (0x40)
#define XRC_REG_PLAYER_OFF          (8)
#define XRC_PLAYER_CHANNELS_OFF     (0x38)
#define XRC_CHANNEL_ENTRY_PTR_OFF   (8)
