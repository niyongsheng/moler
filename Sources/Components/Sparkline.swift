import SwiftUI

/// A tiny area sparkline for live metrics (network, CPU, etc.).
/// Pure Path rendering — no labels, no axes, just the recent curve.
struct Sparkline: View {
    let values: [Double]
    var color: Color = Brand.accentOrange
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            if values.count >= 2, w > 0, h > 0 {
                chart(w: w, h: h)
            } else {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h > 0 ? h - 1 : 0))
                    p.addLine(to: CGPoint(x: max(w, 1), y: h > 0 ? h - 1 : 0))
                }
                .stroke(color.opacity(0.2), lineWidth: 1)
            }
        }
    }

    private func chart(w: CGFloat, h: CGFloat) -> some View {
        let lo = min(values.min() ?? 0, 0)
        let hi = max(values.max() ?? 1, lo + 0.001)
        let denom = hi - lo
        let pts: [CGPoint] = values.enumerated().map { i, v in
            CGPoint(x: w * CGFloat(i) / CGFloat(values.count - 1),
                    y: (1.0 - CGFloat((v - lo) / denom)) * h)
        }

        return ZStack(alignment: .topLeading) {
            Path { p in
                guard let f = pts.first, let l = pts.last else { return }
                p.move(to: CGPoint(x: f.x, y: h))
                p.addLine(to: f)
                for pt in pts.dropFirst() { p.addLine(to: pt) }
                p.addLine(to: CGPoint(x: l.x, y: h))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [color.opacity(0.25), color.opacity(0.02)],
                                 startPoint: .top, endPoint: .bottom))

            Path { p in
                guard let f = pts.first else { return }
                p.move(to: f)
                for pt in pts.dropFirst() { p.addLine(to: pt) }
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}
