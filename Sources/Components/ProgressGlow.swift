import SwiftUI

/// An orange glowing progress bar for the running phase.
/// Thin, with a gradient glow that evokes a thruster charge meter.
struct ProgressGlow: View {
    let progress: Double // 0.0 ... 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Brand.lineColor.opacity(0.4))
                    .frame(height: 3)

                // Filled portion with glow
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Brand.accentOrange, Brand.accentGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * progress), height: 3)
                    .shadow(color: Brand.accentOrange.opacity(0.6), radius: 6, y: 0)
            }
        }
        .frame(height: 3)
    }
}

/// A subtle pulsing glow indicator — used while waiting/loading.
struct PulseGlow: View {
    @State private var opacity: Double = 0.3

    var body: some View {
        Circle()
            .fill(Brand.accentOrange)
            .frame(width: 6, height: 6)
            .shadow(color: Brand.accentOrange.opacity(0.8), radius: 4)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    opacity = 1.0
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressGlow(progress: 0.65)
            .frame(width: 300)
        PulseGlow()
    }
    .padding()
    .background(Brand.bgNavy)
    .environment(\.colorScheme, .dark)
}
