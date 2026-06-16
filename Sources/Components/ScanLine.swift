import SwiftUI

/// NASA-Punk orbital radar animation for the scanning phase.
/// Features a glowing sweep line, orbital rings with pulsing dots,
/// a glowing center core, and cardinal tick marks — inspired by the
/// Observatory's system-monitor radar and scanner-trail components.
struct ScanLine: View {
    @State private var rotation: Double = 0
    @State private var centerGlow: CGFloat = 1.0
    @State private var orbitRotation: Double = 0

    private let ringSizes: [CGFloat] = [30, 50, 75, 95]
    private let orbitSpeeds: [Double] = [4, 8, 15, 25]
    private let dotColors: [Color] = [Brand.accentGold, Brand.accentBlue, Brand.accentOrange, Brand.accentRed]

    var body: some View {
        ZStack {
            // Outer ring with glow
            Circle()
                .stroke(Brand.lineColor.opacity(0.5), lineWidth: 1)
                .shadow(color: Brand.lineColor.opacity(0.3), radius: 6)

            // Orbital rings (dashed)
            ForEach(0..<ringSizes.count, id: \.self) { i in
                Circle()
                    .stroke(Brand.lineColor.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [3, 6]))
                    .frame(width: ringSizes[i] * 2)
            }

            // Orbiting dots (like Observatory's planet-markers)
            ForEach(0..<ringSizes.count, id: \.self) { i in
                Circle()
                    .fill(dotColors[i])
                    .frame(width: i == 3 ? 5 : 3, height: i == 3 ? 5 : 3)
                    .shadow(color: dotColors[i].opacity(0.8), radius: 3)
                    .offset(y: -ringSizes[i])
                    .rotationEffect(.degrees(orbitRotation * orbitSpeeds[i]))
            }

            // Scanner sweep trail (conic gradient like observatory's scanner-trail)
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Brand.accentBlue.opacity(0.15),
                            Brand.accentBlue.opacity(0.08),
                            Color.clear,
                            Color.clear,
                            Color.clear,
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    )
                )
                .rotationEffect(.degrees(rotation))

            // Sweeping scan line
            Circle()
                .trim(from: 0, to: 0.06)
                .stroke(
                    Brand.accentOrange,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
                .shadow(color: Brand.accentOrange.opacity(0.6), radius: 6)
                .shadow(color: Brand.accentOrange.opacity(0.3), radius: 12)

            // Tick marks (cardinal + sub-cardinal)
            ForEach(0..<8) { i in
                let isMain = i % 2 == 0
                Rectangle()
                    .fill(isMain ? Brand.lineColor : Brand.lineColor.opacity(0.3))
                    .frame(width: 1, height: isMain ? 10 : 5)
                    .offset(y: -62)
                    .rotationEffect(.degrees(Double(i) * 45))
            }

            // Center glow core (pulsing)
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(Brand.accentOrange.opacity(0.3), lineWidth: 1)
                    .frame(width: 16, height: 16)
                    .scaleEffect(centerGlow)

                // Inner glow
                Circle()
                    .fill(Brand.accentOrange.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .blur(radius: 3)

                // Center dot
                Circle()
                    .fill(Brand.accentOrange)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: 130, height: 130)
        .onAppear {
            // Scan line sweep
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            // Orbital rotation
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                orbitRotation = 360
            }
            // Center pulsing
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                centerGlow = 1.3
            }
        }
    }
}

#Preview {
    ScanLine()
        .padding()
        .background(Brand.bgNavy)
        .environment(\.colorScheme, .dark)
}
