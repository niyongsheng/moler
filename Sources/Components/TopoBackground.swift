import SwiftUI

/// NASA-Punk topographic contour background — ported from the Observatory's
/// `topoRenderer.js`. Draws animated contour lines, a subtle grid, and stars
/// using SwiftUI Canvas with a simplified noise field.
struct TopoBackground: View {
    var bgColor: Color = Brand.bgNavy
    var lineOpacity: Double = 0.4
    var lineColor: Color = Color(hex: "#3b4e6b")

    private let gridSize: Double = 10
    private let levels: Int = 6

    @State private var t: Double = 0
    private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            drawContent(ctx: &ctx, size: size, time: t)
        }
        .allowsHitTesting(false)
        .onReceive(timer) { _ in
            t += 1.0 / 30
        }
    }

    private func drawContent(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bgColor))
        drawGrid(ctx: &ctx, size: size)
        drawStars(ctx: &ctx, size: size, time: time)
        drawContours(ctx: &ctx, size: size, time: time)
    }

    // MARK: - Grid

    private func drawGrid(ctx: inout GraphicsContext, size: CGSize) {
        let step: Double = 120
        let lineStyle = StrokeStyle(lineWidth: 1)

        var path = Path()
        for x in stride(from: 0, through: size.width, by: step) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: 0, through: size.height, by: step) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.opacity = 0.05
        ctx.stroke(path, with: .color(lineColor), style: lineStyle)

        // Cross marks
        ctx.opacity = 0.12
        let crossSize: Double = 3
        var crossPath = Path()
        for x in stride(from: 0, through: size.width, by: step) {
            for y in stride(from: 0, through: size.height, by: step) {
                crossPath.move(to: CGPoint(x: x - crossSize, y: y))
                crossPath.addLine(to: CGPoint(x: x + crossSize, y: y))
                crossPath.move(to: CGPoint(x: x, y: y - crossSize))
                crossPath.addLine(to: CGPoint(x: x, y: y + crossSize))
            }
        }
        ctx.stroke(crossPath, with: .color(lineColor), style: lineStyle)
    }

    // MARK: - Stars

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        var rng = SeededRNG(seed: Int(size.width * 100 + size.height))

        for _ in 0..<150 {
            let x = rng.next() * size.width
            let y = rng.next() * size.height
            let starSize = rng.next() * 1.5 + 0.3
            let baseOpacity = rng.next() * 0.6 + 0.1
            let flicker = 0.85 + 0.15 * sin(time * 0.5 + x * 0.01 + y * 0.01)

            ctx.opacity = baseOpacity * flicker
            let star = Path(ellipseIn: CGRect(x: x, y: y, width: starSize, height: starSize))
            ctx.fill(star, with: .color(.white))
        }
    }

    // MARK: - Contour Lines

    private func drawContours(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let cols = Int(size.width / gridSize) + 1
        let rows = Int(size.height / gridSize) + 1
        let noiseOffset = 100.0 + time * 0.03 // very slow drift

        // Build noise field
        var field: [[Double]] = Array(repeating: Array(repeating: 0, count: rows), count: cols)
        for i in 0..<cols {
            for j in 0..<rows {
                let x = Double(i) * gridSize * 0.002 + noiseOffset
                let y = Double(j) * gridSize * 0.002 + noiseOffset
                field[i][j] = (fbm(x: x, y: y, octaves: 3) + 1) / 2
            }
        }

        let style = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
        let step = 1.0 / Double(levels)

        for level in stride(from: 0.2, to: 0.8, by: step) {
            var contour = Path()
            for i in 0..<(cols - 1) {
                for j in 0..<(rows - 1) {
                    let x = Double(i) * gridSize
                    let y = Double(j) * gridSize
                    let valTL = field[i][j]
                    let valTR = field[i + 1][j]
                    let valBR = field[i + 1][j + 1]
                    let valBL = field[i][j + 1]

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
            ctx.opacity = 0.5
            ctx.stroke(contour, with: .color(lineColor), style: style)
        }
    }
}

// MARK: - Helpers

private func noise2D(x: Double, y: Double) -> Double {
    let v = sin(x * 1.2 + y * 0.8) * cos(y * 1.3 + x * 0.7)
           + sin(x * 0.5 - y * 2.1) * 0.5
           + cos(x * 2.3 + y * 1.1) * 0.3
    return v / 1.8
}

private func fbm(x: Double, y: Double, octaves: Int) -> Double {
    var value = 0.0
    var amplitude = 1.0
    var frequency = 1.0
    var maxVal = 0.0
    for _ in 0..<octaves {
        value += amplitude * noise2D(x: x * frequency, y: y * frequency)
        maxVal += amplitude
        amplitude *= 0.5
        frequency *= 2.0
    }
    return value / maxVal
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
            lineColor: lineColor ?? Color(hex: "#3b4e6b")
        ))
    }
}

#Preview {
    TopoBackground()
        .frame(width: 900, height: 640)
}
