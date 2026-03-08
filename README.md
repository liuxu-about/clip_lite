# ClipLite

ClipLite is a lightweight macOS menu bar clipboard history manager built with Swift, SwiftUI, and AppKit.

## Highlights

- Runs as a menu bar app with no Dock icon
- Monitors clipboard history for text and images
- Shows a non-activating quick-paste panel via global hotkey
- Persists history with SQLite plus file storage for image assets
- Includes cleanup, thumbnail generation, startup options, and regression tests

## Requirements

- macOS 13+
- Swift 6.2 toolchain

## Development

```bash
swift build
swift build -c release
swift test
```

Run the app after a debug build:

```bash
.build/debug/ClipLite
```

Create an unsigned app bundle and zip artifact locally:

```bash
./scripts/package_app.sh
```

## Project Layout

- `ClipLite/App` — app lifecycle and coordination
- `ClipLite/Core` — clipboard, storage, panel, settings, permissions, hotkey, image services
- `ClipLite/UI` — menu bar, panel, and settings UI
- `ClipLite/Models` — shared models
- `ClipLite/Utilities` — helpers and supporting utilities
- `Tests/ClipLiteTests` — XCTest coverage
- `docs/` — MVP notes and development progress

## Notes

- `dist/` and `.build/` are local build/package artifacts and are intentionally ignored from Git.
- The app uses `sqlite3` from the system library.
