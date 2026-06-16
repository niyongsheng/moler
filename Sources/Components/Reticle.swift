import SwiftUI

/// NASA-Punk target reticle — four corner brackets framing a rectangular area.
/// Inspired by spacecraft targeting HUDs. Purely decorative.
struct Reticle: View {
    var strokeColor: Color = Brand.accentOrange
    var lineWidth: CGFloat = 1
    var armLength: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            CornerBracketsPath(
                armLength: armLength,
                rect: CGRect(origin: .zero, size: geo.size)
            )
            .stroke(strokeColor, lineWidth: lineWidth)
        }
    }
}

/// The reticle path shape reused by ReticleCheck.
struct CornerBracketsPath: Shape {
    let armLength: CGFloat
    let rect: CGRect

    func path(in _: CGRect) -> Path {
        let r = rect
        let len = armLength
        var p = Path()

        // Top-left
        p.move(to: CGPoint(x: r.minX, y: r.minY + len))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + len, y: r.minY))

        // Top-right
        p.move(to: CGPoint(x: r.maxX - len, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + len))

        // Bottom-right
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - len))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - len, y: r.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: r.minX + len, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - len))

        return p
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Brand.bgNavy

        Reticle(strokeColor: Brand.accentOrange, lineWidth: 1, armLength: 8)
            .frame(width: 200, height: 120)
    }
    .frame(width: 300, height: 200)
    .environment(\.colorScheme, .dark)
}
