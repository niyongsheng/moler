import SwiftUI

/// A procedural starfield + grid background inspired by NASA-Punk Observatory's
/// topography canvas. Rendered in SwiftUI Canvas for performance.
struct StarfieldBackground: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                // 1. Deep navy fill
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(hex: "#0e141f")))

                // 2. Subtle grid lines
                let gridSpacing: CGFloat = 40
                let gridColor = Color(hex: "#3b4e6b").opacity(0.15)
                var gridPath = Path()
                for x in stride(from: 0, through: size.width, by: gridSpacing) {
                    gridPath.move(to: CGPoint(x: x, y: 0))
                    gridPath.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0, through: size.height, by: gridSpacing) {
                    gridPath.move(to: CGPoint(x: 0, y: y))
                    gridPath.addLine(to: CGPoint(x: size.width, y: y))
                }
                ctx.stroke(gridPath, with: .color(gridColor), lineWidth: 0.5)

                // 3. Scattered star points (deterministic from size)
                let starCount = Int(size.width * size.height / 800)
                var starPath = Path()
                for i in 0..<starCount {
                    // Simple hash-based position for deterministic scatter
                    let hx = Double((i * 2654435761) % 1_000_000) / 1_000_000.0
                    let hy = Double((i * 1597334677) % 1_000_000) / 1_000_000.0
                    let x = hx * size.width
                    let y = hy * size.height
                    starPath.addEllipse(in: CGRect(x: x, y: y, width: 1.2, height: 1.2))
                }
                // Flicker: a fraction of stars pulse
                let flickerCount = starCount / 20
                var flickerPath = Path()
                for i in 0..<flickerCount {
                    let hx = Double((i * 3655221443) % 1_000_000) / 1_000_000.0
                    let hy = Double((i * 2597334677) % 1_000_000) / 1_000_000.0
                    let x = hx * size.width
                    let y = hy * size.height
                    let r = 0.8 + 0.8 * sin(timeline.date.timeIntervalSince1970 * 3 + Double(i))
                    flickerPath.addEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                }

                ctx.fill(starPath,
                         with: .color(Color.white.opacity(0.35)))
                ctx.fill(flickerPath,
                         with: .color(Color.white.opacity(0.7)))

                // 4. Crosshair markers at corners (subtle version)
                let crossColor = Brand.accentBlue.opacity(0.2)
                let crossLen: CGFloat = 12
                let margin: CGFloat = 20
                let positions: [(CGFloat, CGFloat)] = [
                    (margin, margin),
                    (size.width - margin, margin),
                    (margin, size.height - margin),
                    (size.width - margin, size.height - margin),
                ]
                for (cx, cy) in positions {
                    var cross = Path()
                    cross.move(to: CGPoint(x: cx - crossLen, y: cy))
                    cross.addLine(to: CGPoint(x: cx + crossLen, y: cy))
                    cross.move(to: CGPoint(x: cx, y: cy - crossLen))
                    cross.addLine(to: CGPoint(x: cx, y: cy + crossLen))
                    ctx.stroke(cross, with: .color(crossColor), lineWidth: 0.5)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        StarfieldBackground()
        Text("STARFIELD PREVIEW")
            .foregroundColor(.white)
    }
    .frame(width: 800, height: 500)
}
