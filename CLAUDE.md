# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClipLite is a macOS menu bar clipboard history manager. It runs as a background agent (LSUIElement = YES) with no Dock icon, monitoring the system clipboard and providing quick access to history via a global hotkey.

**Core User Flow**: User presses `Cmd+Shift+V` → non-activating panel appears → arrow keys navigate → Enter auto-pastes to the original app via CGEvent.

## Build & Run Commands

- `swift build` - Build debug binary
- `swift build -c release` - Build release binary
- `swift test` - Run tests (currently no tests exist)
- `.build/debug/ClipLite` - Run the debug app directly

Always run `swift build` before opening a PR to catch compile-time issues.

## Architecture Overview

### Module Structure

The codebase follows a feature-oriented layout:

- **App/**: Lifecycle management (`ClipLiteApp`, `AppDelegate`, `AppCoordinator`)
- **Core/**: Domain-specific services organized by feature
  - `Clipboard/`: Monitoring, parsing, paste execution
  - `Storage/`: SQLite + file system persistence, cleanup
  - `Panel/`: NSPanel management and keyboard event routing
  - `Hotkey/`: Global hotkey registration
  - `Settings/`: User preferences and startup management
  - `Permissions/`: Accessibility permission handling
  - `Image/`: Thumbnail generation
- **UI/**: Presentation layer (MenuBar, Panel, Settings)
- **Models/**: Shared data types (`ClipItem`, `AppSettings`, etc.)
- **Utilities/**: Helpers and extensions

### Data Flow

1. **Clipboard Monitoring**: `ClipboardMonitor` polls `NSPasteboard.changeCount` every 500ms
2. **Parsing & Storage**: `ClipboardParser` extracts text/images → `HistoryStore` persists to SQLite + local files
3. **Panel Display**: Global hotkey → `ClipboardPanelController` shows `NSPanel` with history
4. **Paste Execution**: User selects item → `PasteExecutor` writes to pasteboard + sends `Cmd+V` via CGEvent

### Storage Strategy

- **SQLite**: Metadata (id, type, content, timestamps, hash, file paths)
- **File System**: Images stored as originals + thumbnails in `~/Library/Application Support/ClipLite/Images/`
- **Cleanup**: Triggered on startup and after new items, removes records exceeding `maxItemCount` or `maxRetentionDays`

## Critical Technical Constraints

### 1. Non-Activating Panel Behavior

The clipboard panel MUST use `NSPanel` with `.nonactivatingPanel` to avoid disrupting the user's current app context:

- Display with `panel.makeKeyAndOrderFront(nil)` - NEVER call `NSApp.activate()`
- Panel can receive keyboard events without bringing the app to the foreground
- Settings window is an exception - it DOES activate the app when opened

### 2. Keyboard Event Handling

SwiftUI `List` keyboard behavior is unreliable in non-activating panels. Solution:

- Use `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` at the panel level
- Intercept `↑`, `↓`, `Enter`, `Esc` and handle them in `PanelKeyEventRouter`
- Return `nil` after handling to prevent event propagation
- Remove the monitor when the panel closes

### 3. Clipboard Self-Loop Prevention

When `PasteExecutor` writes to `NSPasteboard`, it triggers the monitor. To prevent re-recording:

- Record the `changeCount` immediately after writing to the pasteboard
- `ClipboardMonitor` must ignore this specific `changeCount` in its next poll
- This prevents the app from treating its own paste operations as new clipboard entries

### 4. Auto-Paste Requirements

Auto-paste via `CGEvent` requires:

- **Accessibility permission** (`AXIsProcessTrusted()`)
- **App Sandbox DISABLED** in Xcode project settings (Target → Signing & Capabilities)
- Fallback: If permission denied or CGEvent fails, content is still in pasteboard for manual `Cmd+V`

### 5. Threading Model

- **Main thread**: All UI operations (menu bar, panel, settings)
- **Background serial queue**: Clipboard parsing, hash calculation, image processing, database writes, cleanup
- **Database queue**: SQLite operations must be serialized to avoid conflicts

## Key Patterns & Conventions

### Concurrency

- Use `@MainActor` for UI entry points
- Dedicated queues for storage and background work
- All expensive operations (image processing, database writes) run off the main thread

### File Organization

- One primary type per file, filename matches type name (e.g., `HistoryStore.swift`)
- Keep feature code in matching folders (storage logic in `Core/Storage`)
- 4-space indentation, no tabs

### Error Handling

- Don't let single clipboard parse failures interrupt monitoring
- Don't let thumbnail generation failures block original image saves
- Auto-paste failures should preserve the pasteboard write and notify the user
- File deletion failures during cleanup should be logged but not block subsequent deletions

### Deduplication

- Calculate hash for text content (normalized) and image binary data
- Compare only with the most recent item (consecutive duplicate prevention)
- This avoids blocking legitimate re-use of the same content later

## Platform Requirements

- **Minimum macOS**: 13.0+ (for `SMAppService` and mature SwiftUI/AppKit interop)
- **Dependencies**: SQLite (system library, linked via Package.swift)
- **Info.plist**: `LSUIElement = YES` for agent behavior (no Dock icon, no Cmd+Tab appearance)
