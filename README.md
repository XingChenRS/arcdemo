# ArcDemo（xrc · runtime-ios）

Arcaea iOS 侧载 dylib：练习向运行时插件。xrc 工作区 `projects/runtime-ios/` 层的唯一活跃项目。

> 仓库：<https://github.com/XingChenRS/ArcDemo>
> 证据与能力状态：以 [能力账本](../../../research/notes/xrc-arcaea-capability-ledger-2026-08-31.md) 为准；本文档只描述本仓库的定位、结构与纪律。

## 1. 定位（xrc 宏观约定）

| 层 | 职责 | ArcDemo 的关系 |
|---|---|---|
| `projects/runtime-ios/ArcDemo`（本项目） | iOS 运行时插件：变速、seek、改判、重放/循环 | 本体 |
| `projects/patcher`（预留） | 跨项目的二进制手术层（打桩、段生成、重签） | 暂不启用；Mach-O 手术先长在本地 `inject.py`，桩点稳定后评估抽取 |
| `projects/core`（预留） | 共享 ABI / profile schema / 平台无关逻辑 | `xrc_abi.h`、`XRCClock.m`、profile schema 按"可无痛抽取"的口径编写 |
| `projects/docs/arcmodwiki` | 语义知识（判定链、存档链、解锁语义） | 本项目所有偏移的逆向出处；地址不对只查笔记 |
| `archive/legacy-arcdemo` | 历史 root injector / dylib | 不支持入口；其经验教训见账本 §7 |

**本项目不重复承载**：资源编辑（workbench/APRE）、私服（server）、Android 运行时（runtime-android）、逆向知识沉淀（research/notes）——各归其层。

## 2. 能力状态（对齐账本状态标记）

| 能力 | 状态 | 平台/版本 | 说明 |
|---|---|---|---|
| 谱面时间变速（Gameplay.update vtable） | **XRC-R** | iOS 6.13.10 | 当前 main 运行中 |
| 视觉变速（fishhook gettimeofday） | **XRC-R** | iOS 6.13.10 | 当前 main 运行中 |
| 基础 seek（音频 player + 谱面钟平移） | **XRC-R** | iOS 6.13.10 | 导航语义，已判音符不重放 |
| 悬浮 UI / plist 配置 / 文件日志 | **XRC-R** | iOS 6.13.10 | `Documents/xrc-arcdemo.plist` |
| 判定窗口参数 UI | **XRC-R/仅配置** | iOS 6.13.10 | 保存 Max/Pure/Far/Lost 四项，尚未生效 |
| 静态判定窗口补丁（8×CMP imm） | **XRC-S/历史** | iOS 6.13.10 | v7.2 已撤出 main；地址保留于 `include/ArcOffsets.h` 作研究锚点 |
| 运行时动态判定窗口 | **PROTO** | iOS 6.13.10 | v7.2 runtime patch / v7.3 graft 均失败，机制教训见 DEVLOG |
| **动态改判（桩点+slot）** | **OPEN→实施中** | iOS 7.0.255 | 收敛架构 v1.1，见 specs |
| **seek-replay / A-B 循环（转场机制）** | **OPEN→实施中** | iOS 7.0.255 | 收敛架构 v2.x，纯 dylib，零桩点 |

## 3. 架构分层

```
┌─ dylib（跨版本不变）──────────────────────────┐
│  Tweak.x       bootstrap + 悬浮 UI/菜单       │
│  XRCClock.m    时间基准/warp/freeze            │
│  XRCPlayer.m   音频 registry/进度/曲长         │
│  XRCGameplay.m gp hook + retime + seek + 转场  │
│  XRCJudge.m    slot 注册 + 改判 handler        │
│  XRCConfig.m   plist 配置                     │
├─ 版本契约（跨版本唯一改动点）──────────────────┤
│  XRCProfile.h  偏移/vtable 槽/字段布局          │
│  profiles/<ver>.json  注入器与 dylib 共享的行   │
│  xrc_abi.h     slot 布局 + handler 签名        │
├─ 注入器（inject.py）───────────────────────────┤
│  dylib 打包 + LC 注入（现有）                  │
│  桩点：段生成 + 入口覆写 + slot + 重签（v1.1）  │
└──────────────────────────────────────────────┘
```

**原则**：跨版本只改 `XRCProfile.h` / `profiles/` 行；逻辑文件全部版本无关。桩点只服务"纯 dylib 够不着的能力"——目前只有改判。

## 4. 证据纪律

- 所有偏移必须能回溯到研究笔记（`research/notes/ios-7.0.255-judgement-chain.md`、`ios-7.0.255-replay-chain.md`、`ios-6.13.10-stage1-patch-plan.md`）。**新增偏移 = 更新笔记 + profile 行同步提交**，禁止只写代码。
- 真机验证记录：每次设备测试写 DEVLOG（日期、包哈希、现象、结论）；能力状态标记随之更新（XRC-R/XRC-V/XRC-S）。
- 版本矩阵：6.13 与 7.0 各一行 profile；6.13 侧维持现状，机制验证在 7.0.255 进行。
- 注入产物（打桩后的主二进制）与注入前基线哈希对照，记录在 workspace MANIFEST 流程内。

## 5. 配置

`Documents/xrc-arcdemo.plist`。键列表见 `XRCConfig.m`（重构后）；历史键 `judgeMaxMs/judgePureMs/judgeFarMs/judgeLostMs` 语义不变（判定窗口设计参数，v1.1 起生效）。

## 6. 构建与注入

```sh
make            # 产出 libArcDemo.dylib
```

侧载：`libArcDemo.dylib` + `libellekit.dylib` 放入 `Arc-mobile.app/Frameworks`，由 `inject.py` 完成拷贝与 `LC_LOAD_DYLIB`/`LC_RPATH` 注入。

`inject.py` 参数化要求（工作区 README 已声明"必须参数化后才能视为受支持入口"）：输入显式 `--app` 目录与 dylib 路径，不再假设根级 `ios/Payload`；桩点功能（v1.1）按 `profiles/<version>.json` 行执行。参数化完成前，本仓库内历史路径引用保持现状并标注。

## 7. 里程碑

| 里程碑 | 内容 | 验证 |
|---|---|---|
| v1.0 | 源码模块化拆分（6.13 语义等价）+ profile 集中 | 6.13 真机行为不变 |
| v1.1 | 7.0 profile + 注入器打桩 + 改判 handler | 7.0 真机动态改判生效 |
| v2.0 | 转场 seek-replay | 7.0 真机 seek 后音符重飞、计分复位 |
| v2.1 | A-B 循环（转场机制，白闪帧为预期形态） | 7.0 真机 |
| v3（可选） | 触摸注入/自动演奏（旧桩点 #3 路线） | 待定 |

架构依据：[收敛版架构 spec](../../../docs/superpowers/specs/2026-09-06-arcdemo-7.0-converged-architecture.md)

## License

MIT. See `LICENSE`.
