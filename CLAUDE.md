# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SimpleClip is a **macOS clipboard manager** that has evolved into a **Personal Work Memory Bank** with infinite storage, local AI capabilities, and intelligent daily summaries. Built entirely with SwiftUI and SwiftData.

- **Entry Point**: `SimpleClip/SimpleClipApp.swift`
- **Language**: Swift
- **Minimum macOS**: 14.0+ (SwiftData requirement)
- **Full AI Features**: macOS 26.0+ (graceful degradation to NaturalLanguage framework)

## Build & Run

```bash
# Build the project
xcodebuild -project SimpleClip.xcodeproj -scheme SimpleClip build

# Run the built app
open build/Build/Products/Debug/SimpleClip.app

# Open in Xcode
open SimpleClip.xcodeproj
```

**Key Configuration**: `LSUIElement = true` in Info.plist - this is a menu bar app with no dock icon.

## Architecture

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
- `id: UUID` - unique identifier
- `content: String` - text or file path for images
- `type: ClipboardType` - enum (text/image/url)
- `timestamp: Date` - capture time
- `isPinned: Bool` - pinned items appear first
- `contentHash: String` - SHA256 for deduplication

**DailyDigest** (SwiftData @Model):
- `id: UUID` - unique identifier
- `date: Date` - start of day
- `summary: String` - AI-generated summary
- `itemCount: Int` - number of items summarized

### View Architecture

**PopoverView**: Main quick-access interface with search/filter, pinned items first
**ClipboardManagerView**: Three-pane NavigationSplitView (filters, content, detail)
**DailyDigestView**: Displays AI-generated daily summaries

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

## Privacy & Security

- **100% Local Processing**: No network calls, all AI on-device
- **App Sandbox**: Enabled in entitlements
- **Data location**: SwiftData database in app container, images in Application Support

## User Interaction

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
- **Recent**: Performance optimizations - timer tolerance, deduplication, thumbnail optimization (commit `1571667`)

## Testing Plan

See `TESTING_PLAN.md` for comprehensive test coverage including:
- Core functionality (clipboard monitoring, data persistence, UI)
- Edge cases (empty clipboard, long text, special characters, rapid copying)
- System compatibility (permissions, dark mode, multi-display)
