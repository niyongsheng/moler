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

## Release (publish a new version)

```bash
# 1. Update version in Resources/Info.plist
#    CFBundleShortVersionString → "0.2.0"
#    CFBundleVersion → "2"

# 2. Regenerate + build Release
xcodegen generate --spec project.yml
xcodebuild -project Moler.xcodeproj -scheme Moler -configuration Release build

# 3. Package the .app as zip
cd ~/Library/Developer/Xcode/DerivedData/Moler-*/Build/Products/Release/
zip -ry /tmp/Moler-0.2.0.zip Moler.app

# 4. Tag and push
git tag -a v0.2.0 -m "v0.2.0"
git push origin v0.2.0

# 5. Create GitHub Release at https://github.com/niyongsheng/moler/releases
#    Tag: v0.2.0, upload Moler-0.2.0.zip
```

After release, users clicking "Check for Updates" in the app will detect the new version via the GitHub Releases API and be directed to the release page to download.

> **Note**: No code signing — `CODE_SIGNING_ALLOWED: NO`. Un-signed .app triggers macOS Gatekeeper. Users must allow it in System Settings → Privacy & Security.

## Architecture

Moler is a **macOS SwiftUI app** that wraps the `mo` CLI (from [tw93/Mole](https://github.com/tw93/Mole), install via `brew install mole`) in a NASA-Punk themed GUI for disk cleanup. Built with XcodeGen; the Xcode project is generated, not committed. Current version: **v0.1.0**. Version displayed in the sidebar and Settings is read dynamically from `Info.plist` via `UpdateChecker.currentVersion`.

### Entry Point & Window Lifecycle

- **`App.swift`**: `@main enum MolerMain` — creates `NSApplication`, sets `AppDelegate`, starts run loop. Checks for `--mcp` flag (MCP server mode, not implemented).
- **`AppDelegate.swift`**: Manages single-window lifecycle. Window is 900×640, transparent titlebar, rounded corners, dark navy background. Shows in Dock when window is open, hides to menu bar accessory when window closes (`LSUIElement`).

### View Hierarchy

```
RootView (HStack)
├── Sidebar (200pt) — clickable logo → Overview, 4 nav tabs, settings gear, version
├── SerifDivider (1pt, animated pulse on Overview)
└── Main Content (ZStack — all views kept alive via .visible())
    ├── OverviewView (default landing page)
    ├── CleanView (scan & cleanup)
    ├── PurgeView (project artifact cleanup via PTY-driven `mo purge`)
    ├── OptimizeView (Jupiter 3D scene via SceneKit)
    ├── AnalyzeView (disk usage treemap)
    ├── SoftwareView (software info)
    └── SettingsView
```

`Pane` enum drives navigation (`.overview`, `.clean`, `.purge`, `.optimize`, `.analyze`, `.settings`). All views stay in the hierarchy using `.visible(isVisible)` — opacity + `allowsHitTesting` — so background tasks (e.g. CleanView scan) survive tab switches.

### Overview Dashboard

Default landing page at `OverviewView.swift` — displays:
- **Stats card**: total freed bytes, clean count, last clean date, last scan path (from `Store.shared`)
- **Live system cards**: CPU usage (%) + load averages, Memory usage (%) + swap, Network rates (RX/TX Mbit/s) with disk I/O and sparkline charts
- **Disk card**: capacity, free space, usage bar
- **Quick actions**: navigate to Clean tab or Settings

System data comes from `SystemMonitor` which polls `mo status --json` every 3s and publishes `SystemStats` via `@Published`. The monitor auto-starts on appear, stops on disappear. Rolling 30-sample network history feeds `Sparkline` components.

### Clean Module Workflow (5-state machine)

`CleanViewModel.state` drives all UI:

1. **`.idle`** — stats from last scan, "INITIATE SCAN" button
2. **`.scanning(ScanProgress)`** — orbital radar animation (`ScanLine` with `SystemMonitorOverlay`), elapsed timer, progress with live items count. Scans by enumerating directory contents + running `mo analyze --json`. Supports **stop/cancel** preserving partial results.
3. **`.review(DiskScanResult)`** — scrollable file list with reticle checkboxes, select/deselect all, execute button
4. **`.running(log, progress)`** — terminal-style streaming output from `mo clean` with auto-confirm (`"y\ny\n"`), real-time log, cancel support
5. **`.done(freedBytes, filesRemoved)`** — completion summary with "NEW SCAN" button

### Mole CLI Integration Layer

| File | Role |
|------|------|
| `MoEngine.swift` | Singleton facade — single entry point for all `mo` calls |
| `MoleCLI.swift` | Executable discovery (`/opt/homebrew/bin/mo`, `/usr/local/bin/mo`, `which mo`), capture helper |
| `MoleProcess.swift` | Foundation `Process` wrapper — pipes, timeout via DispatchWorkItem, stdin support |
| `DiskScanner.swift` | Runs `mo analyze --json <path>`, parses JSON into `[DiskScanEntry]` with loose decoding |

Key commands:
- `mo analyze --json <path>` — scan, returns JSON with `total_size`, `total_files`, `entries[]`
- `mo clean` — destructive cleanup, interactive (auto-confirmed with `"y\ny\n"` via stdin)
- `mo status --json` — live system stats (CPU, memory, network, disk), polled every 3s by `SystemMonitor`

### System Monitor Module

| File | Role |
|------|------|
| `SystemMonitor.swift` | `@MainActor ObservableObject` — polls `mo status --json` via timer, publishes `SystemStats`, maintains rolling 30-sample network history for sparklines |
| `SystemStats.swift` | Decodable models: `SystemStats` (CPU, memory, network, disks, disk I/O, hardware, uptime, health), `CPUStats`, `MemoryStats`, `NetworkStats`, `DiskStats`, `DiskIOStats`, `HardwareInfo` |

### Optimize Module

| File | Role |
|------|------|
| `OptimizeView.swift` | Tab view hosting `SceneKit` scene with zoom controls, rotation hint, stats overlay |
| `JupiterScene.swift` | SceneKit-based 3D Jupiter particle scene — 200 particle point cloud, Great Red Spot (animated drift), 4 Galilean moons (orbiting), dark rings, atmosphere haze. Mouse drag rotation + scroll wheel zoom. Ported from Three.js `jupiter.js`. |

### Components Reference

| Component | File | Description |
|-----------|------|-------------|
| `Reticle` | `Reticle.swift` | Crosshair reticle — used as checkbox / decorative element |
| `ScanLine` | `ScanLine.swift` | Orbital radar animation — sweep line, orbiting dots, glow core, cardinal ticks |
| `SystemMonitorOverlay` | `SystemMonitorOverlay.swift` | 8-planet solar system animation — replaces ScanLine in scanning state, orbiting planets + scanner beam |
| `SerifDivider` | `SerifBar.swift` | Animated serif-striped divider with comet glow pulse |
| `Sparkline` | `Sparkline.swift` | Tiny area sparkline chart for live network metrics (Path-based, no axes) |
| `TopoBackground` | `TopoBackground.swift` | Animated topographic contour background — Canvas-based, contour lines + grid + stars |
| `ProgressGlow` | `ProgressGlow.swift` | Glowing progress bar |
| `DataRow` | `DataRow.swift` | Label-value data row for stats displays |
| `InstrumentPanel` | `InstrumentPanel.swift` | Bordered panel frame |
| `GlassCard` | `GlassCard.swift` | Translucent card background |
| `StarfieldBackground` | `StarfieldBackground.swift` | Starfield particle animation |
| `TypewriterLabel` | `TypewriterLabel.swift` | Typewriter-style text reveal |
| `Format` | `Format.swift` | Pure formatting functions — `bytes()`, `count()` — number/byte/date formatting |

### Persistence (Store)

`Store.shared` is a `@MainActor` singleton with `@Published` properties auto-persisted to `UserDefaults`:

| Key | Type | Description |
|-----|------|-------------|
| `hasOnboarded` | `Bool` | Onboarding completion flag |
| `language` | `String` | `""` (system), `"zh-Hans"`, `"en"` — stored in `AppleLanguages` |
| `lastScanPath` | `String` | Last scanned directory path |
| `lastCleanDate` | `Date?` | Timestamp of last clean |
| `totalFreedBytes` | `Int64` | Cumulative bytes freed |
| `totalCleanCount` | `Int` | Total clean operations performed |

Language init normalises system locale: `"zh-Hans-CN"` → `"zh-Hans"`, `"en-US"` → `"en"`. Language change requires app restart.

### Localization

`L10n.swift` defines 60+ `String(localized:)` keys with dot-notation namespacing. `.strings` files in `Resources/`. Covers navigation, clean (all 5 states), overview dashboard, settings, permissions, errors.

Language switching: three-state cycle via `Store.toggleLanguage()`:
- `""` (default) — removes `AppleLanguages` key → follows system
- `"zh-Hans"` — Simplified Chinese
- `"en"` — English

Requires app restart to take effect (writes to `AppleLanguages` UserDefaults key).

### Privilege Module

- `Privacy.swift` — checks Full Disk Access by probing TCC-protected paths. Shows NSAlert prompting user to open System Settings.
- `PrivilegeBroker.swift` — runs commands with admin privileges via AppleScript `do shell script ... with administrator privileges`.

## Key Constraints

- **macOS 14.0+** deployment target
- **Swift 5.9**
- **No code signing** (development builds only — `CODE_SIGNING_ALLOWED: NO`)
- **No hardened runtime** (`ENABLE_HARDENED_RUNTIME: NO`)
- App sandbox disabled, network client+server allowed
- SceneKit.framework linked for Jupiter 3D scene
- The `mo` CLI must be installed separately (`brew install mole`). App checks availability and shows error with install instructions if missing.
- Tests directory exists but contains no test files.

