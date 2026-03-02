<p align="center">
  <h1 align="center">SimpleClip</h1>
  <p align="center"><b>Your Personal Work Memory Bank</b></p>
  <p align="center">
    <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+"/>
    <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift 5.9"/>
    <img src="https://img.shields.io/badge/license-GPL--3.0-green" alt="GPL-3.0"/>
    <img src="https://img.shields.io/badge/AI-100%25%20Local-purple" alt="100% Local AI"/>
  </p>
</p>

---

[English](#english) | [中文](#中文)

---

<a id="english"></a>

## English

### Not Just a Clipboard Manager

Every day, you copy and paste dozens — maybe hundreds — of things: code snippets, API keys, URLs, design feedback, meeting notes, error logs. Most clipboard managers treat them as disposable. **SimpleClip treats them as your work memory.**

Think about it: your clipboard is a stream of everything you've touched throughout the day. SimpleClip captures that stream, stores it permanently, and uses on-device AI to turn it into a daily digest — a summary of what you actually worked on, not what your calendar says you did.

**No cloud. No tokens. No subscription. Everything stays on your Mac.**

> Clipboard in, memory out. That's SimpleClip.

### Features

- **Unlimited History** — Powered by SwiftData, handles 100,000+ records without lag
- **Smart Deduplication** — SHA256 hash-based, automatically skips duplicate content
- **Image Support** — Auto-saves copied images with thumbnail previews
- **Local AI Daily Digest** — Auto-generates clipboard content summaries (Apple Intelligence on macOS 26+ / NaturalLanguage fallback)
- **PII Filtering** — Automatically redacts personal names, emails, phone numbers before AI processing
- **Global Hotkey** — `Cmd+Shift+V` for instant access
- **Memory Bank Manager** — Three-pane management UI with search, filter, and batch operations
- **100% Local** — Zero network requests, zero data uploads, fully offline
- **Menu Bar App** — Lives in your menu bar, no Dock icon

### System Requirements

| Feature | Minimum |
|---------|---------|
| Core | macOS 14.0+ (Sonoma) |
| Full AI Digest | macOS 26.0+ / macOS 14.0+ (keyword extraction fallback) |
| Architecture | Apple Silicon (ARM64) / Intel (x86_64) |

### Installation

#### Option 1: Homebrew (Recommended)

```bash
brew tap dongsheng123132/tap
brew install --cask simpleclip
```

Auto-downloads, installs, and handles macOS security — no manual steps needed. Update with `brew upgrade --cask simpleclip`.

#### Option 2: One-Line Install Script

```bash
curl -fsSL https://raw.githubusercontent.com/dongsheng123132/simpleclip-pro/main/install.sh | bash
```

Auto-downloads latest DMG, installs to /Applications, removes quarantine, and launches.

#### Option 3: Manual Download

1. Go to the [Releases](../../releases) page
2. Download the latest `SimpleClip-vX.X.X.dmg`
3. Open the DMG and drag SimpleClip to your Applications folder
4. **First launch**: Run `xattr -cr /Applications/SimpleClip.app` in Terminal (the app is not code-signed)

#### Option 4: Build from Source

```bash
git clone https://github.com/dongsheng123132/simpleclip-pro.git
cd simpleclip-pro
xcodebuild -project SimpleClip.xcodeproj -scheme SimpleClip build
open build/Build/Products/Debug/SimpleClip.app
```

### Usage

| Action | How |
|--------|-----|
| Show/Hide | `Cmd + Shift + V` or click menu bar icon |
| Copy item | Click any item |
| Copy & Paste | Double-click item (requires Accessibility permission) |
| Open Manager | Right-click menu bar icon → "Open Manager" |
| Quit | Right-click menu bar icon → "Quit SimpleClip" |

### Privacy & PII Protection

SimpleClip is built on a simple principle: **your work memory belongs to you, not the cloud.**

- All data stored in on-device SwiftData database
- AI analysis runs entirely on-device (Apple Intelligence / NaturalLanguage)
- **PII auto-redaction**: Personal names, emails, phone numbers, and addresses are automatically stripped before AI processing — even the local AI only sees sanitized content
- Zero network requests, zero telemetry, zero data uploads
- App Sandbox enabled — the app can't access anything outside its container

### Contributing

PRs and Issues welcome!

1. Fork this repo
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

<a id="中文"></a>

## 中文

### 不只是剪贴板管理器

每天你复制粘贴几十甚至上百次：代码片段、API Key、URL、设计反馈、会议笔记、报错日志。大多数剪贴板工具把它们当作用完即弃的临时数据。**SimpleClip 把它们当作你的工作记忆。**

想想看——你的剪贴板就是你一天工作的信息流。SimpleClip 捕获这条信息流，永久保存，然后用本地 AI 把它变成每日工作摘要——一份关于你**真正做了什么**的总结，而不是日历上写了什么。

**不走云端。不烧 token。不收订阅费。一切都在你的 Mac 上。**

> 剪贴板进，记忆出。这就是 SimpleClip。

### 功能特性

- **无限历史记录** — 基于 SwiftData，支持 10 万+ 条记录无卡顿
- **智能去重** — SHA256 哈希自动跳过重复内容
- **图片支持** — 自动保存复制的图片，缩略图预览
- **本地 AI 日报** — 每日自动生成剪贴板内容摘要（macOS 26+ Apple Intelligence / 低版本 NaturalLanguage 降级）
- **PII 隐私过滤** — AI 处理前自动脱敏个人姓名、邮箱、电话号码等敏感信息
- **全局快捷键** — `Cmd+Shift+V` 快速呼出
- **记忆库管理器** — 三栏管理界面，搜索、筛选、批量管理
- **100% 本地** — 无网络请求，无数据上传，完全离线运行
- **菜单栏应用** — 不占 Dock 位置，常驻菜单栏

### 系统要求

| 功能 | 最低要求 |
|------|----------|
| 基础功能 | macOS 14.0+ (Sonoma) |
| AI 智能日报 | macOS 26.0+ (完整功能) / macOS 14.0+ (关键词提取降级) |
| 架构 | Apple Silicon (ARM64) / Intel (x86_64) |

### 安装

#### 方式一：Homebrew（推荐）

```bash
brew tap dongsheng123132/tap
brew install --cask simpleclip
```

自动下载、安装、处理 macOS 安全限制，无需手动操作。更新：`brew upgrade --cask simpleclip`

#### 方式二：一键安装脚本

```bash
curl -fsSL https://raw.githubusercontent.com/dongsheng123132/simpleclip-pro/main/install.sh | bash
```

自动下载最新 DMG、安装到 /Applications、去除隔离标记并启动。

#### 方式三：手动下载

1. 前往 [Releases](../../releases) 页面
2. 下载最新的 `SimpleClip-vX.X.X.dmg`
3. 打开 DMG，拖拽 SimpleClip 到应用程序文件夹
4. **首次打开**：终端运行 `xattr -cr /Applications/SimpleClip.app`（应用未签名，需手动解除限制）

#### 方式四：从源码构建

```bash
git clone https://github.com/dongsheng123132/simpleclip-pro.git
cd simpleclip-pro
xcodebuild -project SimpleClip.xcodeproj -scheme SimpleClip build
open build/Build/Products/Debug/SimpleClip.app
```

### 使用方法

| 操作 | 方式 |
|------|------|
| 呼出/隐藏 | `Cmd + Shift + V` 或点击菜单栏图标 |
| 复制条目 | 点击任意条目 |
| 复制并粘贴 | 双击条目（需辅助功能权限） |
| 打开管理器 | 右键菜单栏图标 → 「打开管理界面」 |
| 退出应用 | 右键菜单栏图标 → 「退出 SimpleClip」 |

### 隐私 & PII 保护

SimpleClip 的设计原则很简单：**你的工作记忆属于你，不属于云端。**

- 所有数据存储在本机 SwiftData 数据库中
- AI 分析完全在设备端运行（Apple Intelligence / NaturalLanguage）
- **PII 自动脱敏**：个人姓名、邮箱、电话、地址在 AI 处理前自动过滤——即使是本地 AI 也只看到脱敏后的内容
- 无网络请求，无遥测，无数据上传
- App Sandbox 已启用——应用无法访问容器外的任何内容

### 贡献

欢迎 PR 和 Issue！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交修改 (`git commit -m 'Add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

---

## Tech Stack / 技术栈

- **Language**: Swift
- **UI**: SwiftUI
- **Data**: SwiftData
- **AI**: FoundationModels (macOS 26+) / NaturalLanguage (fallback)
- **Architecture**: Menu Bar App (LSUIElement)

## License / 许可证

[GPL-3.0](LICENSE)

You can freely use, modify, and distribute. Modified versions must also be open-sourced.

你可以自由使用、修改和分发。修改后的版本也必须开源。

## Vision / 愿景

The future of personal productivity tools is **local-first AI**. Sensitive data stays on your device; only when you need cloud-level intelligence do you opt in — and even then, PII gets filtered first.

SimpleClip is an early step toward that future: a tool that remembers everything you've worked on, understands the patterns, and keeps your privacy intact.

个人效率工具的未来是**本地优先的 AI**。敏感数据留在设备上；只有当你需要云端级别的智能时才主动选择——即便如此，PII 也会先被过滤。

SimpleClip 是迈向这个未来的早期一步：一个记住你所有工作内容、理解其中规律、同时守住隐私的工具。

## Roadmap / 未来计划

- [ ] App Store release (SimpleClip Pro) / App Store 上架
- [ ] iCloud Sync / iCloud 同步
- [ ] Deep work pattern analysis / 深度工作模式分析
- [ ] Cross-app context awareness / 跨应用上下文感知
- [ ] Custom hotkeys / 自定义快捷键
- [ ] Plugin system / 插件系统

---

**Built with Swift & SwiftUI. Powered by on-device AI.**
