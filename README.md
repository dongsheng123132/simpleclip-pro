<p align="center">
  <h1 align="center">SimpleClip</h1>
  <p align="center">
    macOS Clipboard Manager & Personal Work Memory Bank<br/>
    macOS 剪贴板管理器 & 个人工作记忆库
  </p>
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

#### Option 1: Download (Recommended)

1. Go to the [Releases](../../releases) page
2. Download the latest `SimpleClip.dmg`
3. Open the DMG and drag SimpleClip to your Applications folder
4. **First launch**: Since the app is unsigned, macOS will block it:
   - Right-click SimpleClip.app → Select "Open"
   - Click "Open" in the dialog
   - Or: System Settings → Privacy & Security → Click "Open Anyway"

#### Option 2: Build from Source

```bash
git clone https://github.com/YOUR_USERNAME/SimpleClip.git
cd SimpleClip
xcodebuild -project SimpleClip.xcodeproj -scheme SimpleClip build
open build/Build/Products/Debug/SimpleClip.app
```

Or open `SimpleClip.xcodeproj` in Xcode and run directly.

### Usage

| Action | How |
|--------|-----|
| Show/Hide | `Cmd + Shift + V` or click menu bar icon |
| Copy item | Click any item |
| Copy & Paste | Double-click item (requires Accessibility permission) |
| Open Manager | Right-click menu bar icon → "Open Manager" |
| Quit | Right-click menu bar icon → "Quit SimpleClip" |

### Privacy

SimpleClip is 100% local:
- All data stored in on-device SwiftData database
- AI analysis runs entirely on-device
- PII (personal names, emails, phone numbers) is automatically redacted before AI processing
- Zero network requests, zero telemetry, zero data uploads

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

#### 方式一：直接下载（推荐）

1. 前往 [Releases](../../releases) 页面
2. 下载最新的 `SimpleClip.dmg`
3. 打开 DMG，拖拽 SimpleClip 到应用程序文件夹
4. **首次打开**：由于未签名，macOS 会阻止运行：
   - 右键点击 SimpleClip.app → 选择「打开」
   - 在弹出的对话框中点击「打开」
   - 或者：系统设置 → 隐私与安全性 → 点击「仍要打开」

#### 方式二：从源码构建

```bash
git clone https://github.com/YOUR_USERNAME/SimpleClip.git
cd SimpleClip
xcodebuild -project SimpleClip.xcodeproj -scheme SimpleClip build
open build/Build/Products/Debug/SimpleClip.app
```

或者用 Xcode 打开 `SimpleClip.xcodeproj` 直接运行。

### 使用方法

| 操作 | 方式 |
|------|------|
| 呼出/隐藏 | `Cmd + Shift + V` 或点击菜单栏图标 |
| 复制条目 | 点击任意条目 |
| 复制并粘贴 | 双击条目（需辅助功能权限） |
| 打开管理器 | 右键菜单栏图标 → 「打开管理界面」 |
| 退出应用 | 右键菜单栏图标 → 「退出 SimpleClip」 |

### 隐私

SimpleClip 是 100% 本地应用：
- 所有数据存储在本机 SwiftData 数据库中
- AI 分析完全在设备端运行
- PII（个人姓名、邮箱、电话）在 AI 处理前自动脱敏
- 无网络请求，无遥测，无数据上传
- 你的剪贴板历史只属于你

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

## Roadmap / 未来计划

- [ ] App Store release (SimpleClip Pro)
- [ ] iCloud Sync
- [ ] Smarter AI analysis
- [ ] Custom hotkeys
- [ ] Plugin system

---

**Built with Swift & SwiftUI**
