import SwiftUI

// MARK: - Edge Serif (Overlay)

struct SerifBar: View {
    enum Edge { case leading, trailing, top, bottom }
    let edge: Edge
    var pulseActive: Bool = false

    private let colors: [Color] = [Brand.accentRed, Brand.accentOrange, Brand.accentGold, Brand.accentBlue]
    private let phaseOffsets: [Double] = [0, 0.25, 0.5, 0.75]

    var body: some View {
        GeometryReader { geo in
            if pulseActive, case .trailing = edge {
                AnimatedStripes(phaseOffsets: phaseOffsets, totalHeight: geo.size.height, stripeWidth: 16, aligned: .trailing, vertical: false, skew: -10)
            } else {
                staticStripes(geo: geo)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func staticStripes(geo: GeometryProxy) -> some View {
        switch edge {
        case .trailing, .leading:
            HStack(spacing: 0) {
                Spacer()
                ForEach(colors.indices, id: \.self) { i in
                    colors[i].frame(width: Brand.serifWidth).frame(maxHeight: geo.size.height / CGFloat(colors.count))
                }
            }
        case .top, .bottom:
            VStack(spacing: 0) {
                Spacer()
                ForEach(colors.indices, id: \.self) { i in
                    colors[i].frame(height: Brand.serifWidth).frame(maxWidth: geo.size.width / CGFloat(colors.count))
                }
            }
        }
    }
}

// MARK: - Vertical Divider

struct SerifDivider: View {
    var width: CGFloat = 2
    var pulseActive: Bool = true

    private let phaseOffsets: [Double] = [0, 0.25, 0.5, 0.75]
    private let colors: [Color] = [Brand.accentRed, Brand.accentOrange, Brand.accentGold, Brand.accentBlue]

    var body: some View {
        if pulseActive { animatedBody } else { staticBody }
    }

    @ViewBuilder
    private var animatedBody: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .top) {
                // Static colored stripes
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in colors[i] }
                }
                .frame(width: width, height: h)
                
                // Moving light point
                MovingLight(totalHeight: h, stripeWidth: width)
            }
            .frame(width: width, height: h)
        }
        .frame(width: width)
        .allowsHitTesting(false)
    }

    /// A glowing comet that flows from bottom to top through the stripes.
    /// The leading light adopts the color of the stripe it's passing through,
    /// with a fading tail trailing behind.
    private struct MovingLight: View {
        let totalHeight: CGFloat
        let stripeWidth: CGFloat
        @State private var pos: Double = 0
        private let timer = Timer.publish(every: 1.0/30, on: .main, in: .common).autoconnect()
        
        private let colors: [Color] = [Brand.accentRed, Brand.accentOrange, Brand.accentGold, Brand.accentBlue]
        private let tailLength: CGFloat = 280
        
        var body: some View {
            let cycle = pos.truncatingRemainder(dividingBy: 10) / 10
            // Bottom → top: y=0 at top, y=totalHeight at bottom
            let lightY = totalHeight * (1 - cycle)
            let stripeH = totalHeight / 4
            let idx: Int = stripeH > 0 ? min(3, max(0, Int(lightY / stripeH))) : 0
            let color = colors[idx]
            
            let flareY = lightY - 6
            return ZStack(alignment: .top) {
                // Long sweeping tail with soft glow
                LinearGradient(
                    colors: [color.opacity(0.7), color.opacity(0.35), color.opacity(0.12), color.opacity(0.03), color.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: stripeWidth + 8, height: tailLength)
                .blur(radius: 5)
                .offset(y: lightY)
                .opacity(0.9)
                
                // Tail inner glow (brighter core of the tail)
                LinearGradient(
                    colors: [color.opacity(0.5), color.opacity(0.15), color.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: stripeWidth + 2, height: tailLength * 0.7)
                .blur(radius: 3)
                .offset(y: lightY + tailLength * 0.15)
                
                // Outer aura
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 36, height: 36)
                    .blur(radius: 12)
                    .offset(y: flareY - 12)
                
                // Medium glow
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .blur(radius: 7)
                    .offset(y: flareY - 4)
                
                // Inner glow
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .blur(radius: 4)
                    .offset(y: flareY)
                
                // Bright white core
                Circle()
                    .fill(.white)
                    .frame(width: 4, height: 4)
                    .shadow(color: color, radius: 12)
                    .shadow(color: .white, radius: 6)
                    .offset(y: flareY + 2)
                
                // Trailing sparkle dots
                ForEach(0..<3, id: \.self) { i in
                    let d: CGFloat = 50 + CGFloat(i) * 40
                    Circle()
                        .fill(color.opacity(0.3 - Double(i) * 0.08))
                        .frame(width: CGFloat(3 - i), height: CGFloat(3 - i))
                        .blur(radius: CGFloat(i))
                        .offset(y: lightY + d)
                }
            }
            .onReceive(timer) { _ in pos += 1.0/30 }
        }
    }

    @ViewBuilder
    private var staticBody: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in colors[i] }
            }
            .frame(width: width, height: geo.size.height)
        }
        .frame(width: width)
        .allowsHitTesting(false)
    }
}

// MARK: - Animated Stripes (Shared)

private struct AnimatedStripes: View {
    let phaseOffsets: [Double]
    let totalHeight: CGFloat
    let stripeWidth: CGFloat
    enum Alignment { case leading, center, trailing }
    let aligned: Alignment
    let vertical: Bool
    let skew: Double

    @State private var time: Double = 0
    private let timer = Timer.publish(every: 1.0/30, on: .main, in: .common).autoconnect()

    private let colors: [Color] = [Brand.accentRed, Brand.accentOrange, Brand.accentGold, Brand.accentBlue]

    var body: some View {
        let s = CGFloat(tan(skew * Double.pi / 180))
        Group {
            if vertical {
                VStack(spacing: 0) {
                    ForEach(0..<phaseOffsets.count, id: \.self) { i in stripe(at: i) }
                }
                .transformEffect(CGAffineTransform(a: 1, b: s, c: 0, d: 1, tx: 0, ty: 0))
            } else {
                HStack(spacing: 0) {
                    if aligned == .leading { Spacer() }
                    if aligned == .center { EmptyView() }
                    if aligned == .trailing { Spacer() }
                    ForEach(0..<phaseOffsets.count, id: \.self) { i in stripe(at: i) }
                    if aligned == .leading { Spacer() }
                }
                .transformEffect(CGAffineTransform(a: 1, b: 0, c: s, d: 1, tx: 0, ty: 0))
            }
        }
        .allowsHitTesting(false)
        .onReceive(timer) { _ in time += 1.0/30 }
    }

    private func stripe(at index: Int) -> some View {
        let h = totalHeight / CGFloat(phaseOffsets.count)
        let cycle = time.truncatingRemainder(dividingBy: 6) / 6
        let pos = (cycle + phaseOffsets[index]).truncatingRemainder(dividingBy: 1)
        let intensity = (cos(pos * 2 * Double.pi - Double.pi) + 1) * 0.5

        return colors[index]
            .frame(width: stripeWidth, height: h)
            .background(
                colors[index]
                    .opacity(intensity * 0.5)
                    .blur(radius: 10)
                    .padding(-12)
            )
    }
}

// MARK: - Convenience Modifier

struct SerifBarModifier: ViewModifier {
    let edge: SerifBar.Edge
    let pulseActive: Bool
    func body(content: Content) -> some View {
        content.overlay(SerifBar(edge: edge, pulseActive: pulseActive))
    }
}

extension View {
    func serif(_ edge: SerifBar.Edge = .trailing, pulseActive: Bool = false) -> some View {
        modifier(SerifBarModifier(edge: edge, pulseActive: pulseActive))
    }
}
