# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**LifeClip** is an open-source "Personal Context System" — it auto-captures digital behavior (clipboard, browser, notes, AI chats) and generates AI-readable personal context. 100% local processing, zero network requests.

The project evolved from **SimpleClip** (a macOS clipboard manager with SwiftUI/SwiftData) into a full monorepo with TypeScript data processing packages and a CLI.

- **Monorepo**: npm workspaces (`packages/*`)
- **Clipboard Logger**: Swift + SwiftData (macOS native app)
- **Data Processing**: TypeScript (Node.js 18+)
- **Storage**: JSONL files in `~/.lifeclip/`
- **Minimum macOS**: 14.0+ (SwiftData requirement)
- **Full AI Features**: macOS 26.0+ (graceful degradation to NaturalLanguage framework)

## Build & Run

### Monorepo (TypeScript packages)

```bash
# Install all dependencies
npm install

# Build all packages
npm run build

# Run CLI commands
npx lifeclip collect
npx lifeclip timeline
npx lifeclip graph
npx lifeclip context
```

### Clipboard Logger (Swift app)

```bash
# Build the macOS app
xcodebuild -project SimpleClip.xcodeproj -scheme SimpleClip build

# Run the built app
open build/Build/Products/Debug/SimpleClip.app

# Open in Xcode
open SimpleClip.xcodeproj
```

**Key Configuration**: `LSUIElement = true` in Info.plist — this is a menu bar app with no dock icon.

## Monorepo Architecture

```
lifeclip/
├── package.json               # Root workspace config
├── tsconfig.base.json         # Shared TypeScript config
├── packages/
│   ├── shared/                # Unified types (LifeClipEvent) + JSONL storage utilities
│   ├── clipboard-logger/      # macOS clipboard capture (Swift + SwiftData native app)
│   ├── browser-logger/        # Chrome & Safari history extraction (SQLite DB copy)
│   ├── note-sync/             # Obsidian vault change detection (file system scan)
│   ├── ai-chat-logger/        # Claude Code session parsing (JSONL)
│   ├── context-engine/        # TF-IDF topic extraction + context graph generation
│   └── lifeclip-cli/          # CLI entry point: collect, timeline, graph, context, report, status
├── SimpleClip/                # Swift source for the macOS clipboard app
├── SimpleClip.xcodeproj/      # Xcode project
└── SimpleClipTests/           # Swift tests
```

### Package Details

- **`shared`**: Core `LifeClipEvent` type definition, JSONL read/write utilities, content hashing, PII filtering
- **`clipboard-logger`**: Bridge between the Swift macOS app's SwiftData store and the LifeClip JSONL format
- **`browser-logger`**: Copies Chrome/Safari SQLite history databases, extracts visits as events
- **`note-sync`**: Scans Obsidian vault for file changes, emits note edit events
- **`ai-chat-logger`**: Parses Claude Code JSONL session files into LifeClip events
- **`context-engine`**: TF-IDF topic extraction (pure TypeScript, no LLM), generates `graph.json` and `context.json`
- **`lifeclip-cli`**: Commander-based CLI with subcommands: `collect`, `timeline`, `graph`, `context`, `report`, `status`

## CLI Commands

```bash
lifeclip collect                    # Collect from all sources
lifeclip collect --source browser   # Browser only
lifeclip collect --since 2026-03-01 # Backfill history

lifeclip timeline                   # Today's timeline
lifeclip timeline --week            # This week

lifeclip graph                      # Topic graph (30d)
lifeclip graph --period 7d          # Last 7 days

lifeclip context                    # Generate context.json
lifeclip context --show             # View current context

lifeclip report                     # Daily report (Markdown)
lifeclip status                     # Data statistics
```

## Data Format

All events use the unified `LifeClipEvent` JSONL format:

```json
{"id":"uuid","source":"clipboard","type":"text","timestamp":"2026-03-13T10:12:00Z","content":"...","contentHash":"sha256","tags":["dev"],"topic":"AI Agent"}
```

Storage locations:
- Events: `~/.lifeclip/events/YYYY-MM-DD.jsonl` (one file per day)
- Graph: `~/.lifeclip/graph.json`
- Context: `~/.lifeclip/context.json`

## Swift App Architecture (clipboard-logger)

### Core Components

```
SimpleClip/
├── SimpleClipApp.swift          # App entry, AppDelegate, NSStatusItem setup
├── Managers/
│   └── ClipboardMonitor.swift   # Polling-based clipboard monitoring (1s interval)
├── Services/
│   └── DailySummaryService.swift # AI-powered daily digest generation
├── Models/
│   ├── ClipboardItem.swift      # SwiftData model (content, type, timestamp, hash)
│   └── DailyDigest.swift        # SwiftData model for daily summaries
└── Views/
    ├── PopoverView.swift        # Quick-access popup (400x600)
    ├── ClipboardManagerView.swift # Full management window (1200x800)
    ├── DailyDigestView.swift    # Daily summary viewer
    └── [Other views...]
```

### Clipboard Monitoring (`ClipboardMonitor.swift`)

**Architecture**: Polling-based with optimizations
- **Timer**: 1.0-second interval with 0.5s tolerance (reduces CPU usage)
- **Change detection**: Compares `NSPasteboard.general.changeCount`
- **Deduplication**: SHA256 hash of content (stored in `contentHash`)
- **Source tracking**: Records copying app via `NSWorkspace.didActivateApplicationNotification`
- **Image storage**: Saves PNG files to `~/Library/Application Support/SimpleClip/Images/`

**Data flow**:
```
NSPasteboard → checkClipboard() → hash check → SwiftData insert
```

**Special features**:
- **Auto-paste**: Simulates Cmd+V via `CGEvent` (requires accessibility permissions)
- **Content type detection**: Auto-detects URLs vs plain text

### Daily Summary Service (`DailySummaryService.swift`)

**Two-tier AI architecture**:

1. **macOS 26+ with Apple Intelligence** (preferred):
   - Uses `FoundationModels.LanguageModelSession`
   - Generates human-readable summaries with actionable advice
   - Configurable: greedy sampling, 0.3 temperature, 400 max tokens

2. **Fallback (macOS 14+)**: NaturalLanguage framework
   - Extracts keywords using `NLTagger` (lexicalClass, nameType schemes)
   - Returns structured summary: item count + keywords + links

**Concurrency safety**:
- Main thread for SwiftData operations
- `Task.detached` for CPU-intensive AI generation
- Double-check pattern prevents race conditions during digest generation

### Data Models

**ClipboardItem** (SwiftData @Model):
- `id: UUID` — unique identifier
- `content: String` — text or file path for images
- `type: ClipboardType` — enum (text/image/url)
- `timestamp: Date` — capture time
- `isPinned: Bool` — pinned items appear first
- `contentHash: String` — SHA256 for deduplication

**DailyDigest** (SwiftData @Model):
- `id: UUID` — unique identifier
- `date: Date` — start of day
- `summary: String` — AI-generated summary
- `itemCount: Int` — number of items summarized

### View Architecture

- **PopoverView**: Main quick-access interface with search/filter, pinned items first
- **ClipboardManagerView**: Three-pane NavigationSplitView (filters, content, detail)
- **DailyDigestView**: Displays AI-generated daily summaries

## Key Design Patterns

1. **Closure callbacks**: Views communicate back to AppDelegate without tight coupling
2. **Observable pattern**: `@ObservedObject` for ClipboardMonitor in views
3. **Query pattern**: SwiftData `@Query` for reactive data fetching
4. **Timer-based polling**: Clipboard monitoring with tolerance optimization

## Critical Constraints & Gotchas

### SwiftData Concurrency Safety
**CRITICAL**: All `ModelContext` operations MUST be on the main thread. The app previously had `objc_release` crashes due to SwiftData concurrency issues (fixed in commit `6e30a51`).

- Never access `ModelContext` from background threads
- Use `@MainActor` or `DispatchQueue.main.async` for database operations

### Deduplication
- Content is hashed via SHA256 before insertion
- Duplicate entries are silently skipped
- Hash is stored in `contentHash` field

### Image Handling
- Images are saved as PNG files to Application Support directory
- Thumbnails are downsampled to 200px max dimension for performance
- Image paths are stored in `content` field (type is `.image`)

### Accessibility Permissions
- Auto-paste feature requires accessibility permissions
- Check permissions before attempting `CGEvent` operations
- App gracefully degrades if permissions denied

### JSONL File Locking
- Only one process should write to a daily JSONL file at a time
- Use append mode for writes to avoid data loss
- Events are immutable once written

## Privacy & Security

- **100% Local Processing**: No network calls, all AI on-device
- **App Sandbox**: Enabled in entitlements for the Swift app
- **PII Filtering**: Built-in redaction for emails, phone numbers, credit cards before any processing
- **Content Truncation**: Only first 200-500 chars stored, never full content
- **Data location**: Swift app data in app container; LifeClip events in `~/.lifeclip/`

## User Interaction (Swift App)

- **Global hotkey**: `Cmd+Shift+V` toggles popover
- **Quit**: Right-click menu bar icon → "Quit SimpleClip" or Settings → Quit button
- **Open Manager**: Right-click menu bar icon → "Open Manager"

## Localization

- UI is primarily in Chinese (zh_CN)
- Date formatting uses `Locale(identifier: "zh_CN")`
- AI prompts are in Chinese for localized summaries

## Known Issues & Fixes

- **Fixed**: objc_release crash due to SwiftData concurrency (commit `6e30a51`)
- **Fixed**: Missing quit options (commit `a8058c6`)
- **Recent**: Performance optimizations — timer tolerance, deduplication, thumbnail optimization (commit `1571667`)

## Testing Plan

See `TESTING_PLAN.md` for comprehensive test coverage including:
- Core functionality (clipboard monitoring, data persistence, UI)
- Edge cases (empty clipboard, long text, special characters, rapid copying)
- System compatibility (permissions, dark mode, multi-display)
