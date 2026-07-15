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

        private static let frameInterval: TimeInterval = 1.0 / 60
        @State private var pos: Double = 0
        private let timer = Timer.publish(every: Self.frameInterval, on: .main, in: .common).autoconnect()

        private let colors: [Color] = [Brand.accentRed, Brand.accentOrange, Brand.accentGold, Brand.accentBlue]
        private let tailLength: CGFloat = 360

        /// Pre-built shape + gradient — created once, not per frame.
        private let tailShape: TaperedTailShape
        private let tailGradient: LinearGradient

        init(totalLength: CGFloat, stripeLength: CGFloat, thickness: CGFloat, direction: Direction) {
            self.totalLength = totalLength
            self.stripeLength = stripeLength
            self.thickness = thickness
            self.direction = direction
            let c = Brand.accentOrange
            self.tailShape = TaperedTailShape(length: 360, headWidth: thickness * 1.5, tipWidth: 1)
            self.tailGradient = LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: c.opacity(0.55), location: 0),
                    .init(color: c.opacity(0.35), location: 0.2),
                    .init(color: c.opacity(0.18), location: 0.4),
                    .init(color: c.opacity(0.08), location: 0.6),
                    .init(color: c.opacity(0.03), location: 0.8),
                    .init(color: c.opacity(0), location: 1),
                ]),
                startPoint: .trailing,
                endPoint: .leading
            )
        }

        enum Direction { case vertical, horizontal }

        var body: some View {
            let cycle = pos.truncatingRemainder(dividingBy: 10) / 10
            Group {
                if direction == .vertical { verticalBody(cycle: cycle) }
                else { horizontalBody(cycle: cycle) }
            }
            .onReceive(timer) { _ in pos += Self.frameInterval }
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
        }

        // MARK: - Horizontal (left → right)

        private func horizontalBody(cycle: Double) -> some View {
            // Left → right: x=0 at left, x=totalLength at right
            let lightPos = totalLength * cycle
            // Fixed comet color — does not change when passing different stripe colors
            let tailColor = Brand.accentOrange
            let glowColor = Brand.accentOrange

            return ZStack(alignment: .leading) {
                // Continuous gradient tail — smooth trapezoid fade, no banding
                continuousTail(lightPos: lightPos)

                // Scattered particles along the tail
                particleTrail(color: tailColor, lightPos: lightPos)

                // Head glow — outer aura (horizontal capsule sweeps wider than circle)
                Capsule()
                    .fill(glowColor.opacity(0.15))
                    .frame(width: 48, height: thickness * 3)
                    .blur(radius: 10)
                    .offset(x: lightPos - 24)
                // Head glow — medium
                Circle()
                    .fill(glowColor.opacity(0.35))
                    .frame(width: 22, height: 22)
                    .blur(radius: 7)
                    .offset(x: lightPos, y: 0)
                // Head glow — inner
                Circle()
                    .fill(glowColor)
                    .frame(width: 10, height: 10)
                    .blur(radius: 3)
                    .offset(x: lightPos, y: 0)
                // White core — teardrop shape (bulb forward, point trailing)
                CometHead()
                    .fill(.white)
                    .frame(width: 22, height: 6)
                    .shadow(color: glowColor, radius: 12)
                    .shadow(color: .white, radius: 6)
                    .offset(x: lightPos - 4, y: 0)
            }
        }

        /// Continuous gradient tail — uses pre-built shape + gradient, only offset changes per frame.
        private func continuousTail(lightPos: CGFloat) -> some View {
            tailShape
                .fill(tailGradient)
                .frame(width: tailLength, height: thickness * 1.5)
                .offset(x: lightPos - tailLength + 22)
        }

        /// Bullet-shaped tail: rounded right cap, tapering to a thin point on the left.
        private struct TaperedTailShape: Shape {
            let length: CGFloat
            let headWidth: CGFloat
            let tipWidth: CGFloat

            func path(in rect: CGRect) -> Path {
                Path { path in
                    let m = rect.midY
                    let r = headWidth / 2
                    let tw = tipWidth / 2
                    let rx = rect.maxX
                    let lx = rect.minX

                    // Right side: semicircular cap (bulge to the right)
                    path.addArc(center: CGPoint(x: rx - r, y: m),
                               radius: r,
                               startAngle: Angle(radians: -.pi / 2),
                               endAngle: Angle(radians: .pi / 2),
                               clockwise: false)
                    // Bottom edge tapering to left tip
                    path.addLine(to: CGPoint(x: lx, y: m + tw))
                    // Left edge
                    path.addLine(to: CGPoint(x: lx, y: m - tw))
                    // Close back to arc start
                    path.closeSubpath()
                }
            }
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

        /// Teardrop-shaped comet head — delegates to TaperedTailShape with zero-width tip.
        private struct CometHead: Shape {
            func path(in rect: CGRect) -> Path {
                TaperedTailShape(length: rect.width, headWidth: rect.height, tipWidth: 0)
                    .path(in: rect)
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
    private static let frameInterval: TimeInterval = 1.0 / 60
    private let timer = Timer.publish(every: Self.frameInterval, on: .main, in: .common).autoconnect()

    private let colors: [Color] = [Brand.accentRed, Brand.accentOrange, Brand.accentGold, Brand.accentBlue]
    private let skewTan: CGFloat

    init(phaseOffsets: [Double], totalHeight: CGFloat, stripeWidth: CGFloat, aligned: Alignment, vertical: Bool, skew: Double) {
        self.phaseOffsets = phaseOffsets
        self.totalHeight = totalHeight
        self.stripeWidth = stripeWidth
        self.aligned = aligned
        self.vertical = vertical
        self.skew = skew
        self.skewTan = CGFloat(tan(skew * Double.pi / 180))
    }

    var body: some View {
        let s = skewTan
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
        .onReceive(timer) { _ in time += Self.frameInterval }
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
