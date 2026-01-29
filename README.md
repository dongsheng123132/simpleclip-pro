# SimpleClip AI - 个人工作记忆库

SimpleClip AI 是一个原生的 macOS 剪贴板管理工具，旨在从单纯的“复制粘贴工具”进化为你的**“个人工作记忆库”**。它不仅完整记录你的剪贴板历史，还利用本地 AI 技术帮助你整理、回顾和挖掘工作中的碎片信息。

## 核心功能

### 1. 无限记忆存储 (Powered by SwiftData)
- **无限记录**：彻底移除了传统剪贴板工具的条目数量限制（如 50 条）。
- **高性能架构**：底层核心已迁移至 Apple 最新的 **SwiftData** 数据库框架。
- **海量吞吐**：轻松承载数十万条文本、图片和链接记录，并在毫秒级完成检索，告别卡顿。
- **永久保存**：所有数据本地持久化存储，构建你的长期工作资产。

### 2. 智能记忆库管理器 (New)
- **独立管理窗口**：提供类似 Finder 或备忘录的独立管理界面，方便进行深度整理。
- **多维度分类**：
  - **按时间**：今天、昨天、本周、本月、更早
  - **按类型**：图片、链接、文本
  - **收藏夹**：重要内容一键固定
- **图片画廊模式**：专为设计师和开发者优化的图片浏览视图，快速回溯历史截图。
- **全文检索**：支持对历史记录进行快速全文搜索。

### 3. 本地 AI 洞察 (Privacy First)
- **每日工作摘要**：利用 macOS 本地 **Natural Language** 框架（及 Apple Intelligence），自动分析当天的剪贴内容，生成“今日工作摘要”。
- **绝对隐私**：所有 AI 分析**完全在本地运行**，任何剪贴板数据（可能包含密码、密钥等敏感信息）**绝不上传云端**。
- **智能建议**：基于内容提供简单的决策建议和关键信息提取。

## 技术栈与架构

- **开发语言**：Swift 5.9+
- **UI 框架**：SwiftUI (主界面) + AppKit (底层系统交互)
- **数据存储**：SwiftData (SQLite)
- **AI 引擎**：
  - `FoundationModels` (macOS 15+ Apple Intelligence)
  - `Natural Language` Framework (macOS 14+)
- **最低系统要求**：macOS 14.0 (Sonoma)

### 关键模块
- **ClipboardMonitor**: 核心监听服务。实时监控系统剪贴板 `NSPasteboard` 的变化，自动去重、分类并写入 SwiftData 数据库。
- **DailySummaryService**: 后台智能服务。负责在后台调度本地 AI 模型，生成每日摘要并触发通知。
- **ClipboardManagerView**: 记忆库主视图。采用 NavigationSplitView 布局，结合 `@Query` 实现高效的数据展示与筛选。

## 快速开始

1. **环境准备**：
   - Xcode 15.0 或更高版本
   - macOS 14.0 或更高版本

2. **获取代码**：
   ```bash
   git clone <repository-url>
   cd SimpleClip
   ```

3. **编译运行**：
   - 双击打开 `SimpleClip.xcodeproj`
   - 确保 Target `SimpleClip` 的 **Deployment Target** 设置为 **14.0**
   - 在 "Signing & Capabilities" 中配置你的开发团队签名
   - 点击 Run (Cmd+R)

## 开发计划

- [x] 迁移至 SwiftData 存储引擎
- [x] 实现无限历史记录
- [x] 开发记忆库管理独立窗口
- [x] 集成基础本地 AI 摘要
- [ ] 优化图片存储空间的自动清理策略
- [ ] 引入更多维度的 AI 分析（如代码片段自动识别）

## 许可证

MIT License
