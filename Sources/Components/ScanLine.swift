import SwiftUI

/// A rotating radar-style scan line effect for the scanning phase.
/// Orange radial gradient that sweeps a circle — evokes a radar dish.
struct ScanLine: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Brand.lineColor, lineWidth: 1)

            // Tick marks (simplified — 4 cardinal ticks)
            ForEach(0..<4) { i in
                Rectangle()
                    .fill(Brand.lineColor)
                    .frame(width: 1, height: 8)
                    .offset(y: -60)
                    .rotationEffect(.degrees(Double(i) * 90))
            }

            // Sweeping scan line
            Circle()
                .trim(from: 0, to: 0.08)
                .stroke(Brand.accentOrange, lineWidth: 1.5)
                .rotationEffect(.degrees(rotation))
                .shadow(color: Brand.accentOrange.opacity(0.5), radius: 4)

            // Center dot
            Circle()
                .fill(Brand.accentOrange)
                .frame(width: 4, height: 4)
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                rotation = 360
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
