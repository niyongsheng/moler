import SwiftUI

// MARK: - Solar System Monitor Overlay

struct SystemMonitorOverlay: View {
    @State private var scanAngle: Double = 0

    init() {}

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { context in
            SystemMonitorContent(date: context.date, scanAngle: scanAngle)
        }
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                scanAngle = 360
            }
        }
    }
}

// MARK: - Inner content

private struct PlanetDatum {
    let name: String
    let orbitRadius: CGFloat
    let period: TimeInterval
    let color: Color
    let size: CGFloat
    let isJupiter: Bool
}

private let allPlanets: [PlanetDatum] = [
    PlanetDatum(name: "MERC", orbitRadius: 0.14, period: 3,   color: Color(white: 0.65),       size: 3,  isJupiter: false),
    PlanetDatum(name: "VEN",  orbitRadius: 0.21, period: 6,   color: Color(red: 0.9, green: 0.75, blue: 0.4), size: 3.5, isJupiter: false),
    PlanetDatum(name: "TER",  orbitRadius: 0.28, period: 10,  color: Color(red: 0.35, green: 0.7, blue: 0.75), size: 4,  isJupiter: false),
    PlanetDatum(name: "MARS", orbitRadius: 0.35, period: 18,  color: Color(red: 0.8, green: 0.35, blue: 0.25), size: 3,  isJupiter: false),
    PlanetDatum(name: "JUP",  orbitRadius: 0.43, period: 30,  color: Brand.accentOrange, size: 5.5, isJupiter: true),
    PlanetDatum(name: "SAT",  orbitRadius: 0.51, period: 50,  color: Brand.accentGold,    size: 4.5, isJupiter: false),
    PlanetDatum(name: "URA",  orbitRadius: 0.58, period: 80,  color: Color(red: 0.5, green: 0.75, blue: 0.8), size: 4,  isJupiter: false),
    PlanetDatum(name: "NEP",  orbitRadius: 0.65, period: 120, color: Color(red: 0.25, green: 0.4, blue: 0.8),  size: 4,  isJupiter: false),
]

struct SystemMonitorContent: View {
    let date: Date
    let scanAngle: Double

    var body: some View {
        let elapsed = date.timeIntervalSinceReferenceDate

        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.75
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let half = size / 2

            ZStack {
                // Outer ring
                Circle()
                    .stroke(Brand.lineColor.opacity(0.5), lineWidth: 1)
                    .shadow(color: Brand.lineColor.opacity(0.2), radius: 8)
                    .frame(width: size, height: size)

                // Orbital rings (dashed)
                ForEach(0..<allPlanets.count, id: \.self) { i in
                    let p = allPlanets[i]
                    Circle()
                        .stroke(
                            p.isJupiter ? Brand.accentOrange.opacity(0.6) : Brand.lineColor.opacity(0.18),
                            style: StrokeStyle(
                                lineWidth: p.isJupiter ? 1.5 : 0.5,
                                dash: p.isJupiter ? [6, 4] : [3, 8]
                            )
                        )
                        .frame(width: half * p.orbitRadius * 2, height: half * p.orbitRadius * 2)
                }

                // Tick marks (16)
                ForEach(0..<16) { i in
                    let isMain = i % 4 == 0
                    Rectangle()
                        .fill(isMain ? Brand.lineColor.opacity(0.6) : Brand.lineColor.opacity(0.25))
                        .frame(width: 1, height: isMain ? 12 : 6)
                        .offset(y: -(half + 5))
                        .rotationEffect(.degrees(Double(i) * 22.5))
                }

                // Sun marker
                ZStack {
                    Circle().fill(Brand.accentOrange.opacity(0.12)).frame(width: 28, height: 28).blur(radius: 8)
                    Circle().fill(Brand.accentOrange.opacity(0.35)).frame(width: 18, height: 18).blur(radius: 4)
                    Circle().fill(Brand.accentOrange).frame(width: 9, height: 9)
                        .shadow(color: Brand.accentOrange.opacity(0.8), radius: 6)
                }

                // Orbiting planets
                ForEach(0..<allPlanets.count, id: \.self) { i in
                    let p = allPlanets[i]
                    let angle = elapsed / p.period * 360
                    let rad = angle * .pi / 180
                    let px = cos(rad) * half * p.orbitRadius
                    let py = sin(rad) * half * p.orbitRadius

                    if p.isJupiter {
                        Circle()
                            .stroke(p.color.opacity(0.6), lineWidth: 2)
                            .frame(width: p.size + 12, height: p.size + 12)
                            .shadow(color: p.color.opacity(0.6), radius: 6)
                            .position(x: center.x + px, y: center.y + py)
                    }

                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .shadow(color: p.color.opacity(0.9), radius: p.isJupiter ? 5 : 3)
                        .position(x: center.x + px, y: center.y + py)
                }

                // Scanner trail
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .clear, Brand.accentBlue.opacity(0.22), Brand.accentBlue.opacity(0.10),
                                .clear, .clear, .clear, .clear, .clear,
                            ]),
                            center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)
                        )
                    )
                    .frame(width: size, height: size)
                    .mask {
                        Circle()
                            .strokeBorder(lineWidth: half * 0.55)
                            .frame(width: size, height: size)
                    }
                    .rotationEffect(.degrees(scanAngle))

                // Scanner beam
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Brand.accentBlue.opacity(0.9), location: 0.85),
                                .init(color: Brand.accentBlue, location: 1),
                            ]),
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: half, height: 2)
                    .shadow(color: Brand.accentBlue.opacity(0.7), radius: 8)
                    .shadow(color: Brand.accentBlue.opacity(0.35), radius: 16)
                    .offset(x: half * 0.5)
                    .rotationEffect(.degrees(scanAngle))

                // Counter-beam
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Brand.accentBlue.opacity(0.35), location: 1),
                            ]),
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: half * 0.35, height: 0.5)
                    .offset(x: -half * 0.82)
                    .rotationEffect(.degrees(scanAngle + 180))

                // Corner reticle
                Reticle(strokeColor: Brand.accentBlue.opacity(0.5), lineWidth: 1, armLength: 12)
                    .frame(width: size + 24, height: size + 24)

                // Label
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("SOL SYSTEM // OPTIMIZE")
                            .font(.custom(Brand.monoFont, size: 10))
                            .foregroundColor(Brand.textDim.opacity(0.5))
                            .tracking(2.5)
                            .padding(.trailing, 24)
                            .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }
}
