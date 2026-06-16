import SwiftUI

/// NASA-Punk design token system.
/// Centralizes colors, fonts, and metrics used throughout the app.
enum Brand {

    // MARK: - Background Colors

    /// Deep space navy — primary background (#0e141f)
    static let bgNavy       = Color(hex: "#0e141f")
    /// Slightly lighter card/panel background (#141c2b)
    static let bgCard       = Color(hex: "#141c2b")
    /// Elevated surface (#1a2333)
    static let bgElevated   = Color(hex: "#1a2333")

    // MARK: - Accent Colors

    /// Hot orange — primary accent, active elements (#e06236)
    static let accentOrange = Color(hex: "#e06236")
    /// Gold/yellow — secondary highlight, sub-text (#d7ab61)
    static let accentGold   = Color(hex: "#d7ab61")
    /// Alert red — danger, warnings (#c82337)
    static let accentRed    = Color(hex: "#c82337")
    /// Steel blue — calm, informational (#2f4c79)
    static let accentBlue   = Color(hex: "#2f4c79")

    // MARK: - Line & Text Colors

    /// Muted line/divider color (#3b4e6b)
    static let lineColor    = Color(hex: "#3b4e6b")
    /// Primary text — off-white (#e8e8e8)
    static let textPrimary  = Color(hex: "#e8e8e8")
    /// Dim secondary text (#6d7d8c)
    static let textDim      = Color(hex: "#6d7d8c")

    // MARK: - Font Families

    /// Title / heading font (Jura, Bold weight)
    static let titleFont = "Jura-Bold"
    /// Body font (Jura, Medium weight)
    static let bodyFont  = "Jura-Medium"
    /// Light body font (Jura)
    static let lightFont = "Jura-Light"
    /// Monospace data font (Roboto Mono, Regular weight)
    static let monoFont  = "RobotoMono-Regular"
    /// Monospace light font
    static let monoLight = "RobotoMono-Light"

    // MARK: - Spacing

    /// Base spacing unit: 4pt
    static let unit: CGFloat = 4
    /// Standard margin: 16pt
    static let margin: CGFloat = 16
    /// Tight margin: 8pt
    static let marginTight: CGFloat = 8

    /// Serif bar width
    static let serifWidth: CGFloat = 4
}

// MARK: - Color Hex Extension

extension Color {
    /// Initialize a Color from a hex string like "#0e141f" or "0e141f".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Font View Extension

extension View {
    /// Apply Jura Bold title font.
    func titleFont(_ size: CGFloat = 18) -> some View {
        self.font(.custom(Brand.titleFont, size: size))
    }

    /// Apply Jura Medium body font.
    func bodyFont(_ size: CGFloat = 14) -> some View {
        self.font(.custom(Brand.bodyFont, size: size))
    }

    /// Apply Roboto Mono data font.
    func monoFont(_ size: CGFloat = 11) -> some View {
        self.font(.custom(Brand.monoFont, size: size))
    }
}
