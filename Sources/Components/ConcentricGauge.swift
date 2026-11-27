import SwiftUI

/// One value in a `ConcentricGauge`.
struct ConcentricGaugeRing: Identifiable {
    let id: String
    let label: String
    /// Normalised progress, 0...1.
    let value: Double
    let displayValue: String
    let color: Color
}

/// Concentric arc gauges, inspired by overlapping mission-telemetry rings.
/// The first ring is the outermost; each following ring nests inward.
struct ConcentricGauge: View {
    let rings: [ConcentricGaugeRing]
    var lineWidth: CGFloat = 10
    var ringGap: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack {
                ForEach(Array(rings.enumerated()), id: \.element.id) { index, ring in
                    ringView(ring, index: index, side: side)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func ringView(_ ring: ConcentricGaugeRing, index: Int, side: CGFloat) -> some View {
        let value = min(max(ring.value, 0), 1)
        let inset = lineWidth / 2 + CGFloat(index) * (lineWidth + ringGap)
        let diameter = max(0, side - inset * 2)

        ZStack {
            Circle()
                .stroke(Brand.lineColor.opacity(0.22), lineWidth: lineWidth)
                .frame(width: diameter, height: diameter)

            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    ring.color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: diameter, height: diameter)
                .shadow(color: ring.color.opacity(0.35), radius: 4)
                .animation(.easeOut(duration: 0.5), value: value)

            if value > 0.02 {
                // Dark arrowhead set into the arc near its leading edge, like
                // the directional ticks in a spacecraft telemetry dial.
                let angle = -Double.pi / 2 + 2 * Double.pi * value
                let radius = diameter / 2
                let arrowLength = max(5, lineWidth * 0.55)
                let markerAngle = angle - (arrowLength / 2) / radius
                let x = side / 2 + radius * CGFloat(cos(markerAngle))
                let y = side / 2 + radius * CGFloat(sin(markerAngle))

                GaugeArrowhead()
                    .fill(Brand.bgNavy)
                    .frame(width: arrowLength, height: lineWidth * 0.7)
                    .rotationEffect(.radians(markerAngle + .pi / 2))
                    .position(x: x, y: y)
            }
        }
        .frame(width: side, height: side)
    }
}

/// Right-pointing triangle used as a directional tick on a gauge arc.
private struct GaugeArrowhead: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    ConcentricGauge(rings: [
        ConcentricGaugeRing(id: "cpu", label: "CPU", value: 0.42, displayValue: "42%", color: Brand.accentOrange),
        ConcentricGaugeRing(id: "mem", label: "MEM", value: 0.82, displayValue: "82%", color: Brand.accentBlue),
        ConcentricGaugeRing(id: "disk", label: "DISK", value: 0.76, displayValue: "76%", color: Brand.accentGold),
    ])
    .frame(width: 128, height: 128)
    .padding(40)
    .background(Brand.bgElevated)
    .environment(\.colorScheme, .dark)
}
