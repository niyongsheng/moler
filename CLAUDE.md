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

> **Note**: No code signing — `CODE_SIGNING_ALLOWED: NO`. Un-signed .app triggers macOS Gatekeeper. Users must allow it in System Settings → Privacy & Security.

## Architecture

Moler is a **macOS SwiftUI app** that wraps the `mo` CLI (from [tw93/Mole](https://github.com/tw93/Mole), install via `brew install mole`) in a NASA-Punk themed GUI for disk cleanup. Built with XcodeGen; the Xcode project is generated, not committed. Current version: **v0.1.0**. Version displayed in the sidebar and Settings is read dynamically from `Info.plist` via `UpdateChecker.currentVersion`.

For NASA-Punk design tokens (colors, fonts, spacing, layout) see [`docs/design-token.html`](docs/design-token.html).

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

