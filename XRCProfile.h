// XRCProfile.h — 版本契约。
// 跨版本迁移只改本文件（+ 注入器侧 profiles/<version>.json）。
// 纪律：每个偏移必须有 research/notes 出处注释；禁止只改代码不加出处。
#pragma once

#include <stdint.h>
#include <stdbool.h>

// ---------------- 版本选择 ----------------
#define XRC_PROFILE_ARC_6_13_10  1
#define XRC_PROFILE_ARC_7_0_255  2

#ifndef XRC_ACTIVE_PROFILE
#  define XRC_ACTIVE_PROFILE XRC_PROFILE_ARC_6_13_10
#endif

// ---------------- 共同布局（两端已核实一致） ----------------
// 谱面钟对象布局：6.13 真机验证（ArcDemo seek 平移）；7.0.255 静态核实
// （research/notes/ios-7.0.255-replay-chain.md §4，与 6.13 逐字节一致）。
#define XRC_CLK_FLAG45_OFF       45   // =1 时走分段钟分支（读 +32）
#define XRC_CLK_BASE_OFF         40   // seek 平移目标（base_off）
#define XRC_CLK_ALT_START_OFF    32   // flag45=1 分支的起始值
#define XRC_CLK_CUR_OFF          52   // 非分段钟当前值（<=0 时 -3000 前导）
#define XRC_CLK_NEG_LEAD_MS      (-3000)

// gameplay 对象 → note group（6.13 称 logic）→ 谱面钟
#define XRC_GP_NOTEGROUP_OFF      928
#define XRC_CLOCK_IN_NOTEGROUP_OFF 48

#if XRC_ACTIVE_PROFILE == XRC_PROFILE_ARC_6_13_10
// ================= Arcaea iOS 6.13.10 =================
// 出处: research/notes/ios-6.13.10-stage1-patch-plan.md（真机验证）
// 音频链
#define XRC_OFF_GET_REGISTRY        (0xC9D718ULL)
#define XRC_OFF_GET_CURRENT_SOUND   (0xEC094CULL)
#define XRC_OFF_GET_SOUND_LENGTH    (0xF2BB64ULL)
#define XRC_OFF_CH_GET_POSITION     (0xEC03ACULL)
// 播放器
#define XRC_OFF_MTP_VTABLE          (0x1312860ULL)
#define XRC_OFF_MTP_GETPOS          (0x846950ULL)
#define XRC_PLAYER_SEEK_SLOT_OFF    (0x40)
#define XRC_REG_PLAYER_OFF          (8)
#define XRC_PLAYER_CHANNELS_OFF     (0x38)
#define XRC_CHANNEL_ENTRY_PTR_OFF   (8)
// gameplay
#define XRC_OFF_GP_VTABLE           (0x136E1C0ULL)
#define XRC_OFF_GP_UPDATE_FN        (0xB3AD70ULL)
// 桩点：6.13 无（改判机制未注入；历史 graft 已撤出，见 DEVLOG）
#define XRC_HAS_JUDGE_STUB          0
#define XRC_JUDGE_STUB_ENTRY_OFF    0
#define XRC_JUDGE_SLOT_OFF          0
// 转场重放：6.13 无
#define XRC_HAS_TRANSITION          0

#elif XRC_ACTIVE_PROFILE == XRC_PROFILE_ARC_7_0_255
// ================= Arcaea iOS 7.0.255 =================
// 出处: research/notes/ios-7.0.255-replay-chain.md（IDA 静态核实，待真机验证）
// 音频链：待重定位（6.13 条目已失效）——占位 0，安装时自动降级
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
// GameScene（replay-chain 笔记 §2；vtable RTTI 名 9GameScene 已验）
// 注意：本文件所有值均为 image 偏移（运行时地址 = image_base + offset）。
#define XRC_OFF_GP_VTABLE           (0x151D8C0ULL)   // 绝对 VA 0x10151D8C0
#define XRC_OFF_GP_UPDATE_FN        0   // TODO: 逐帧更新槽待真机确认
// 桩点（改判）——收敛架构 spec §2
#define XRC_HAS_JUDGE_STUB          1
#define XRC_JUDGE_STUB_ENTRY_OFF    (0x9D9ED8ULL)  // sub_1009D9ED8，ABI: X0=note X8=out 无 sret
#define XRC_JUDGE_SLOT_OFF          0   // TODO: 注入后由 inject.py 回填 __xrc_slots 运行时偏移
// note 字段（改判 handler 读；replay-chain 笔记 §3.2）
#define XRC_NOTE_TYPE_OFF           28
#define XRC_NOTE_TIME_OFF           24
#define XRC_NOTE_PURE_OFF           32
#define XRC_NOTE_FAR_OFF            36
#define XRC_NOTE_LOST_OFF           40
// 转场重放 —— replay-chain 笔记 §6（纯 dylib，零桩点）
#define XRC_HAS_TRANSITION          1
#define XRC_TRANSITION_VTABLE_SLOT  178
#define XRC_TRANSITION_FLAG_OFF     1144  // a2=1 转场标志
#define XRC_RESUME_POS_OFF          1140  // 新场景恢复位置（ms）

#endif
