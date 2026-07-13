import Foundation
import SwiftUI

// MARK: - State Machine

/// The state machine for Analyze (disk usage treemap) operations.
enum AnalyzeState: Equatable {
    /// Initial state with "Scan Home" button + history
    case idle

    /// Scanning via `mo analyze --json <path>`
    case scanning(progress: AnalyzeProgress)

    /// Scan complete, treemap ready to display
    case loaded(result: DiskScanResult, breadcrumb: [BreadcrumbItem])

    /// Fatal error
    case error(String)

    static func == (lhs: AnalyzeState, rhs: AnalyzeState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.scanning, .scanning): return true
        case (.loaded(let a, _), .loaded(let b, _)): return a.path == b.path
        case (.error, .error): return true
        default: return false
        }
    }
}

// MARK: - Supporting Types

struct AnalyzeProgress: Equatable {
    let currentPath: String
    let elapsedSeconds: Int
}

/// A clickable item in the breadcrumb navigation path.
struct BreadcrumbItem: Identifiable, Equatable {
    let id: String   // path
    let name: String // display name
}

/// A treemap cell after layout — contains the computed rectangle and styling.
struct TreemapCell: Identifiable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let isDir: Bool
    let weight: Double       // 0...1 normalised size proportion
    let rect: CGRect         // computed by TreemapLayout
    let color: Color         // pre-computed based on type/extension
}

// MARK: - Color helpers

/// A curated palette of 18 distinct colors for treemap blocks, spanning the hue
/// spectrum at roughly equal visual intervals, plus a few neutral tones. Colors
/// are designed to work on dark backgrounds (NASA-Punk dark navy).
private let treemapPalette: [Color] = [
    Color(hex: "#4a9eff"), // bright blue
    Color(hex: "#34d399"), // emerald
    Color(hex: "#f472b6"), // pink
    Color(hex: "#a78bfa"), // purple
    Color(hex: "#fbbf24"), // amber
    Color(hex: "#60a5fa"), // sky blue
    Color(hex: "#fb923c"), // orange-light
    Color(hex: "#2dd4bf"), // teal
    Color(hex: "#f87171"), // red-light
    Color(hex: "#818cf8"), // indigo
    Color(hex: "#facc15"), // yellow
    Color(hex: "#6ee7b7"), // mint
    Color(hex: "#c084fc"), // violet
    Color(hex: "#38bdf8"), // light blue
    Color(hex: "#fb7185"), // rose
    Color(hex: "#a3e635"), // lime
    Color(hex: "#67e8f9"), // cyan
    Color(hex: "#e879f9"), // fuchsia
]

/// Returns a stable colour for a given file entry.
///
/// - Directories always get accent orange (consistent visual anchor).
/// - Common file extensions get semantic colours (archives = gold, media = purple, etc.).
/// - Everything else gets a deterministic colour derived from a hash of its name,
///   drawn from the 18-colour `treemapPalette` so adjacent blocks are visually distinct.
func treemapColor(for entry: DiskScanEntry) -> Color {
    if entry.isDir {
        // Warm hue palette anchored near accentOrange — deterministic hash
        // per directory name gives visual variety while keeping a warm anchor.
        let dirPalette: [Color] = [
            Brand.accentOrange,        // #e06236
            Color(hex: "#d47a3a"),     // amber-orange
            Color(hex: "#c4703a"),     // burnt orange
            Color(hex: "#e88d4a"),     // lighter orange
            Color(hex: "#cc6633"),     // deep orange
            Color(hex: "#d7ab61"),     // gold
        ]
        let hash = entry.name.hash
        let index = abs(hash) % dirPalette.count
        return dirPalette[index]
    }

    let ext = URL(fileURLWithPath: entry.path).pathExtension.lowercased()

    // Semantic colours for common file families
    switch ext {
    case "zip", "gz", "tar", "bz2", "7z", "rar", "xz":
        return Brand.accentGold
    case "dmg", "iso", "img":
        return Brand.accentBlue
    case "app", "framework", "xcappdata":
        return Color(hex: "#f87171") // rose
    case "mp4", "mov", "avi", "mkv", "webm", "wmv", "flv":
        return Color(hex: "#a78bfa") // purple
    case "mp3", "wav", "flac", "aac", "m4a", "wma", "ogg":
        return Color(hex: "#f472b6") // pink
    case "png", "jpg", "jpeg", "gif", "heic", "webp", "bmp", "tiff", "svg":
        return Color(hex: "#34d399") // emerald
    case "pdf", "doc", "docx", "pages", "txt", "md", "rst", "rtf":
        return Color(hex: "#60a5fa") // sky blue
    case "xls", "xlsx", "numbers", "csv", "tsv":
        return Color(hex: "#2dd4bf") // teal
    case "ppt", "pptx", "key", "odp":
        return Color(hex: "#fb923c") // orange-light
    case "json", "xml", "yaml", "yml", "toml", "plist":
        return Color(hex: "#a3e635") // lime
    case "swift", "kt", "java", "py", "js", "ts", "go", "rs", "cpp", "c", "h", "m", "mm":
        return Color(hex: "#38bdf8") // light blue
    default:
        // Deterministic hash-based colour for unrecognised extensions.
        // Uses the full name so identical extensions in different dirs get different colours.
        let hash = entry.name.hash
        let index = abs(hash) % treemapPalette.count
        return treemapPalette[index]
    }
}
