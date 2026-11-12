# AGENTS.md

## Authorization decision before implementation

Decision `2026-10-auth-1`: No commercial Permit credentials, Commerce checkout or licensing account. Read the complete [local authorization decision](PRICING.md#authorization-decision-for-implementation) and its Chinese counterpart before commercial, trial, update-eligibility or credential work. Record this decision revision and the source/policy SHAs actually read in the PR/handoff. Refresh at each bounded slice; existing agent conversations do not receive this change automatically. Follow the existing product contract and implementation issue; do not activate a payment gate merely because a plan exists.

指引给 AI agent（及开发者）：如何理解、构建、改动 PodLens。

## 这是什么

PodLens 是**原生**播客应用（Rivet 架构）：解决「听不懂英文播客」——转写、逐句翻译、总结。一份 Racket 应用核心以进程内方式嵌进各平台第一方 UI，**不共享任何 UI 代码**，靠 `racket/backend.rkt` 的类型化契约保持一致：

| 平台 | 技术栈 | 目录 | 验证状态 |
|---|---|---|---|
| macOS 14+ | SwiftUI + Rivet（嵌入式 Racket CS） | `macos-host/` | ✅ 构建+打包+启动已验证 |
| Windows 10+ | WinUI 3 (C++/WinRT) + Rivet | `windows/` | 源码完成，CI 构建验证 |
| Linux x64/arm64 | GTK4 + GStreamer + Rivet | `linux/` | 源码完成，CI 构建+headless 冒烟验证 |

GUI 与 CLI 共用同一份 Racket 核心：无参数启动 GUI；CLI 走源码方式
`racket racket/cli.rkt <command>`（单文件自带运行时的 CLI 在路线图上）。

底层框架是 [Rivet](https://github.com/turlamai/rivet)（同组织仓库）：RVT1 协议（typed RPC / Events / State）、嵌入式 Racket CS、构建编排。Rivet 迭代很快：**每次动工前先把本地 checkout 更新到 origin/main 再开发**；遇到 Rivet 的问题直接向上游提 issue 或 PR，不在 PodLens 里绕过或本地 hack。

## 快速命令

```bash
# 每次开发前：检查工作树，再以 fast-forward-only 更新当前仓库和 Rivet
git status --short --branch
git pull --ff-only
git -C /path/to/rivet pull --ff-only
# link（首次或 link 断了）：link rivet 与 rivet-cli 两个子包
raco pkg install --auto --no-docs --link /path/to/rivet/rivet /path/to/rivet/rivet-cli

# 后端测试（假 OpenAI 服务器，无需真实 key）
raco test tests/

# 三平台完整完成定义（在各原生 runner 上执行）
raco rivet acceptance --json

# 构建并启动当前平台宿主（自动重新生成类型化客户端）
raco rivet dev

# 打包 + 自检
raco rivet package

# CLI 冒烟（隔离数据目录）
PODLENS_DATA_DIR=$(mktemp -d) racket racket/cli.rkt doctor

# 更新签名密钥（仅首次；私钥永不入库）
scripts/update-keys.sh
```

工作树非干净、分支已分叉或远端不可达时，保留现场并报告，不得 stash、reset
或清理来掩盖状态。`rivet-acceptance.rktd` 是可执行完成定义；不得删除 requirement、
放宽断言、以 CLI 代替 GUI 操作或复用旧证据来让结果变绿。required suite 未执行、
超时、失败或没有生成本次运行的新证据时，功能不能称为完成。

## 契约（改任何行为前必读）

| 位置 | 内容 |
|---|---|
| `racket/backend.rkt` | RVT1 契约：35 个 RPC、5 个事件（notify/job-progress/episodes-changed/open-url/update-available）、State `version`。行布局是位置参数字符串，注释在文件头。0.6 新增 `job-cancel`、`security-status`、`ai-test`；`settings-list` 对 `api-key` 只返回掩码 |
| `rivet-schema.json` | RVT1 schema 基线（当前 35 RPC / 5 事件），由 `raco rivet schema --output rivet-schema.json` 生成入库，不手写。改 `racket/backend.rkt` 公开契约后同 commit 重生成；兼容门禁 `raco rivet schema check rivet-schema.json --json` 必须零 breaking（新增兼容，删改签名/参数顺序/结果为 breaking） |
| `docs/UPDATE.md` | 更新契约：清单 JSON schema、Ed25519 签名对象、资产命名、客户端行为 |
| `rivet.rktd` | 发布身份唯一真源：version/build/identifier/最低系统版本。**tag 必须等于其中 version** |
| CHANGELOG.md | 每个 tag 必须有同名小节，release 前置检查会拒绝 |

## 数据布局

```
~/.podlens/            （测试/多实例用 PODLENS_DATA_DIR 覆盖）
├── config.json        当前设置；API key 只留 api-key-ref/api-key-store
├── library.json       订阅 + 单集 + 播放进度（原子写）
├── audio/<id>.<ext>   音频缓存（<id> 是 40 位 hex）
├── secrets/           系统安全存储不可用时的 0600 回退文件
└── transcripts/<id>.json  逐句稿 + 翻译 + 总结
```

宿主找本地音频不用加 RPC：按 `<episodeId>` 前缀扫 `audio/` 目录。

## 改动规则

- **改共享行为**（CLI 语义、管线、文案）：先改 `racket/core/` + `tests/`，跑 `raco test tests/`；backend 契约变更 = 三端同步发布
- **改 UI**：macOS 在 `macos-host/Sources/RivetHost/`，Windows 在 `windows/`；`GeneratedBackend.swift/.hpp` 是生成物，不要手改
- **版本发布**：`rivet.rktd` version + CHANGELOG 小节 + 打 `v*` tag，CI 完成 packaging、Windows MSI（`raco rivet release`，WiX，含开始菜单/桌面快捷方式与 per-product UpgradeCode）、便携 zip、签名清单与 GitHub Release
- **应用图标**：`scripts/make-icons.py` 从代码绘制源图并生成 `assets/branding/app.ico` + `app.icns`（已配进 `rivet.rktd`）；改样式只改脚本里的 `draw_master()` 后重跑，不要手改生成物
- **i18n**：三份独立表（Racket `racket/core/i18n.rkt`、macOS `Lang.swift`、Windows `I18n.h`），zh 为默认、en 为回退；键不要求跨端一致（各端只说自己要说的话）
- **更新密钥轮换**：先发一个信任新公钥的版本，再用新私钥签名，见 docs/UPDATE.md

## 诚实缺口（不要在文档里夸口）

- 0.7.0 起 Windows/Linux 已对齐 0.6 的信息架构、三种阅读模式、取消
  按钮、设置存储提示和品牌 tokens；控件仍是 WinUI / GTK 原生，不做
  像素复制。运行时语言切换仍只在 macOS；Windows 用编译期 `kUiLang`，
  Linux 用 `PODLENS_LANG`。
- Windows 125–200% 显示缩放截图矩阵仍未执行；1024×768 打包验收已覆盖。
- 0.7.5 起取消在 UI 侧立即生效：三端宿主先清进度/落 cancelled，再
  best-effort 调 `job-cancel`。若 provider socket 永不返回，worker 仍可能
  阻塞到系统超时，磁盘上的阶段可能仍是 running；彻底修复需把网络 I/O
  移出嵌入式 runtime 线程。证据见 `docs/VERIFICATION-0.7.5.md`。
- BYOK key 在 macOS 走 Keychain（`security -i`，密钥不进 argv）、Windows
  走 DPAPI、Linux 走 secret-tool；都不可用时才降到 0600 文件，并在
  设置页明确标注。CLI 与日志只显示掩码。
- 0.4.0 起三端功能面对齐：发现页全目录搜索、逐句稿跟随高亮与
  双语/译文/原文切换、连续播放、睡眠定时、发现页一键试听、系统媒体
  集成（macOS 控制中心 / Windows SMTC / Linux MPRIS）、zh 界面，每端都有。
- Linux 界面语言无运行时开关：`tr()` 读 `PODLENS_LANG`（zh 默认、en
  回退），与 mac/win 的表一样没有 in-app 切换。
- Linux 封面走系统 curl 且无磁盘缓存（同图重复下载，失败静默占位）。
- 「最近更新/已下载」页基于 `episode-recent`（跨源、上限 200 条按更新
  时间排序）；极端老库中超出上限的已下载单集不会出现在该页。
- Windows 便携 zip 支持应用内下载并安装更新；MSI 安装的「检查更新」
  只报告结果，升级走 MSI 覆盖安装。
- macOS 构建 ad-hoc 签名（公证证书未配置），首次启动需右键打开。
- 翻译按句计费，成本由用户的 API key 承担。
- M4 移动伴随端（iOS/iPadOS/Android/watchOS）未开工：等 Rivet 的
  网络设备通道就绪（见 docs/DESIGN-ROADMAP.md §6-M4）。

## 组合定位（Portfolio placement）

- 当前决策（2026-10-v2）：免费 BYOK；听读用户入口。具体价格、免费/付费边界和开卖门禁以本仓 [PRICING.md](PRICING.md) 为唯一权威；旧版收费候选与早鸟方案已被替代。
- 组合归属：[PORTFOLIO](https://github.com/turlamai/turlamai.github.io/blob/master/PORTFOLIO.md)。当前全部产品开发中、没有实际用户；目标定价不表示已经开卖，不因此立即给开发版加收费墙。
- 免费产品不接商业激活；付费层先实现可验证价值，再接 Commerce/Permit。优先完成本仓既有产品审查 issue；不修改现行源码 LICENSE。

## 产品交付与下一步（2026-10-23）

- 家族[交付标准](https://github.com/turlamai/turlamai.github.io/blob/master/docs/PRODUCT-STANDARD.md)与[组合策略](https://github.com/turlamai/turlamai.github.io/blob/master/PORTFOLIO.md)是共用政策；本仓具体行为以 `docs/DESIGN-ROADMAP.md` 为准，不复制五库依赖图。
- 当前执行入口：0.7.0 已完成 Windows/Linux 的阅读模式、取消、设置存储提示与品牌 tokens 对齐；后续切片见 `docs/DESIGN-ROADMAP.md` 的 M6 与诚实缺口。
- 开工先检查干净工作树与远端，以 fast-forward-only 更新并记录 SHA；共享文件一次一个写入者，保留其他 checkout 的未提交工作。
- 每次只完成一个可验收切片，记录 owned files、依赖 pin、命令/平台/产物证据和回滚。已实现、已发布、实机验收分别陈述；不修改 requirements 或复用旧证据来制造通过。

## Documentation languages

Public default documentation is English; maintain complete Chinese user paths in `*.zh-CN.md`, with reciprocal links. Update both languages when prices, quotas, installation, recovery, privacy or supported platforms change. API/protocol identifiers and commands remain unchanged; do not maintain a second normative protocol or implementation. Follow the [family language policy](https://github.com/turlamai/turlamai.github.io/blob/master/docs/DOCUMENTATION-LANGUAGES.md). Existing internal notes are not a claim that every document is bilingual.

## Public product documentation

The paired `docs/USER-GUIDE.md` / `docs/USER-GUIDE.zh-CN.md` own the public installation, first-use, data/recovery, privacy and availability path. Keep the homepage and both README entry points aligned with them when behavior changes. Detailed technical contracts and the current implementation queue retain their existing owners. Do not publish target prices, a purchase link or a ready/secure/platform claim before its release evidence exists.

## 设计流程（原型先行）

所有 UI 开发与界面改造一律先原型后代码：brief → `design/DESIGN.md`
视觉契约 → HTML 原型 → 按 HIG 基准评审通过才开工；改界面先改原型再改
代码。契约与原型放本仓 `design/`（尚未建立时随首个 UI 切片建立），
实物截图验收后才能作为对外宣传素材。
