import SwiftUI

/// NASA-Punk edge serif bars — the colored stripes along window edges
/// that evoke aerospace instrument bezels.
///
/// Usage: `.overlay(SerifBar(edge: .trailing))` on a full-frame view.
struct SerifBar: View {
    enum Edge {
        case leading, trailing, top, bottom
    }

    let edge: Edge

    /// Colors in NASA-Punk order: red, orange, yellow, blue.
    private let colors: [Color] = [
        Brand.accentRed,
        Brand.accentOrange,
        Brand.accentGold,
        Brand.accentBlue,
    ]

    var body: some View {
        GeometryReader { geo in
            switch edge {
            case .trailing, .leading:
                HStack(spacing: 0) {
                    Spacer()
                    ForEach(colors.indices, id: \.self) { i in
                        colors[i]
                            .frame(width: Brand.serifWidth)
                            .frame(maxHeight: geo.size.height / CGFloat(colors.count))
                    }
                }
            case .top, .bottom:
                VStack(spacing: 0) {
                    Spacer()
                    ForEach(colors.indices, id: \.self) { i in
                        colors[i]
                            .frame(height: Brand.serifWidth)
                            .frame(maxWidth: geo.size.width / CGFloat(colors.count))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Convenience Modifier

struct SerifBarModifier: ViewModifier {
    let edge: SerifBar.Edge

    func body(content: Content) -> some View {
        content.overlay(SerifBar(edge: edge))
    }
}

extension View {
    /// Add NASA-Punk serif color bars to an edge.
    func serif(_ edge: SerifBar.Edge = .trailing) -> some View {
        modifier(SerifBarModifier(edge: edge))
    }
}
