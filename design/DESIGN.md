# PodLens DESIGN.md — 视觉与交互契约（单一真源）

原型（`design/prototype/`）与三端实现（`macos-host/` / `windows/` / `linux/`）都遵循本文件；改视觉先改这里，再同步实现。
Tokens 逐值提取自现行实现：真源 `docs/DESIGN-ROADMAP.md` §5，镜像于 `windows/Themes/Tokens.xaml`、`macos-host/Sources/RivetHost/DesignSystem.swift`（Palette/Typeface/Space/Radius/Motion）、`linux/src/main.cpp`（`@define-color`），原型 → 实现零翻译成本。

## Brief（2026-11-11）

- **目标**：非从零重设计。UI 已成型（0.6 macOS 基准 + 0.7.0 三端对齐），tokens 从实现逐值提取。让两个差异化主角在界面上站出来：**逐句稿阅读态**（音频与文字并列回溯）与**重复收听/进度记忆**（继续收听是首页第一视觉层级，播放位置与阅读上下文永不丢失）。
- **原型范围**（6 屏 × 亮/暗）：① 主页（英雄屏，继续收听进行态）② 逐句稿阅读态（核心差异化屏，当前句高亮 + 双语对照 + 章节跳转）③ 订阅单集列表（状态 chips + 行内作业进度 + 成本预估）④ 总结 tab（结构化卡片 + 锚点回放）⑤ 发现页（新用户空态引导 + 一键试听）⑥ 设置（BYOK：api-base / 掩码密钥 / 存储状态 / 测试连接）。
- **Exit 条件**：6 屏关键状态齐（空态/播放进行态/作业进行态）+ 交互逻辑定稿 + HIG 清单全过 + 用户评审通过。
- **不在范围**：新功能（收藏夹、Up Next 队列、波形、分章总结——产品尚无，需先立 issue）、契约变更（不动 `racket/backend.rkt` 的 35 RPC）、移动端 M4、新配色体系、商业/定价 UI。

## 设计原则（HIG 内核 + 本产品特有）

- **逐句稿是主角**：详情区第一视觉层级永远是逐句对照——当前句高亮、点击/回车跳播、双语/译文/原文切换零跳变。详情页以文本为中心，不做封面橱窗。
- **重复收听验证优先**：「继续收听」卡带细进度条与剩余时间占首页首位；已听完的单集「从头重听」一步可达；总结里的引语可从原句锚点重放（00:37 ▶）。播放进度是用户财产，切视图/专注模式/重启都不丢。
- **动作跟着对象走**：下载/转写/翻译/总结是单集动作，放在单集行内与详情页；全局只留「添加订阅」「设置」。
- **诚实**：未配 key、未转写、进行中、已取消各有明确文案与下一步；翻译成本先预估后计费（将翻译约 N 字符）；逐句稿没生成就不显示「已就绪」。
- **键盘一等公民**：Space 播放/暂停、⌘←/→（Ctrl）seek、Return 跳到选中句、专注模式往返；文本框聚焦不抢键。
- **每端都是第一方原生**：原型锁定信息架构、tokens 与交互逻辑；控件形态（sheet/ContentDialog/GTK 对话框）尊重平台习惯，不做像素复制。

## Tokens（语义；值不在此复制，亮/暗成对）

值类 token 真源 = `docs/DESIGN-ROADMAP.md` §5，镜像于三端实现（`windows/Themes/Tokens.xaml` · `macos-host/Sources/RivetHost/DesignSystem.swift` 的 Palette/Typeface/Space/Radius/Motion · `linux/src/main.cpp` 的 `@define-color`）；原型 `design/prototype/shared.css` 与其一一对应，本表只记语义与层级。

| Token | 语义 |
|---|---|
| `--accent --accent-soft` | 陶土橙：当前句/选中/进行态/主按钮 + 弱底（当前句高亮底、跟随激活、徽标） |
| `--canvas --surface --raised --hairline` | 暖纸画布 / 卡片侧栏 PlayerBar / 悬停按下嵌套底 / 唯一分隔线（三层明度层级） |
| `--ink --ink-soft` | 主/次级文字 |
| `--positive --warning --danger` | 已就绪成功 / 等待注意 / 失败破坏性（双态均须达对比度） |

- **on-accent** 为 accent 底上的文字（`#FFFFFF`）；macOS 另有 hover 深变体 `accent-deep`（值见 DesignSystem.swift）。
- **字号阶**：11 micro / 12 caption / 13 callout / 14 body / 15 headline / 17 reading / 19 title / 24 display / 30 hero。**阅读排版**：原文 17 系统衬线（New York）、译文 14 sans、时间戳 10 mono，行高 1.45–1.55，栏宽 ≤780。
- **字体栈**：`system-ui, -apple-system, "Segoe UI", "PingFang SC", "Microsoft YaHei"`；衬线 `ui-serif, "New York", Georgia`；等宽 `ui-monospace, "SF Mono", Menlo`。
- **间距** 4/8/12/16/24/32/48。**圆角** 8 控件 / 10 封面 / 14 卡片 / 18 弹层。**动效** 0.14s ease-out（按压/悬停）、spring 0.34（模式切换），不做持续动画。
- **布局**：侧栏 212–236（原型 224）· 内容列 430–500 · 阅读区 ≤780 · 主页内容 ≤920；专注模式把侧栏与列表动画收起到 0 宽，详情不重建。
- **设置形态**：原型按 Windows/Linux 的页内分区绘制；macOS 实现为独立设置窗口，属平台机制差异，分组内容两端同构。
- **语言**：界面文案 zh 默认 / en 回退（`Lang.swift` / `I18n.h` / `i18n.rkt` 三份独立表）；文案取自现行 i18n 键，不自造术语。

## 组件词汇

`Sidebar`（主页/发现 + 资料库三页 + 我的订阅带未听角标）· `ContinueCard`（继续收听英雄卡：封面/眉标/细进度/剩余时间/播放·重听）· `EpisodeRow`（未听点 + 标题 + 摘要 + 状态 chips + 行内动作）· `SentenceRow`（时间戳 mono + 原文衬线 + 译文 sans；当前句 accent-soft + 左侧 2.5px 品牌短线）· `SummaryCard`（一句话总结/要点/值得记的话/话题标签）· `PlayerBar`（常驻：now playing 三段式 + 细进度条 + 倍速/睡眠）· `DiscoverCard`（试听/添加）· `EmptyState`（说明下一步，不用「暂无数据」）· 设置分组行。

## 不变式

1. `accent` 只用于：当前句、选中态、进行态、主按钮；禁止大面积色块（封面氛围背景除外，且明度压暗不与文字争）。
2. 层级靠 `canvas < surface < raised` 三层明度 + `hairline` 分隔表达；卡片至多一层 4.5% 微阴影，不用重描边与阴影堆叠。
3. 亮暗主题成对设计，不存在只有暗态的界面；语义色（positive/warning/danger）双态都必须达标对比度。
4. 播放进度与阅读上下文是用户财产：切换视图、专注模式、重启都不丢；任何时候一键「当前句」回到正在播放的句子并恢复跟随。
5. 状态诚实：未配 key、未转写、进行中、已取消各有明确文案与下一步；成本先预估后执行；阶段没完成不得显示「已就绪」。
6. PlayerBar 常驻全局（含倍速 1.0–3.0×、±15/30s、睡眠定时、章节跳转）；键盘提示统一 `kbd` 样式：`raised` 底、`ink-soft` 字、4px 圆角。


## 平台映射与差异声明（预钉 · 宿主实现时升级为落点表）

统一层（三平台必须一致，`design/prototype/` 原型已锁定）：信息架构、核心流程、快捷键语义、
语义色与层级词汇。因地制宜层（按平台惯例落地，不预画像素）：

| 维度 | macOS | Windows | Linux |
|---|---|---|---|
| 修饰键 | ⌘ | Ctrl | Ctrl |
| 命令入口 | 原生菜单栏 | 菜单栏/命令行内 | 菜单栏 |
| 字体 | 系统栈 + PingFang SC | 系统栈 + Microsoft YaHei | 系统栈 + Noto Sans CJK |
| 原生控件 | SwiftUI 控件 | WinUI 3 控件 | GTK4 控件 |

差异声明纪律：宿主特例必须先写进本节才能实现；未声明的宿主差异按违约处理
（案例：taskly 漂移台账 D8）。
