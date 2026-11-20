# AGENTS.md

## 家族设计（必读入口）

- 设计/UI 任务先加载 `tlai-product`，必读 `references/policy.md` 与 `references/design-standard.md`（理念、决策规则、UI 验收）。技能缺失时读取 ZCode 真源：macOS/Linux `~/Sync/ZCode/skills/tlai-product/`；Windows `D:/ZCode/skills/tlai-product/`。无法读取须报告规范未核验，不凭记忆跳过。
- 家族规范管共性；本仓现有设计、行为与 token 真源管具体值和产品差异。例外记回原契约，不复制家族规则或新增数值表；已有界面按下一次相关切片渐进对齐。
- 改界面先改原型、落账后实现；按家族 UI 清单与本仓当前技术线的既有门禁验收，原型对照和真实交互证据都要保留；对外宣传使用验收后的实物截图。

## 实现路由（agent 按任务读真源）

- 实现界面以 `design/prototype/` 为准：对照 HTML/CSS/JS 与实物截图验收，不依赖散文复述。
- Token/几何值真源 = `design/prototype/shared.css`（亮暗成对；无 shared.css 的仓 = design/prototype/ 各页样式）；`design/DESIGN.md` 只记语义名、用途与决策。
- 行为边界与跨平台一致性以 `design/DESIGN.md` 的不变式与平台差异节为准。
- 改界面先改原型再改实现（tlai-product）；动共享层（design/、shared/）先 issue 声明，同 commit 落契约。

## Current owner decision — 2026-11-18 quality-first

This product is in **non-commercial development**. The prior 2026-10/11 product pricing, trial, paid-feature, Free/Pro and family Permit/Commerce rollout decisions are canceled. Do not introduce checkout, subscriptions, activation, commercial entitlement, paid update windows or a paywall. Do not change source-license terms or release signing and identity verification. Prioritize product correctness, reliable native experience, recovery, bilingual README and truthful website claims. The [current family portfolio](https://github.com/turlamai/turlamai.github.io/blob/master/PORTFOLIO.md) governs every slice.

指引给 AI agent（及开发者）：如何理解、构建、改动 PodLens。

## 这是什么

PodLens 是**原生窗口的播客应用**（Glaze 架构，#63 起）：解决「听不懂英文播客」——转写、逐句翻译、总结。一份 Racket 应用核心（`racket/`）经 `backend/main.rkt` 的类型化路由适配进 [Glaze](https://github.com/turlamai/glaze) 载体：三平台各自的第一方 WebView（WebView2 / WKWebView / WebKitGTK）承载**同一份共享 web UI**（`apps/desktop/` + `packages/core/`），窗口、托盘、菜单、媒体键等宿主能力由 glaze 提供。引擎与 CLI 仍共用同一份 Racket 核心：无参数启动 GUI；CLI 走源码方式 `racket racket/cli.rkt <command>`。

| 平台 | 载体 | 验证状态 |
|---|---|---|
| macOS 14+ | glaze（WKWebView） | ✅ 真窗 verify + seeded 旅程 CI 三平台 |
| Windows 10+ | glaze（WebView2） | ✅ 真窗 verify + seeded 旅程 CI 三平台 |
| Linux x64/arm64 | glaze（WebKitGTK） | ✅ 真窗 verify（Xvfb + null sink）CI 三平台 |

0.8.x 及以前的三套原生宿主（SwiftUI / WinUI 3 / GTK4，`macos-host/` `windows/` `linux/` `flatpak/`）已随 #63 切片 4 退役删除；历史证据见 `docs/VERIFICATION-0.7.0.md` / `docs/VERIFICATION-0.7.5.md`，不再代表当前载体。

底层框架迭代很快：**每次动工前先把本地 checkout 更新到 origin/main 再开发**；CI 以 `.github/workflows/ci.yml` 的 `RIVET_PIN` / `GLAZE_RIVET_PIN` / `GLAZE_PIN` 为唯一 pin 真源。遇到 rivet/glaze 的问题直接向上游提 issue 或 PR，不在 PodLens 里绕过或本地 hack。

## 快速命令

```bash
# 每次开发前：检查工作树，再以 fast-forward-only 更新当前仓库和上游
git status --short --branch
git pull --ff-only
git -C /path/to/glaze pull --ff-only
# link（首次或 link 断了）：link glaze 与 glaze-cli 两个子包（rivet 同理）
raco pkg install --auto --no-docs --link /path/to/glaze/glaze /path/to/glaze/glaze-cli

# 后端测试（假 OpenAI 服务器，无需真实 key）
raco test tests/

# web 侧类型检查 + 构建 + 生成物门禁
pnpm check && pnpm build
pnpm gen:rpc && pnpm gen:i18n && python scripts/check-rpc-surface.py

# 真窗完成定义（独立进程 seeding fixture + 六旅程 + 截图证据）
racket verify.rkt

# 框架验收信封 + 跨平台矩阵（CI acceptance.yml 同款）
raco glaze acceptance --json --out report.json
raco glaze matrix report.json --json

# 开发启动 / 打包（身份与版本走 release.yml 的 build flags）
raco glaze dev
raco glaze build --installer

# CLI 冒烟（隔离数据目录）
PODLENS_DATA_DIR=$(mktemp -d) racket racket/cli.rkt doctor

# 更新签名密钥（仅首次；私钥永不入库）
scripts/update-keys.sh
```

工作树非干净、分支已分叉或远端不可达时，保留现场并报告，不得 stash、reset
或清理来掩盖状态。`verify.rkt` 是可执行完成定义（glaze docs/product-acceptance.md
指定 verify 为验收 owner）；不得删除 journey、放宽断言、以 CLI 代替真窗操作或
复用旧证据来让结果变绿。required suite 未执行、超时、失败或没有生成本次运行的
新证据时，功能不能称为完成。

## 契约（改任何行为前必读）

| 位置 | 内容 |
|---|---|
| `racket/backend.rkt` | RVT1 引擎契约：35 个 RPC、5 个事件（notify/job-progress/episodes-changed/open-url/update-available）、State `version`。行布局是位置参数字符串，注释在文件头。`settings-list` 对 `api-key` 只返回掩码 |
| `backend/main.rkt` | glaze 适配层：引擎 RVT1 → 类型化路由 + 宿主路由（`GET api/audio/:id` Range 流式透传、鉴权 `?glaze-token=` → 302 HttpOnly cookie）、tray、close-to-tray |
| `rivet-schema.json` | 引擎 RVT1 schema 基线，由 `raco rivet schema --output rivet-schema.json` 生成入库，不手写；兼容门禁 `raco rivet schema check rivet-schema.json --json` 必须零 breaking |
| `glaze-schema.json` | 载体 API 基线，由 `raco glaze schema write` 生成入库；改 `backend/main.rkt` 公开路由后同 commit 重生成 |
| `docs/UPDATE.md` | 更新契约：清单 JSON schema、Ed25519 签名对象、资产命名、客户端行为 |
| `VERSION` + `racket/version.rkt` | 发布版本真源（`scripts/check-release-version.sh` 门禁）；installer 身份由 release.yml 的 `--version`/`--identifier` flags 传入，identifier 终身稳定 |
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

web UI 取本地音频不加引擎 RPC：宿主路由 `GET api/audio/:id` 按 `<episodeId>` 前缀扫 `audio/` 目录并做 Range 流式透传。

## 改动规则

- **改共享行为**（CLI 语义、管线、文案）：先改 `racket/core/` + `tests/`，跑 `raco test tests/`；引擎契约变更 =  schema 基线同 commit 重生成
- **改 UI**：`apps/desktop/src/`（state/player/views/main/e2e）+ `packages/core/`；`packages/core/src/rpc.ts` 与 `i18n.ts` 是生成物，不要手改（`pnpm gen:rpc` / `pnpm gen:i18n`）
- **版本发布**：`VERSION` + `racket/version.rkt` + CHANGELOG 小节 + 打 `v*` tag；release.yml 以 `raco glaze build --installer` 完成三平台 packaging（MSI/dmg/deb/rpm/AppImage，工具链缺失时回退 zip/tar.gz）、签名清单与 GitHub Release
- **应用图标**：`scripts/make-icons.py` 从代码绘制源图并生成 `assets/branding/app.ico` + `app.icns`（release.yml 以 `--icon` 传入）；改样式只改脚本里的 `draw_master()` 后重跑，不要手改生成物
- **i18n**：单源 `racket/core/i18n.rkt`（zh 默认、en 回退），`scripts/gen-web-i18n.py` 投影为 `packages/core/src/i18n.ts`；改文案只改 Racket 表后重跑投影，门禁 `scripts/check-rpc-surface.py` 同轮校验
- **更新密钥轮换**：先发一个信任新公钥的版本，再用新私钥签名，见 docs/UPDATE.md

## 诚实缺口（不要在文档里夸口）

- 当前载体是共享 web UI + 三平台原生 WebView 窗口，**不是**三套原生控件；
  平台差异集中在窗口chrome、托盘、媒体键与文件对话框，由 glaze 承载。
- 系统级 Now Playing：web 侧 MediaSession 桥保留（页内 metadata/playbackState/
  positionState + action handler，Windows SMTC 仍走它）；OS 表面自 glaze#153
  起由**宿主自有**能力发布（macOS 公共 MediaPlayer.framework、Linux 宿主自有
  MPRIS2；Windows 宿主 stub 惰性）。页面经 `api/host/now-playing` 同步状态，
  OS 传输命令经 SSE `now-playing-command` 回到页面播放路径；验收探针读宿主
  表面（Linux 匹配 `org.mpris.MediaPlayer2.site_jrtx_podlens`、macOS 经
  `api/host/now-playing_os` 回读、Windows SMTC 探针不变），不宣称 web 桥
  直接等于 OS 集成。
- 验收进程的合成点击播放依赖 glaze 的 env-gated hatch
  （`GLAZE_ALLOW_PROGRAMMATIC_PLAYBACK=1`，turlamai/glaze#143/#144）；
  **发布应用禁设该变量**，真实用户手势门槛不变。
- 真窗截图上下翻转是 glaze 已知 capture artifact（turlamai/glaze#140），
  不代表 UI 布局问题；目视验收以布局与文案为准。
- Windows 125–200% 显示缩放截图矩阵仍未执行。
- 0.7.5 起取消在 UI 侧立即生效：先清进度/落 cancelled，再 best-effort 调
  `job-cancel`。若 provider socket 永不返回，worker 仍可能阻塞到系统超时，
  磁盘上的阶段可能仍是 running；彻底修复需把网络 I/O 移出 runtime 线程。
  证据见 `docs/VERIFICATION-0.7.5.md`（原生载体时点）。
- BYOK key 在 macOS 走 Keychain（`security -i`，密钥不进 argv）、Windows
  走 DPAPI、Linux 走 secret-tool；都不可用时才降到 0600 文件，并在
  设置页明确标注。CLI 与日志只显示掩码。
- 「最近更新/已下载」页基于 `episode-recent`（跨源、上限 200 条按更新
  时间排序）；极端老库中超出上限的已下载单集不会出现在该页。
- macOS 构建 ad-hoc 签名（公证证书未配置），首次启动需右键打开。
- 翻译按句计费，成本由用户的 API key 承担。
- M4 移动伴随端（iOS/iPadOS/Android/watchOS）未开工（见 docs/DESIGN-ROADMAP.md §6-M4）。

## 组合定位（Portfolio placement）

2026-11-18 起，以产品交付质量为目标，不推进收费版、试用、商业授权或结账。既有 LICENSE 和发行签名验证保持不变。当前权威是[产品组合策略](https://github.com/turlamai/turlamai.github.io/blob/master/PORTFOLIO.zh-CN.md)。

## 产品交付与下一步（2026-11-18）

请以当前代码与验收证据推进用户主流程、恢复、跨平台原生体验、签名更新、文档和产品主页，不按任何历史商业规划开发。

## Documentation languages

Public default documentation is English; maintain complete Chinese user paths in `*.zh-CN.md`, with reciprocal links. Update both languages when prices, quotas, installation, recovery, privacy or supported platforms change. API/protocol identifiers and commands remain unchanged; do not maintain a second normative protocol or implementation. Follow the [family language policy](https://github.com/turlamai/turlamai.github.io/blob/master/docs/DOCUMENTATION-LANGUAGES.md). Existing internal notes are not a claim that every document is bilingual.

## Public product documentation

The paired `docs/USER-GUIDE.md` / `docs/USER-GUIDE.zh-CN.md` own the public installation, first-use, data/recovery, privacy and availability path. Keep the homepage and both README entry points aligned with them when behavior changes. Detailed technical contracts and the current implementation queue retain their existing owners. Do not publish target prices, a purchase link or a ready/secure/platform claim before its release evidence exists.
