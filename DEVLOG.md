# DEVLOG

ArcDemo 演进记录。能力状态标记与 [xrc 能力账本](../../research/notes/xrc-arcaea-capability-ledger-2026-08-31.md) 对齐（XRC-R 运行中 / XRC-V 已验证 / XRC-S 静态闭环 / PROTO 失败原型 / OPEN 未闭合）。

## 2026-09-07 — Deferred 状态机 + 能力门控

- 崩溃修复：转场/seek 全部 deferred 到 gp.update 游戏循环内执行（UI 回调里旧场景可能已释放 → UAF）。状态机：SEEK / SEEK_REPLAY / LOOP_REWIND 三种操作，1.5s 冷却、4s 过期丢弃、代计数。UI 只登记。
- 能力门控（不做双编译）：stub 未激活 → 改判区隐藏只读；seek-replay 默认关（config seekReplay，先跑稳纯 seek）；循环 UI 按转场能力显示。
- A-B 循环改为 ArcCreate 练习模式风格：From/To 两次点击 + On/Off，To ≥ From+1000ms 夹取。
- XRCRuntime 诊断日志（DATA 范围 + 预期 slot 字节）——runtime info 在真机仍 NOT found，下次日志定位。
- 窗口求值器输出语义确认：*out = 单个 f32 窗口 ms（caller vadd_f32 到特效时间基），handler 用"调原函数 + 缩放"路线，无需复刻表 B。

## 2026-09-06 — 音频链重定位（seek/进度条恢复）

- MTP vtable = `0x1014B75B0`（RTTI 名 `20AudioProviderFMODiOS` 经 typeinfo `0x1014B7690` 验证）；getpos 槽 7 = `sub_1008E24F0`、seek 槽 8 = `sub_1008E253C`（形状与 6.13 逐条一致）。
- `Channel::getPosition` 内层 = `sub_101033BBC`；`Channel::getCurrentSound` = `sub_10103415C`（日志串 "Channel::getCurrentSound" 已验）。
- get_sound_length / registry 不追：进度条用 max_seen 兜底；player 实例由 getpos hook 直接缓存（不需要 registry 单例）。
- 决策确认：不 hook FMOD 变速（音画同步已 DNR），只做读位置 + seekTo——与 6.13 同做法。

## 2026-09-06 — 基准切换：7.0.255（6.13 适配废弃）

- 6.13 适配废弃：删除 `include/ArcOffsets.h`（git 历史保留）；`XRCProfile.h` 单版本 7.0.255。
- gp.update 重定位：GameScene vtable 槽 155 = `sub_100CA118C`（单参 `(GameScene*)`；内含 HUD syncer 调用 `0x100ca368c`）。谱面变速 hook 点就绪，待真机验证。
- 音频链决策：不 hook FMOD/音频链。seek 与进度条在 7.0 降级为"未就绪"（UI 禁用，谱面钟平移保留、音频不动）。若日后恢复，先重定位 6.13 的四个锚点（get_registry/get_current_sound/get_sound_length/ch_get_position）与 MTP vtable。
- CI 三级缓存（Theos/SDK/ellekit）就绪并验证命中：重跑时 Clone Theos / Download SDK / Build ellekit 全部 skipped。

## 2026-09-06 — 架构收敛（v2 spec 定稿）

决策（与 xrc 研究同步）：

- **改判**：唯一侵入主二进制的功能。桩点 = `sub_1009D9ED8`（7.0.255 判定区间求值器，表 B 消费点），完全接管 handler；ABI 已确认（X0=note、X8=out_ptr、无 sret）。四桩点方案收敛为单桩点；Locator / LC_XRC_INFO 废弃。
- **seek-replay / A-B 循环**：走 7.0 自带转场机制（`sub_100CA9590`，GameScene vtable 槽 178，a2=1 带进度重开；新场景 +1140=恢复位置，启动时 `sub_1009204E4` 跳过 T 前音符）。**纯 dylib，零桩点**。判定提交拦截降级为可选。白闪帧为预期形态（游戏原生转场表现），已接受。
- **拖拽进度条实时预览**：放弃。
- **音画同步 / BGM 变速**：不再追（FMOD 变速失败史 + DSP 时间拉伸成本过高）。
- 源码整改：Tweak.x 单体拆分（XRCClock/XRCPlayer/XRCGameplay/XRCJudge/XRCConfig + XRCProfile.h + xrc_abi.h）；跨版本只动 profile。
- 依据笔记：`research/notes/ios-7.0.255-replay-chain.md`（转场机制反编译全链）；spec：`docs/superpowers/specs/2026-09-06-arcdemo-7.0-converged-architecture.md`。

## Scope Reset（历史，保留）

活动树曾重置为纯侧载分支。

保留：谱面变速（Gameplay.update vtable）、视觉变速（gettimeofday）、基础音乐播放器 seek、悬浮 UI 与 plist 配置、判定参数 UI（供后续设计使用）。

移除：特权安装构建变体、主程序 payload 注入实验、运行时 `__TEXT` patch 尝试、静态判定 patch helper、音频变速与漂移校正实验、note replay / scorekeeper reset 实验、重复遗留工程。

历史教训（PROTO）：

- 运行时改写主 `__TEXT` 在普通侧载下不可行（页签名）。
- v7.3 graft（entry→trampoline→`__DATA` slot）概念可行，但 Mach-O 布局修改不完整导致失败——本次以"新增独立段"根治（见收敛版 spec §2）。
- note 对象级 replay（清 active list / 重激活 / vtable 手术）导致 UAF，已判死——7.0 重放改走游戏转场机制。
