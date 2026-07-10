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
    enum Orientation: Equatable { case vertical, horizontal }

    var thickness: CGFloat = 2
    var pulseActive: Bool = true
    var orientation: Orientation = .vertical

    private let phaseOffsets: [Double] = [0, 0.25, 0.5, 0.75]
    private let colors: [Color] = [Brand.accentRed, Brand.accentOrange, Brand.accentGold, Brand.accentBlue]

    var body: some View {
        if pulseActive { animatedBody } else { staticBody }
    }

    @ViewBuilder
    private var animatedBody: some View {
        GeometryReader { geo in
            if orientation == .vertical {
                verticalAnimatedBody(geo: geo)
            } else {
                horizontalAnimatedBody(geo: geo)
            }
        }
        .frame(width: orientation == .vertical ? thickness : nil)
        .frame(height: orientation == .horizontal ? thickness : nil)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func verticalAnimatedBody(geo: GeometryProxy) -> some View {
        let h = geo.size.height
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in colors[i] }
            }
            .frame(width: thickness, height: h)
            MovingLight(totalLength: h, stripeLength: h / 4, thickness: thickness, direction: .vertical)
        }
        .frame(width: thickness, height: h)
    }

    @ViewBuilder
    private func horizontalAnimatedBody(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in colors[i] }
            }
            .frame(width: w, height: thickness)
            MovingLight(totalLength: w, stripeLength: w / 4, thickness: thickness, direction: .horizontal)
        }
        .frame(width: w, height: thickness)
    }

    /// A glowing comet that flows through the stripes.
    /// The leading light adopts the color of the stripe it's passing through,
    /// with a fading tail trailing behind.
    private struct MovingLight: View {
        let totalLength: CGFloat
        let stripeLength: CGFloat
        let thickness: CGFloat
        let direction: Direction
        @State private var pos: Double = 0
        private let timer = Timer.publish(every: 1.0/30, on: .main, in: .common).autoconnect()

        private let colors: [Color] = [Brand.accentRed, Brand.accentOrange, Brand.accentGold, Brand.accentBlue]
        private let tailLength: CGFloat = 280

        enum Direction { case vertical, horizontal }

        var body: some View {
            let cycle = pos.truncatingRemainder(dividingBy: 10) / 10
            if direction == .vertical { verticalBody(cycle: cycle) }
            else { horizontalBody(cycle: cycle) }
        }

        // MARK: - Vertical (bottom → top)

        private func verticalBody(cycle: Double) -> some View {
            // Bottom → top: y=0 at top, y=totalLength at bottom
            let lightPos = totalLength * (1 - cycle)
            let idx: Int = stripeLength > 0 ? min(3, max(0, Int(lightPos / stripeLength))) : 0
            let color = colors[idx]
            let flarePos = lightPos - 6
            return ZStack(alignment: .top) {
                sweepingTail(color: color, sizeW: thickness + 8, sizeH: tailLength, innerW: thickness + 2)
                    .offset(y: lightPos)
                innerTailGlow(color: color, sizeW: thickness + 2, offset: lightPos + tailLength * 0.15)
                outerAura(color: color, offset: flarePos - 12, axis: true)
                mediumGlow(color: color, offset: flarePos - 4, axis: true)
                innerGlow(color: color, offset: flarePos, axis: true)
                whiteCore(color: color, offset: flarePos + 2, axis: true)
                sparkleDots(color: color, baseOffset: lightPos, axis: true)
            }
            .onReceive(timer) { _ in pos += 1.0/30 }
        }

        // MARK: - Horizontal (left → right)

        private func horizontalBody(cycle: Double) -> some View {
            // Left → right: x=0 at left, x=totalLength at right
            let lightPos = totalLength * cycle
            // Fixed comet color — does not change when passing different stripe colors
            let tailColor = Brand.accentOrange
            let glowColor = Brand.accentOrange

            return ZStack(alignment: .leading) {
                // Layer 1 — Outer dust tail (widest, most blurry, farthest-reaching)
                taperedTail(color: tailColor, opacity: 0.12, lengthRatio: 1.0, heightMul: 3.5, blur: 10)
                    .offset(x: lightPos - tailLength)
                // Layer 2 — Mid dust tail
                taperedTail(color: tailColor, opacity: 0.20, lengthRatio: 0.75, heightMul: 2.5, blur: 7)
                    .offset(x: lightPos - tailLength * 0.75)
                // Layer 3 — Inner ion tail (narrower, sharper)
                taperedTail(color: tailColor, opacity: 0.35, lengthRatio: 0.55, heightMul: 1.5, blur: 4)
                    .offset(x: lightPos - tailLength * 0.55)
                // Layer 4 — Bright core tail
                taperedTail(color: tailColor, opacity: 0.60, lengthRatio: 0.30, heightMul: 1.0, blur: 1.5)
                    .offset(x: lightPos - tailLength * 0.30)

                // Scattered particles along the tail
                particleTrail(color: tailColor, lightPos: lightPos)

                // Head glow — outer aura (horizontal capsule sweeps wider than circle)
                Capsule()
                    .fill(glowColor.opacity(0.15))
                    .frame(width: 60, height: thickness * 5)
                    .blur(radius: 12)
                    .offset(x: lightPos - 30)
                // Head glow — medium
                Circle()
                    .fill(glowColor.opacity(0.35))
                    .frame(width: 28, height: 28)
                    .blur(radius: 8)
                    .offset(x: lightPos, y: 0)
                // Head glow — inner
                Circle()
                    .fill(glowColor)
                    .frame(width: 12, height: 12)
                    .blur(radius: 4)
                    .offset(x: lightPos, y: 0)
                // White core — teardrop shape (bulb forward, point trailing)
                CometHead()
                    .fill(.white)
                    .frame(width: 22, height: 6)
                    .shadow(color: glowColor, radius: 12)
                    .shadow(color: .white, radius: 6)
                    .offset(x: lightPos - 4, y: 0)
            }
            .onReceive(timer) { _ in pos += 1.0/30 }
        }

        /// A single tapered tail segment — Capsule with blur creates a soft conical glow.
        private func taperedTail(color: Color, opacity: Double, lengthRatio: CGFloat, heightMul: CGFloat, blur: CGFloat) -> some View {
            Capsule()
                .fill(color.opacity(opacity))
                .frame(width: tailLength * lengthRatio, height: thickness * heightMul)
                .blur(radius: blur)
        }

        /// Small scattered particles trailing the comet head, mimicking a dust trail.
        private func particleTrail(color: Color, lightPos: CGFloat) -> some View {
            ForEach(0..<6, id: \.self) { i in
                let t = 0.12 + CGFloat(i) * 0.12
                let dist = tailLength * t
                let opacity = max(0.02, 0.22 - Double(i) * 0.03)
                let size: CGFloat = max(1.5, 3 - CGFloat(i) * 0.3)
                let yOff: CGFloat = (i.isMultiple(of: 2) ? 1 : -1) * CGFloat(i % 3 + 1) * 1.5
                if opacity > 0.02 || i == 0 {
                    Circle()
                        .fill(color.opacity(opacity))
                        .frame(width: size, height: size)
                        .blur(radius: 0.5)
                        .offset(x: lightPos - dist, y: yOff)
                }
            }
        }

        /// Teardrop-shaped comet head — bulb faces forward (right), point trails left.
        private struct CometHead: Shape {
            func path(in rect: CGRect) -> Path {
                Path { path in
                    let midY = rect.midY
                    let r = rect.height / 2
                    let rightX = rect.maxX
                    let leftX = rect.minX

                    // Bulb: semicircle on the right (direction of travel)
                    path.addArc(
                        center: CGPoint(x: rightX - r, y: midY),
                        radius: r,
                        startAngle: Angle(radians: -.pi / 2),
                        endAngle: Angle(radians: .pi / 2),
                        clockwise: false
                    )

                    // Taper to a point on the left (trailing side)
                    path.addLine(to: CGPoint(x: leftX, y: midY))
                    path.closeSubpath()
                }
            }
        }

        // MARK: - Shared rendering helpers

        private func sweepingTail(color: Color, sizeW: CGFloat, sizeH: CGFloat, innerW: CGFloat, horizontal: Bool = false) -> some View {
            Group {
                LinearGradient(
                    colors: [color.opacity(0.7), color.opacity(0.35), color.opacity(0.12), color.opacity(0.03), color.opacity(0)],
                    startPoint: horizontal ? .trailing : .top,
                    endPoint: horizontal ? .leading : .bottom
                )
                .frame(width: sizeW, height: sizeH)
                .blur(radius: 5)
                .opacity(0.9)
            }
        }

        private func innerTailGlow(color: Color, sizeW: CGFloat, offset: CGFloat, horizontal: Bool = false) -> some View {
            LinearGradient(
                colors: [color.opacity(0.5), color.opacity(0.15), color.opacity(0)],
                startPoint: horizontal ? .trailing : .top,
                endPoint: horizontal ? .leading : .bottom
            )
            .frame(width: horizontal ? tailLength * 0.7 : sizeW, height: horizontal ? sizeW : tailLength * 0.7)
            .blur(radius: 3)
        }

        private func outerAura(color: Color, offset: CGFloat, axis: Bool) -> some View {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 36, height: 36)
                .blur(radius: 12)
                .offset(x: axis ? 0 : offset, y: axis ? offset : 0)
        }

        private func mediumGlow(color: Color, offset: CGFloat, axis: Bool) -> some View {
            Circle()
                .fill(color.opacity(0.5))
                .frame(width: 20, height: 20)
                .blur(radius: 7)
                .offset(x: axis ? 0 : offset, y: axis ? offset : 0)
        }

        private func innerGlow(color: Color, offset: CGFloat, axis: Bool) -> some View {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .blur(radius: 4)
                .offset(x: axis ? 0 : offset, y: axis ? offset : 0)
        }

        private func whiteCore(color: Color, offset: CGFloat, axis: Bool) -> some View {
            Circle()
                .fill(.white)
                .frame(width: 4, height: 4)
                .shadow(color: color, radius: 12)
                .shadow(color: .white, radius: 6)
                .offset(x: axis ? 0 : offset, y: axis ? offset : 0)
        }

        private func sparkleDots(color: Color, baseOffset: CGFloat, axis: Bool) -> some View {
            ForEach(0..<3, id: \.self) { i in
                let d: CGFloat = 50 + CGFloat(i) * 40
                Circle()
                    .fill(color.opacity(0.3 - Double(i) * 0.08))
                    .frame(width: CGFloat(3 - i), height: CGFloat(3 - i))
                    .blur(radius: CGFloat(i))
                    .offset(x: axis ? 0 : (baseOffset - d), y: axis ? (baseOffset + d) : 0)
            }
        }
    }

    @ViewBuilder
    private var staticBody: some View {
        GeometryReader { geo in
            if orientation == .vertical {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in colors[i] }
                }
                .frame(width: thickness, height: geo.size.height)
            } else {
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in colors[i] }
                }
                .frame(width: geo.size.width, height: thickness)
            }
        }
        .frame(width: orientation == .vertical ? thickness : nil)
        .frame(height: orientation == .horizontal ? thickness : nil)
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
