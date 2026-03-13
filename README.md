# LifeClip

> **Personal Context System for the AI Era**
>
> AI doesn't know who you are. LifeClip fixes that — it auto-captures your digital behavior and generates AI-readable personal context. 100% local, zero network requests.

---

## Why LifeClip?

Every AI tool starts from zero — no memory of what you've been working on, what you care about, or what your day looks like. LifeClip bridges that gap:

1. **Captures** your digital behavior across clipboard, browser, notes, and AI chats
2. **Extracts** topics and patterns using TF-IDF (no LLM required)
3. **Generates** `~/.lifeclip/context.json` — a personal context file any AI can read

Think of it as **personal infrastructure for AI** — like `.gitconfig` for your identity, but for your context.

## Key Features

### AI Life Timeline

Auto-generates "what you did today", grouped by hour with topic labels.

```bash
npx lifeclip timeline
```

```
# 2026-03-13 人生时间线

## 10:00 - 11:00 | AI Research
- 10:12 📋 复制 GPT Prompt (clipboard)
- 10:18 🌐 浏览 arxiv.org/abs/2026... (browser)
- 10:35 🤖 Claude Code: "设计 LifeClip 架构" (ai_chat)
- 10:40 📝 修改 Obsidian: AI-Context-System.md (note)
```

### Two-Stage Insight Pipeline (v0.3)

A unique two-stage architecture for generating daily/weekly insights:

| Stage | What it does | Engine |
|-------|-------------|--------|
| **Stage 1: Extraction** | TF-IDF topic extraction → `StructuredInsights` JSON | Pure TypeScript |
| **Stage 2: Summarization** | Human-readable narrative from structured data | Pluggable AI provider |

Three AI providers available:

| Provider | How it works | Requirements |
|----------|-------------|-------------|
| `tfidf` (default) | Pure local TF-IDF, zero dependencies | Node.js 18+ |
| `apple-ai` | Apple Intelligence via Swift helper binary | macOS 26+, Xcode |
| `claude-api` | Claude API for high-quality summaries | API key |

```bash
npx lifeclip insights --date 2026-03-13
npx lifeclip insights --week
```

### Context Graph

All behavior auto-classified into topics, forming a personal context graph.

```bash
npx lifeclip graph
```

```
Your Life Context Graph (last 30 days)

AI Agent          ████████████████████  42 events
  📋 15  🌐 12  📝 8  🤖 7
LifeClip          ████████████████     35 events
ESP32             ████████             18 events
```

### Personal Context API

The core differentiator — outputs `~/.lifeclip/context.json` that any AI tool can read:

```bash
npx lifeclip context --show
```

```json
{
  "recentTopics": [{"name": "AI Agent", "weight": 42}],
  "activeProjects": ["LifeClip", "AirKey"],
  "summary": "过去30天主要关注: AI Agent、LifeClip、ESP32"
}
```

Feed this to Claude, GPT, or any AI assistant to give it instant personal context.

## Quick Start

```bash
# Clone & install
git clone https://github.com/dongsheng123132/lifeclip.git
cd lifeclip
npm install && npm run build

# Collect data from all sources
npx lifeclip collect

# View your day
npx lifeclip timeline

# Generate insights
npx lifeclip insights

# Generate AI-readable context
npx lifeclip context
```

## Architecture

```
lifeclip/
├── packages/
│   ├── shared/               # LifeClipEvent type + JSONL storage + PII filter + config
│   ├── clipboard-logger/     # macOS clipboard capture (Swift + SwiftData)
│   ├── browser-logger/       # Chrome & Safari history extraction (SQLite)
│   ├── note-sync/            # Obsidian vault change detection
│   ├── ai-chat-logger/       # Claude Code session parsing (JSONL)
│   ├── context-engine/       # TF-IDF + insight pipeline + 3 AI providers
│   └── lifeclip-cli/         # CLI: collect, timeline, graph, context, insights
├── SimpleClip/               # Swift macOS clipboard app source
├── SimpleClip.xcodeproj/     # Xcode project
└── tools/                    # Swift helper binaries (Apple Intelligence)
```

**Data flow:**

```
Sources (clipboard/browser/notes/AI) → LifeClipEvent JSONL
    → TF-IDF topic extraction → StructuredInsights
    → AI provider → Human-readable report
    → context.json (for any AI to read)
```

## CLI Reference

```bash
# Data collection
lifeclip collect                    # Collect from all sources
lifeclip collect --source browser   # Browser only
lifeclip collect --since 2026-03-01 # Backfill history

# Timeline
lifeclip timeline                   # Today's timeline
lifeclip timeline --week            # This week

# Context graph
lifeclip graph                      # Topic graph (30d)
lifeclip graph --period 7d          # Last 7 days

# Insights (v0.3)
lifeclip insights                   # Today's insights
lifeclip insights --date 2026-03-13 # Specific date
lifeclip insights --week            # Weekly insights

# Context API
lifeclip context                    # Generate context.json
lifeclip context --show             # View current context

# Configuration
lifeclip config                     # Show current config
lifeclip config --set insights.provider=claude-api
lifeclip config --set insights.apiKey=sk-...

# Reports & status
lifeclip report                     # Daily report (Markdown)
lifeclip status                     # Data statistics
```

## Configuration

```bash
# View config
npx lifeclip config

# Switch AI provider
npx lifeclip config --set insights.provider=apple-ai
npx lifeclip config --set insights.provider=claude-api
npx lifeclip config --set insights.apiKey=sk-ant-...

# Adjust PII level
npx lifeclip config --set pii.level=strict   # Redact paths + URL params
npx lifeclip config --set pii.level=standard # Email, phone, card, IP
npx lifeclip config --set pii.level=off      # No redaction
```

Config file: `~/.lifeclip/config.json`

## Privacy & Security

- **100% Local** — zero network requests (unless you opt into `claude-api` provider)
- **PII Filter** — auto-redacts emails, phone numbers, credit cards, API keys, IP addresses
- **Content Truncation** — only first 200-500 chars stored, never full content
- **Your Data** — everything in `~/.lifeclip/`, delete anytime

## Data Format

All events use the unified JSONL format (one file per day):

```json
{"id":"uuid","source":"clipboard","type":"text","timestamp":"2026-03-13T10:12:00Z","content":"...","contentHash":"sha256","tags":["dev"],"topic":"AI Agent"}
```

Storage locations:
- Events: `~/.lifeclip/events/YYYY-MM-DD.jsonl`
- Graph: `~/.lifeclip/graph.json`
- Context: `~/.lifeclip/context.json`
- Config: `~/.lifeclip/config.json`

Human-readable, greppable, no database lock.

## Requirements

- **Node.js 18+** (for CLI and data processing)
- **macOS 14.0+** (for clipboard logger Swift app)
- **macOS 26.0+** (optional, for Apple Intelligence insights)
- Chrome and/or Safari (for browser history)
- Obsidian (optional, for note sync)

## Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Run tests: `npm test`
4. Submit a PR

## License

[GPL-3.0](LICENSE)

---

# 中文文档

## LifeClip — AI 时代的人生上下文系统

> 你的 AI 助手不了解你。LifeClip 让它了解。

LifeClip 是一个开源的**个人上下文系统** —— 自动记录你的数字行为（剪贴板、浏览器、笔记、AI 对话），生成 AI 可理解的个人上下文。

**100% 本地处理，零网络请求，完全隐私。**

## 为什么需要 LifeClip？

每个 AI 工具都从零开始 —— 不知道你在做什么、关心什么、今天经历了什么。LifeClip 解决这个问题：

1. **采集** 剪贴板、浏览器历史、Obsidian 笔记、Claude Code 对话
2. **提取** 主题和模式（TF-IDF，无需 LLM）
3. **生成** `~/.lifeclip/context.json` —— 一份任何 AI 都能读的个人上下文

## v0.3 亮点

### 两级洞察管线

独特的两阶段架构：

| 阶段 | 作用 | 引擎 |
|------|------|------|
| **第一阶段：提取** | TF-IDF 主题提取 → `StructuredInsights` JSON | 纯 TypeScript |
| **第二阶段：总结** | 结构化数据 → 人类可读叙述 | 可插拔 AI 提供者 |

### 3 个 AI 提供者

| 提供者 | 原理 | 要求 |
|--------|------|------|
| `tfidf`（默认） | 纯本地 TF-IDF，零依赖 | Node.js 18+ |
| `apple-ai` | 通过 Swift Helper 调用 Apple Intelligence | macOS 26+, Xcode |
| `claude-api` | Claude API 生成高质量总结 | API Key |

### 核心差异化：Personal Context API

输出 `~/.lifeclip/context.json`，喂给任何 AI 助手，让它秒懂你：

```json
{
  "recentTopics": [{"name": "AI Agent", "weight": 42}],
  "activeProjects": ["LifeClip", "AirKey"],
  "summary": "过去30天主要关注: AI Agent、LifeClip、ESP32"
}
```

## 快速开始

```bash
# 克隆 & 安装
git clone https://github.com/dongsheng123132/lifeclip.git
cd lifeclip
npm install && npm run build

# 采集数据
npx lifeclip collect

# 查看今日时间线
npx lifeclip timeline

# 生成洞察
npx lifeclip insights

# 生成 AI 可读上下文
npx lifeclip context
```

## 数据源

| 来源 | 采集内容 | 方式 |
|------|----------|------|
| 📋 剪贴板 | 文本、URL、图片 | macOS 原生应用 (Swift) |
| 🌐 浏览器 | Chrome & Safari 历史 | SQLite 数据库复制 |
| 📝 笔记 | Obsidian 笔记变更 | 文件系统扫描 |
| 🤖 AI 对话 | Claude Code 会话 | JSONL 解析 |

## CLI 命令

```bash
lifeclip collect                    # 采集所有来源
lifeclip collect --source browser   # 仅浏览器
lifeclip collect --since 2026-03-01 # 回填历史

lifeclip timeline                   # 今日时间线
lifeclip timeline --week            # 本周时间线

lifeclip graph                      # 主题图谱（30天）
lifeclip graph --period 7d          # 最近7天

lifeclip insights                   # 今日洞察
lifeclip insights --week            # 周度洞察

lifeclip context                    # 生成 context.json
lifeclip context --show             # 查看当前上下文

lifeclip config                     # 查看配置
lifeclip report                     # 日报（Markdown）
lifeclip status                     # 数据统计
```

## 隐私 & 安全

- 🔒 **100% 本地** — 零网络请求（除非主动选择 `claude-api`）
- 🛡️ **PII 过滤** — 自动脱敏邮箱、手机号、信用卡、API Key、IP 地址
- 📝 **内容截断** — 仅存储前 200-500 字符，绝不存完整内容
- 📂 **数据自主** — 所有数据在 `~/.lifeclip/`，随时可删

## 技术栈

- **Swift + SwiftData** — 剪贴板监控（macOS 14+）
- **TypeScript** — 数据处理（Node.js 18+）
- **JSONL** — 存储格式（人类可读，Git 友好）
- **TF-IDF** — 主题提取（纯 TS，无需 LLM）
- **npm workspaces** — Monorepo 管理

## 开源协议

[GPL-3.0](LICENSE)
