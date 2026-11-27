import SwiftUI
import AppKit

/// NASA-Punk topographic contour background — ported from the Observatory's
/// `topoRenderer.js`. Draws contour lines, a subtle grid, and stars using
/// SwiftUI Canvas with a simplified noise field.
///
/// Energy notes: the contour field only drifts — it is a pure translation.
/// Instead of re-rendering the Canvas every frame, one oversized frame is
/// rendered at a time and Core Animation translates it on the GPU. The image is
/// refreshed once per drift cycle; the static grid/star layer is drawn once.
/// When the window is closed, minimized, or occluded, all animated layers are
/// removed so menu-bar mode costs nothing.
struct TopoBackground: NSViewRepresentable {
    var bgColor: Color = Brand.bgNavy
    var lineOpacity: Double = 0.4
    var lineColor: Color = Brand.lineColor

    func makeNSView(context: Context) -> PassthroughHostingView<TopoAnimatedView> {
        let view = PassthroughHostingView(rootView: TopoAnimatedView(
            bgColor: bgColor,
            lineColor: lineColor,
            lineOpacity: lineOpacity
        ))
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: PassthroughHostingView<TopoAnimatedView>, context: Context) {
        nsView.rootView = TopoAnimatedView(
            bgColor: bgColor,
            lineColor: lineColor,
            lineOpacity: lineOpacity
        )
    }
}

/// Background host that never intercepts mouse events, so clicks reach the
/// SwiftUI content layered above it.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// The animated background itself.
struct TopoAnimatedView: View {
    let bgColor: Color
    let lineColor: Color
    let lineOpacity: Double

    @ObservedObject private var activity = AppActivityMonitor.shared

    // Separate renderers: each Canvas has a different size and must not share
    // mutable caches.
    @State private var staticRenderer = TopoRenderer()
    @State private var contourRenderer = TopoRenderer()
    @State private var twinkleRenderer = TopoRenderer()

    @State private var phase: Double = 0
    @State private var offset: CGFloat = 0

    /// Screen-space drift of the contour pattern: 0.03 noise units/s ÷ 0.002
    /// units/px = 15 px/s, diagonally. A 240 pt overscan gives a 16 s cycle.
    private static let driftSpeed: CGFloat = 15
    private static let margin: CGFloat = 240
    private static let cycle: TimeInterval = TimeInterval(margin / driftSpeed)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Static layer: background fill, grid, cross marks, and stars.
                Canvas(rendersAsynchronously: true) { ctx, size in
                    staticRenderer.drawStaticLayer(
                        &ctx, size: size, bgColor: bgColor, lineColor: lineColor
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height)

                if activity.isWindowVisible {
                    // Contours: one oversized render per cycle, then a GPU
                    // translation that costs no SwiftUI work per frame.
                    Canvas(rendersAsynchronously: true) { ctx, size in
                        contourRenderer.drawContourLayer(
                            &ctx, size: size, time: phase,
                            lineColor: lineColor, lineOpacity: lineOpacity
                        )
                    }
                    .frame(
                        width: geo.size.width + Self.margin,
                        height: geo.size.height + Self.margin
                    )
                    .offset(x: offset, y: offset)

                    // Extra star layer. Kept static: a second animated layer
                    // costs more than it adds visually.
                    Canvas(rendersAsynchronously: true) { ctx, size in
                        twinkleRenderer.drawTwinkleLayer(&ctx, size: size)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.65)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .task(id: activity.isWindowVisible) {
                await driftLoop()
            }
        }
        .allowsHitTesting(false)
    }

    /// Advance the noise phase and restart the GPU translation in lockstep.
    /// At the swap point the new frame's content matches the old frame's
    /// translated content, so the loop is seamless.
    @MainActor
    private func driftLoop() async {
        guard activity.isWindowVisible else { return }
        restartDrift()

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(Self.cycle * 1_000_000_000))
            guard !Task.isCancelled, activity.isWindowVisible else { return }
            phase += Self.cycle
            restartDrift()
        }
    }

    @MainActor
    private func restartDrift() {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { offset = 0 }

        // One finite sweep, not `repeatForever`: when the loop wraps, the
        // pattern would flash back to its start until the next phase update
        // arrives. Finite animations simply hold their end state.
        withAnimation(.linear(duration: Self.cycle)) {
            offset = -Self.margin
        }
    }
}

// MARK: - Renderer

/// Caches the static paths and reuses a flat noise buffer so each frame
/// allocates nothing.
private final class TopoRenderer {
    private let gridSize: Double = 10
    private let levels: Int = 6

    private var cachedSize: CGSize = .zero
    private var gridPath = Path()
    private var crossPath = Path()
    private var baseStarBuckets: [Path] = []
    private var twinkleBuckets: [Path] = []

    private var cols = 0
    private var rows = 0
    private var field: [Double] = []
    /// Pre-computed sin/cos per grid column/row (3 octaves × 8 values each).
    /// Keeps the per-frame trig count to ~(cols + rows) instead of per cell.
    private var xTrig: [[Double]] = Array(repeating: [], count: 3)
    private var yTrig: [[Double]] = Array(repeating: [], count: 3)

    private let baseStarOpacities: [Double] = [0.18, 0.30, 0.42]

    // MARK: Static

    func drawStaticLayer(_ ctx: inout GraphicsContext, size: CGSize, bgColor: Color, lineColor: Color) {
        if cachedSize != size { rebuild(size: size) }

        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bgColor))
        ctx.stroke(gridPath, with: .color(lineColor.opacity(0.05)), lineWidth: 1)
        ctx.stroke(crossPath, with: .color(lineColor.opacity(0.12)), lineWidth: 1)

        for (i, path) in baseStarBuckets.enumerated() {
            ctx.fill(path, with: .color(.white.opacity(baseStarOpacities[i])))
        }
    }

    private func rebuild(size: CGSize) {
        cachedSize = size

        // --- Grid lines ---
        let step: Double = 120
        var grid = Path()
        for x in stride(from: 0, through: size.width, by: step) {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: 0, through: size.height, by: step) {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        gridPath = grid

        // --- Cross marks ---
        let crossSize: Double = 3
        var crosses = Path()
        for x in stride(from: 0, through: size.width, by: step) {
            for y in stride(from: 0, through: size.height, by: step) {
                crosses.move(to: CGPoint(x: x - crossSize, y: y))
                crosses.addLine(to: CGPoint(x: x + crossSize, y: y))
                crosses.move(to: CGPoint(x: x, y: y - crossSize))
                crosses.addLine(to: CGPoint(x: x, y: y + crossSize))
            }
        }
        crossPath = crosses

        // --- Static stars, batched into three opacity buckets ---
        var rng = SeededRNG(seed: Int(size.width * 100 + size.height))
        var buckets = [Path](repeating: Path(), count: 3)
        for i in 0..<150 {
            let x = rng.next() * size.width
            let y = rng.next() * size.height
            let starSize = rng.next() * 1.5 + 0.3
            _ = rng.next() // keep the RNG sequence aligned with the original
            buckets[i % 3].addEllipse(in: CGRect(x: x, y: y, width: starSize, height: starSize))
        }
        baseStarBuckets = buckets

        // --- Twinkling stars, batched three ways with different phases ---
        var twinkleRNG = SeededRNG(seed: Int(size.width * 100 + size.height) &+ 7)
        var twinkles = [Path](repeating: Path(), count: 3)
        for i in 0..<54 {
            let x = twinkleRNG.next() * size.width
            let y = twinkleRNG.next() * size.height
            let starSize = twinkleRNG.next() * 1.2 + 0.4
            twinkles[i % 3].addEllipse(in: CGRect(x: x, y: y, width: starSize, height: starSize))
        }
        twinkleBuckets = twinkles

        cols = 0
        rows = 0
        field = []
    }

    // MARK: Animated

    func drawContourLayer(
        _ ctx: inout GraphicsContext,
        size: CGSize,
        time: Double,
        lineColor: Color,
        lineOpacity: Double
    ) {
        if cachedSize != size { rebuild(size: size) }
        drawContours(
            ctx: &ctx, size: size, time: time,
            lineColor: lineColor, lineOpacity: lineOpacity
        )
    }

    func drawTwinkleLayer(_ ctx: inout GraphicsContext, size: CGSize) {
        if cachedSize != size { rebuild(size: size) }

        for (i, path) in twinkleBuckets.enumerated() {
            ctx.fill(path, with: .color(.white.opacity(0.55 + Double(i) * 0.1)))
        }
    }

    private func drawContours(
        ctx: inout GraphicsContext,
        size: CGSize,
        time: Double,
        lineColor: Color,
        lineOpacity: Double
    ) {
        let neededCols = Int(size.width / gridSize) + 1
        let neededRows = Int(size.height / gridSize) + 1
        if neededCols != cols || neededRows != rows {
            cols = neededCols
            rows = neededRows
            field = [Double](repeating: 0, count: cols * rows)
        }

        let noiseOffset = 100.0 + time * 0.03 // very slow drift
        rebuildTrigTables(noiseOffset: noiseOffset)
        fillNoiseField()

        let style = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
        let step = 1.0 / Double(levels)

        for level in stride(from: 0.2, to: 0.8, by: step) {
            var contour = Path()
            for i in 0..<(cols - 1) {
                let base = i * rows
                let nextBase = (i + 1) * rows
                for j in 0..<(rows - 1) {
                    let x = Double(i) * gridSize
                    let y = Double(j) * gridSize
                    let valTL = field[base + j]
                    let valTR = field[nextBase + j]
                    let valBR = field[nextBase + j + 1]
                    let valBL = field[base + j + 1]

                    var state = 0
                    if valTL >= level { state |= 8 }
                    if valTR >= level { state |= 4 }
                    if valBR >= level { state |= 2 }
                    if valBL >= level { state |= 1 }

                    if state == 0 || state == 15 { continue }

                    let a = CGPoint(x: x + gridSize * iso(valTL, valTR, level), y: y)
                    let b = CGPoint(x: x + gridSize, y: y + gridSize * iso(valTR, valBR, level))
                    let c = CGPoint(x: x + gridSize * iso(valBL, valBR, level), y: y + gridSize)
                    let d = CGPoint(x: x, y: y + gridSize * iso(valTL, valBL, level))

                    switch state {
                    case 1:  contour.move(to: c); contour.addLine(to: d)
                    case 2:  contour.move(to: b); contour.addLine(to: c)
                    case 3:  contour.move(to: b); contour.addLine(to: d)
                    case 4:  contour.move(to: a); contour.addLine(to: b)
                    case 5:  contour.move(to: a); contour.addLine(to: d); contour.move(to: b); contour.addLine(to: c)
                    case 6:  contour.move(to: a); contour.addLine(to: c)
                    case 7:  contour.move(to: a); contour.addLine(to: d)
                    case 8:  contour.move(to: a); contour.addLine(to: d)
                    case 9:  contour.move(to: a); contour.addLine(to: c)
                    case 10: contour.move(to: a); contour.addLine(to: b); contour.move(to: c); contour.addLine(to: d)
                    case 11: contour.move(to: a); contour.addLine(to: b)
                    case 12: contour.move(to: b); contour.addLine(to: d)
                    case 13: contour.move(to: b); contour.addLine(to: c)
                    case 14: contour.move(to: c); contour.addLine(to: d)
                    default: break
                    }
                }
            }
            ctx.opacity = lineOpacity
            ctx.stroke(contour, with: .color(lineColor), style: style)
        }
        ctx.opacity = 1
    }

    // MARK: Noise field

    /// Pre-compute the sin/cos terms for each grid column and row.
    ///
    /// `noise2D` is a sum of `sin(a·x + b·y)` / `cos(a·x + b·y)` terms, which
    /// can be expanded into products of per-column and per-row trig values.
    /// That turns ~100k trig calls per frame into ~4k — the difference between
    /// a choppy 1 fps background and a smooth 15 fps one.
    private func rebuildTrigTables(noiseOffset: Double) {
        if xTrig[0].count != cols * 8 || yTrig[0].count != rows * 8 {
            for k in 0..<3 {
                xTrig[k] = [Double](repeating: 0, count: cols * 8)
                yTrig[k] = [Double](repeating: 0, count: rows * 8)
            }
        }

        // Argument multipliers from the original noise2D:
        // x: 1.2, 0.7, 0.5, 2.3   y: 0.8, 1.3, 2.1, 1.1
        for k in 0..<3 {
            let frequency = Double(1 << k) // 1, 2, 4
            var xa = xTrig[k]
            var ya = yTrig[k]

            for i in 0..<cols {
                let x = (Double(i) * gridSize * 0.002 + noiseOffset) * frequency
                let base = i * 8
                // sin/cos pairs for 1.2x, 0.7x, 0.5x, 2.3x
                xa[base]     = sin(1.2 * x)
                xa[base + 1] = cos(1.2 * x)
                xa[base + 2] = sin(0.7 * x)
                xa[base + 3] = cos(0.7 * x)
                xa[base + 4] = sin(0.5 * x)
                xa[base + 5] = cos(0.5 * x)
                xa[base + 6] = sin(2.3 * x)
                xa[base + 7] = cos(2.3 * x)
            }

            for j in 0..<rows {
                let y = (Double(j) * gridSize * 0.002 + noiseOffset) * frequency
                let base = j * 8
                // cos/sin pairs for 0.8y, 1.3y, 2.1y, 1.1y
                ya[base]     = cos(0.8 * y)
                ya[base + 1] = sin(0.8 * y)
                ya[base + 2] = cos(1.3 * y)
                ya[base + 3] = sin(1.3 * y)
                ya[base + 4] = cos(2.1 * y)
                ya[base + 5] = sin(2.1 * y)
                ya[base + 6] = cos(1.1 * y)
                ya[base + 7] = sin(1.1 * y)
            }

            xTrig[k] = xa
            yTrig[k] = ya
        }
    }

    private func fillNoiseField() {
        for idx in field.indices { field[idx] = 0 }

        var amplitude = 1.0
        var maxVal = 0.0

        for k in 0..<3 {
            let amp = amplitude
            let xa = xTrig[k]
            let ya = yTrig[k]

            for i in 0..<cols {
                let xb = i * 8
                let sx1 = xa[xb],     cx1 = xa[xb + 1]
                let sx2 = xa[xb + 2], cx2 = xa[xb + 3]
                let sx3 = xa[xb + 4], cx3 = xa[xb + 5]
                let sx4 = xa[xb + 6], cx4 = xa[xb + 7]
                let base = i * rows

                for j in 0..<rows {
                    let yb = j * 8
                    let cy1 = ya[yb],     sy1 = ya[yb + 1]
                    let cy2 = ya[yb + 2], sy2 = ya[yb + 3]
                    let cy3 = ya[yb + 4], sy3 = ya[yb + 5]
                    let cy4 = ya[yb + 6], sy4 = ya[yb + 7]

                    let term1 = (sx1 * cy1 + cx1 * sy1) * (cy2 * cx2 - sy2 * sx2)
                    let term2 = (sx3 * cy3 - cx3 * sy3) * 0.5
                    let term3 = (cx4 * cy4 - sx4 * sy4) * 0.3
                    field[base + j] += amp * ((term1 + term2 + term3) / 1.8)
                }
            }

            maxVal += amp
            amplitude *= 0.5
        }

        for idx in field.indices {
            field[idx] = (field[idx] / maxVal + 1) / 2
        }
    }
}

private func iso(_ v1: Double, _ v2: Double, _ level: Double) -> Double {
    if abs(v2 - v1) < 0.00001 { return 0.5 }
    return (level - v1) / (v2 - v1)
}

/// Deterministic pseudo-random number generator
private struct SeededRNG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(truncatingIfNeeded: seed)
        if state == 0 { state = 1 }
    }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state % 10000) / 10000.0
    }
}

// MARK: - Modifier

extension View {
    /// Add the NASA-Punk topographic contour background.
    func topoBackground(lineOpacity: Double = 0.4, lineColor: Color? = nil) -> some View {
        self.background(TopoBackground(
            lineOpacity: lineOpacity,
            lineColor: lineColor ?? Brand.lineColor
        ))
    }
}

#Preview {
    TopoBackground()
        .frame(width: 900, height: 640)
}
