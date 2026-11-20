# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Regenerate Xcode project from project.yml (required after changing project.yml)
xcodegen generate --spec project.yml

# Build Debug
xcodebuild -project Moler.xcodeproj -scheme Moler -configuration Debug build

# Clean build
xcodebuild -project Moler.xcodeproj -scheme Moler -configuration Debug clean build

# Run the built app
open ~/Library/Developer/Xcode/DerivedData/Moler-*/Build/Products/Debug/Moler.app

# Run tests (none yet — Tests/ is empty)
xcodebuild -project Moler.xcodeproj -scheme MolerTests -configuration Debug test
```

## Release

See `moler-release` skill (`.claude/skills/moler-release/SKILL.md`) for the full release checklist — build, tag, zip, and upload to GitHub.

CI (`.github/workflows/ci.yml`) builds a **universal** Release (arm64 + x86_64), ad-hoc signs the app, and ships three formats: `.pkg` (installs to `/Applications`; `packaging/pkg-scripts/postinstall` clears quarantine), `.dmg`, and `.zip`. Every release must include the stable asset name **`Moler.pkg`** — `docs/index.html` links directly to `https://github.com/niyongsheng/moler/releases/latest/download/Moler.pkg` for the always-latest download button.

> **Note**: No Developer ID — the app is ad-hoc signed only, and the `.pkg` itself is unsigned. Gatekeeper still asks users to confirm/allow the download on first install.

## Architecture

Moler is a **macOS SwiftUI app** that wraps the `mo` CLI (from [tw93/Mole](https://github.com/tw93/Mole), install via `brew install mole`) in a NASA-Punk themed GUI for disk cleanup. Built with XcodeGen; the Xcode project is generated, not committed. Current version: **v0.1.0**. Version displayed in the sidebar and Settings is read dynamically from `Info.plist` via `UpdateChecker.currentVersion`.

For NASA-Punk design tokens (colors, fonts, spacing, layout) see [`docs/design-token.html`](docs/design-token.html).

### Mole CLI Compatibility Notes

- Since Mole **V1.62.0**, `mo uninstall <name>` requires a real terminal for its confirmation prompt. `MolePTYProcess` gives the child a PTY on stdin only (no controlling terminal) and answers the `Enter confirm` prompt; keep this path for uninstall commands.
- Parse `mo clean` totals from its summary line (`CleanSummaryParser`). Mole **1.67+** prints `Removed: 6.74GB · 768 items` for real runs and `Potential space: 6.74GB · 768 items` for dry runs; older releases used `Tracked cleanup: … | Items cleaned: …`. The parser accepts both. Summing every size token in the log over-counts badly.
- Since Mole **1.67**, `mo optimize` dry-run task rows use `○`; real runs use `✓` (older releases used `→` for in-progress). `OptimizeOutputParser` accepts all three, plus the `⊙` diagnosis note marker.
- `mo uninstall --dry-run <name>` still prints its preview without a TTY (it exits after printing the plan), so previews use a normal pipe.
- Since Mole **1.68/1.71**, `mo uninstall` can exit 0 while silently skipping an app (vendor uninstaller required, protected container). `SoftwareViewModel` also checks the bundle is gone and surfaces the warning text as the failure reason.
- `MoleCLI.minimumVersion` is **1.62.0**; Settings shows the installed `mo` version and warns below that.
- `mo purge` requires `--yes` for unattended runs — the app currently deletes Purge entries itself and does not call it.

### Analytics

- **`Sources/Analytics.swift`**: Thin wrapper around the Aptabase Swift SDK (SPM dependency declared in `project.yml`). `AppDelegate` calls `Analytics.configure()` on launch; view models track feature-completion events. Event props must stay non-identifying — counts and byte sizes only, never paths or app names.

### Entry Point & Window Lifecycle

- **`App.swift`**: `@main enum MolerMain` — creates `NSApplication`, sets `AppDelegate`, starts run loop. Checks for `--mcp` flag (MCP server mode, not implemented).
- **`AppDelegate.swift`**: Manages single-window lifecycle. Window is 900×640, transparent titlebar, rounded corners, dark navy background. Shows in Dock when window is open, hides to menu bar accessory when window closes (`LSUIElement`).

## Key Constraints

- **macOS 14.0+** deployment target
- **Swift 5.9**
- **No code signing** (development builds only — `CODE_SIGNING_ALLOWED: NO`)
- **No hardened runtime** (`ENABLE_HARDENED_RUNTIME: NO`)
- App sandbox disabled, network client+server allowed
- SceneKit.framework linked for Jupiter 3D scene
- The `mo` CLI must be installed separately (`brew install mole`). App checks availability and shows error with install instructions if missing.
- Tests directory exists but contains no test files.

