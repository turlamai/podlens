# PodLens

听得懂的英文播客。跨平台桌面播客应用：用你自己的大模型 API key，把英文单集转写、逐句翻译、自动总结——为"读得懂、听不懂"的听众而生。

[![CI](https://github.com/turlamai/podlens/actions/workflows/ci.yml/badge.svg)](https://github.com/turlamai/podlens/actions/workflows/ci.yml) [![Release](https://img.shields.io/github/v/release/turlamai/podlens)](https://github.com/turlamai/podlens/releases/latest) ![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey) [![License](https://img.shields.io/badge/license-AGPL--3.0-blue)](LICENSE)

[English](README.md) · **中文**

## 开始使用

免费 BYOK 应用。不提供 PodLens 托管 AI 订阅；模型用量由配置的服务商收费。提供 macOS、Windows、Linux 桌面发行版；移动与伴随端不交付（glaze 载体按家族政策只做桌面）。界面语言在设置中选择。

[安装、首次使用、隐私与备份恢复](docs/USER-GUIDE.zh-CN.md) · [English](docs/USER-GUIDE.md)

## 安装

从 [Releases](https://github.com/turlamai/podlens/releases/latest) 下载：

| 平台 | 下载 | 更新 |
|---|---|---|
| macOS 14+（Apple Silicon 与 Intel） | `podlens-<version>-macos-<arch>.dmg`——`arm64` / `x64`，或便携版 `podlens-<version>-macos-<arch>.zip` | 应用内检查 + 校验下载（签名清单），再用新版 DMG/zip 替换应用 |
| Windows 10+ x64 | `podlens-<version>-windows-x64.msi` 安装器（含开始菜单/桌面快捷方式），或 `podlens-<version>-windows-x64.zip` 便携版 | 应用内检查 + 校验下载；便携版：把新版 zip 解到安装目录上；MSI：重新运行新版安装器（应用内会提示） |
| Linux x64 / arm64 | `podlens-<version>-linux-<arch>.AppImage`、`.deb`（随包附带 GStreamer 插件闭包含 `gst-libav`，保证 m4a/mp3 可播）、`.rpm`、便携版 `tar.gz`（`bin/` + `lib/` + `public/`，运行 `bin/podlens`），或 `podlens-<version>-linux-<arch>.flatpak` Flatpak 包（app id 为 `site.jrtx.podlens`；用 `flatpak --user install` 安装——数据目录在沙盒内，安装即全新资料库） | tar.gz：应用内检查 + 校验下载，再把新版 tarball 解到应用目录上（有端到端升级资质流程验证）；deb/rpm：系统包管理器；AppImage/Flatpak：替换文件 / 安装新版 bundle |

每个发布都带 `SHA256SUMS` 校验清单和 Sigstore 构建来源证明（`gh attestation verify <file> -R turlamai/podlens`）。

更新走 Ed25519 签名清单（[docs/UPDATE.md](docs/UPDATE.md)）：应用先验签名、哈希与字节数，安装始终由用户按上表方式完成。macOS 在配置了发布证书时做 Developer ID 签名 + 公证；缺证书时 tag 发布直接失败关闭，不发 ad-hoc 产物。

## 为什么做 PodLens？

听力是多数非英语母语者最后一堵墙：播客没有翻译，没人帮你总结一小时的内容，停下来查词又毁掉节奏。PodLens 用一条逐集流水线解决：

- **转写**——调用任意 OpenAI 兼容的 `/audio/transcriptions` 端点（Whisper 等），输出带时间戳的逐句稿
- **翻译**——逐句对齐翻译成中文（或英文），与原文对照显示
- **总结**——每集自动生成一句话总结、5–8 条要点、值得记的话和话题标签

转写、翻译、总结都缓存在本地磁盘：一集只处理一次，结果永远是你的。

### 和主流播放器对比

| | PodLens | Apple 播客 | Overcast |
|---|---|---|---|
| 界面 | **一份共享 web UI，跑在系统 WebView 上** | AppKit | web 套壳 |
| 逐句稿 | **按需生成，归你所有** | 仅部分播客 | 仅部分播客 |
| 翻译 | **逐句对照，本地缓存** | — | — |
| 总结 | **TL;DR + 要点** | AI 回顾（仅美区） | — |
| 模型 | **BYOK，任意 OpenAI 兼容端点** | 仅苹果 | — |

## 工作原理

PodLens 基于 [glaze](https://github.com/turlamai/glaze) 构建：一个共享的 Racket 后端（订阅解析、媒体库、AI 流水线、更新客户端）服务一份共享 web UI，跑在各平台自己的系统 WebView 里——WKWebView、WebView2、WebKitGTK。不是 Electron：不捆绑浏览器，没有后台守护进程。

```text
                 Racket 应用核心
      订阅 · 媒体库 · ASR/翻译/总结 · 更新
                          │
              loopback HTTP 上的类型化 RPC
              （token 门禁，同源 UI）
                          │
                一份 web UI（HTML/CSS/TS）
                    ┌─────┼─────┐
                macOS   Windows  Linux
              WKWebView WebView2 WebKitGTK
```

- 后端把 Racket CS 嵌入应用进程内——没有后台守护进程，没有控制台窗口
- 播放是载体内的 HTML5 audio；宿主经支持 Range 的 loopback 路由流式供缓存音频；OS Now Playing（Control Center / SMTC / MPRIS）按平台桥接
- UI 只与 `racket/backend.rkt` 中的类型化契约对话——改契约就是一次三端同步发布

## 都有什么

- **一键听懂**：下载 → 转写 → 翻译 → 总结一次排队完成——已完成的阶段重跑时自动跳过，确认页先给出大致文本量，运行中可在下一个检查点取消
- 订阅 RSS 播客源（RSS 2.0 + iTunes 标签），刷新检测新单集，每 30 分钟自动刷新并通知新单集
- 播放：1.0–3.0× 倍速、±15/30 秒跳转、睡眠定时器、章节跳转（Podcasting 2.0 `podcast:chapters`）、连续播放接下一集、启动续播、系统媒体键 + Control Center（macOS）/ SMTC（Windows）/ MPRIS（Linux）
- **阅读优先的详情页**：衬线逐句稿按阅读排版，跟随高亮，句子可用键盘操作；双语 / 只看译文 / 只看原文三种模式
- **专注聆听**：收起资料库与单集列表而不中断播放，保留单集、进度和阅读位置；同一控件原位恢复资料库
- 结构化总结卡片（TL;DR、要点、引用、话题），附 feed 自带的节目介绍
- 媒体库基础：已播/未播标记、每档未播徽章、单集任务进度
- 「发现」面板：经典英文播客精选目录 + 全目录搜索（iTunes Search API，无需密钥，结果自带 Apple 权威 feed 地址）——绝不自动订阅
- 先试听再订阅：发现页每张卡片一键试听最新单集——只拉取 feed、缓存试听音频，不入库不订阅（`feed-peek` / `preview-audio`；CLI 对应 `peek`、`preview`）
- 自带 key（BYOK）：OpenAI、DeepSeek、Groq、SiliconFlow、Ollama，任意 OpenAI 兼容端点
- **密钥卫生**：key 存放在系统安全存储（macOS Keychain / Windows DPAPI / Linux Secret Service），不可用时回退为仅本人可读文件；不会写入 config.json 或 CLI 输出。设置页可在不消耗 token 的情况下检查连接
- agent 友好的 CLI，与 GUI 共用同一核心（`add`、`episodes`、`pipeline`、
  `estimate`、`transcribe`、`translate`、`summarize`、`show`、`export`、
  `find`、`done`、`search`、`peek`、`preview`、`--json`、退出码 0/1/2）
- 签名的应用内更新（Ed25519 清单 + SHA-256，见 [docs/UPDATE.md](docs/UPDATE.md)）
- [使用手册](https://podlens.jrtx.site/guide.html)：五分钟上手、BYOK 配置与常见问题

## 快速开始

### 1. 配置 API key

打开设置，填写：

- `api-base`——如 `https://api.openai.com/v1`（或 DeepSeek/Groq/Ollama 的地址）
- `api-key`——你的 key，存放在系统安全存储（不写入 `config.json`），从不同步；首次 AI 任务前先用「检查连接」

### 2. 开听

添加播客 RSS 地址，选一集，点 **一键听懂**。或者在终端：

```bash
git clone https://github.com/turlamai/podlens && cd podlens
raco pkg install --auto --no-docs 'https://github.com/turlamai/glaze.git#<ci.yml 中的 GLAZE_PIN>'
racket racket/cli.rkt add "https://feeds.example.com/show.xml"
racket racket/cli.rkt episodes <feed-id>
racket racket/cli.rkt transcribe <episode-id>
racket racket/cli.rkt show <episode-id> --json
```

CLI 就是 GUI 内嵌的那份 Racket 源码，无头运行。（自带运行时的单文件 CLI
在路线图上；仓库内运行时 `--help`、`list`、`doctor`、`config` 不需要 API key。）

## 仓库结构

```text
podlens/
├── glaze.rktd              # 载体 schema 契约（app id、窗口、托盘）
├── main.rkt                # glaze build 入口（包 backend/main.rkt）
├── VERSION                 # 发布身份，与 racket/version.rkt 对齐校验
├── backend/
│   └── main.rkt            # 宿主：类型化 RPC 路由、音频 Range 流、托盘、关窗收托盘
├── apps/desktop/           # 唯一 web UI（TypeScript + Vite）；i18n 由 racket/core/i18n.rkt 投影
├── racket/
│   ├── backend.rkt         # 类型化线路契约（RPC、事件、State）
│   ├── update.rkt          # 签名清单更新检查（glaze/update）
│   ├── cli.rkt             # agent 向 CLI（--json、退出码）
│   └── core/               # feeds、library、config、openai、pipeline、chapters、i18n
├── tests/                  # 后端测试（含假 OpenAI 服务器与更新流测试）
├── verify.rkt              # 真窗验收旅程（逐平台，可无头跑）
├── scripts/                # update-keys.sh、make-update-manifest.sh、acceptance/、e2e 种子
├── flatpak/                # Linux flatpak 产物的 bundle manifest + 启动器
├── design/                 # 已落账原型 + DESIGN.md 视觉/交互契约
├── docs/                   # UPDATE.md（更新契约）· USER-GUIDE · release-runbook
├── site/                   # podlens.jrtx.site（GitHub Pages）
└── .github/workflows/      # ci · acceptance · release · appimage-upgrade-qualification · pages
```

## 开发

前置：[Racket CS](https://racket-lang.org/)（stable，full 分布）并安装 pinned 的 glaze 包；Node.js 用于 web UI 构建。Linux 另需 GTK3 + WebKitGTK 4.1 + GStreamer 运行包（精确清单见 `.github/workflows/acceptance.yml`）。

```bash
raco pkg install --auto --no-docs 'https://github.com/turlamai/glaze.git#<GLAZE_PIN>'
npm --prefix apps/desktop ci && npm --prefix apps/desktop run build
raco test tests/        # 后端测试（假服务器，不需要真实 key）
racket verify.rkt       # 本平台真窗验收旅程
raco glaze build --entry main.rkt --version "$(cat VERSION)"   # dist/ 出包装树
```

## 诚实缺口

- **无波形、无缝衔接或 Up Next 队列**——seek、±15/30 秒跳转、1.0–3.0× 倍速、睡眠定时器、章节跳转和连续播放已有；可拖拽排序的队列没有
- **章节仅支持 Podcasting 2.0 feed 指针**——内嵌 ID3/M4A 章节原子未解析；分章总结刻意不做（LLM 账单 ×N）
- **翻译成本只受你的用量约束**——选中单集的每一句都走你的 API，长单集花费真金白银。操作区会先显示句数/字符数估算，`podlens estimate <id>` 也能打印
- **一次一种目标语言**——改 `target-lang` 后流水线会重新翻译
- **macOS 签名取决于发布证书**——配置了 Developer ID 与公证密钥时发布即签名 + 公证；缺证书时 tag 发布失败关闭，不发 ad-hoc 产物
- **Flatpak 是全新资料库**——沙盒数据目录与 `~/.podlens/` 分离；想沿用现有资料库请用 tar.gz/deb/rpm 形态

## 路线图

设计路线图见 [docs/DESIGN-ROADMAP.md](docs/DESIGN-ROADMAP.md)。移动伴随不在范围内：glaze 载体按家族政策只做桌面。

- [x] RSS 订阅 + 单集缓存 + 播放进度
- [x] ASR / 翻译 / 总结流水线，任务进度事件
- [x] 一键听懂（pipeline RPC）+ 成本估算
- [x] 一份共享 web UI 跑在 glaze 系统 WebView 载体上（macOS / Windows / Linux）
- [x] Ed25519 签名更新通道
- [x] 系统媒体键（Control Center / SMTC / MPRIS）、跳转、睡眠定时器、3× 倍速
- [x] 章节标记（Podcasting 2.0）、已播标记、未播徽章、连续播放、启动续播
- [x] macOS 公证发布；Linux 五形态包装（deb/rpm/AppImage/Flatpak/tar.gz）
- [ ] Windows Authenticode 签名发布
- [ ] 分章总结、收听统计与生词导出

## 许可

[AGPL-3.0](LICENSE)。
