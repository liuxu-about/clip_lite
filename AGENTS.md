# Repository Guidelines

## Project Structure & Module Organization
`ClipLite/` is the executable target root. Keep new code inside the existing feature-oriented layout:
- `ClipLite/App`: app lifecycle and coordination (`ClipLiteMain`, `AppDelegate`, `AppCoordinator`).
- `ClipLite/Core`: core services by domain (`Clipboard`, `Storage`, `Panel`, `Hotkey`, `Settings`, `Permissions`, `Image`).
- `ClipLite/UI`: SwiftUI/AppKit presentation (`MenuBar`, `Panel`, `Settings`).
- `ClipLite/Models` and `ClipLite/Utilities`: shared data types and helpers.
- `ClipLite/Resources/Info.plist`: app runtime configuration (agent/menu-bar behavior).
- `Package.swift`: SwiftPM manifest.
- `dist/`: packaging artifacts (currently includes `ClipLite-unsigned.zip`).

## Build, Test, and Development Commands
- `swift build`: build debug binary.
- `swift build -c release`: build production configuration.
- `swift test`: run XCTest suites (currently reports `no tests found` until tests are added).
- `.build/debug/ClipLite`: run the app directly after a debug build.

Run build commands before opening a PR to catch compile-time regressions early.

## Coding Style & Naming Conventions
Use Swift defaults reflected in this codebase:
- 4-space indentation, no tabs.
- Types/protocols: `UpperCamelCase`; methods/properties/cases: `lowerCamelCase`.
- One primary type per file; filename should match the type (for example, `HistoryStore.swift`).
- Keep feature code in matching folders (for example, storage logic stays in `Core/Storage`).
- Prefer explicit concurrency boundaries (`@MainActor` for UI entry points, dedicated queues for storage/background work).

No SwiftLint/SwiftFormat config is currently committed; keep style consistent with surrounding files.

## Testing Guidelines
Create tests under `Tests/ClipLiteTests/` using XCTest.
- Test file naming: `<TypeName>Tests.swift`.
- Test method naming: `test_<Scenario>_<ExpectedResult>()`.
- Prioritize `ClipboardParser`, `HistoryStore`/`SQLiteManager`, cleanup behavior, and paste fallback paths.

## Commit & Pull Request Guidelines
This snapshot has no local `.git` metadata, so historical commit conventions cannot be derived here. Recommended convention:
- Use Conventional Commit prefixes (`feat:`, `fix:`, `refactor:`, `chore:`).
- Keep subject lines imperative and under ~72 characters.

PRs should include:
- Change summary and motivation.
- Verification steps/outputs (`swift build`, `swift build -c release`, `swift test` status).
- Screenshots or short recordings for UI/interaction changes.
- Linked issue/task ID when applicable.
