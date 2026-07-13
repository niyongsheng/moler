import SwiftUI

/// SwiftUI Canvas-based squarified treemap renderer.
/// Uses immediate-mode drawing for performance (not per-item SwiftUI views).
struct TreemapCanvasView: View {
    let entries: [DiskScanEntry]
    let onSelect: (DiskScanEntry) -> Void
    let onRevealInFinder: (DiskScanEntry) -> Void

    @State private var hoveredID: String?

    var body: some View {
        GeometryReader { geo in
            let cells = buildCells(in: geo.size)

            Canvas { context, size in
                for cell in cells {
                    drawCell(context: &context, cell: cell)
                }
                // Hover overlay
                if let hoveredID, let cell = cells.first(where: { $0.id == hoveredID }) {
                    drawHover(context: &context, cell: cell)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoveredID = cells.first(where: { $0.rect.contains(point) })?.id
                case .ended:
                    hoveredID = nil
                }
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let location = value.location
                        guard let cell = cells.first(where: { $0.rect.contains(location) }),
                              let entry = entries.first(where: { $0.id == cell.id }) else { return }
                        onSelect(entry)
                    }
            )
            .contextMenu {
                if let hoveredID, let entry = entries.first(where: { $0.id == hoveredID }) {
                    Button("Reveal in Finder") { onRevealInFinder(entry) }
                }
            }
        }
    }

    // MARK: - Cell Building

    private func buildCells(in size: CGSize) -> [TreemapCell] {
        guard !entries.isEmpty else { return [] }

        // Fold tail entries into "Other" to avoid visual noise from tiny cells
        let maxVisible = 80
        let (visible, otherSize) = TreemapLayout.foldOther(entries: entries, maxVisible: maxVisible)

        let totalSize = max(visible.map(\.size).reduce(0, +) + otherSize, 1)
        var weights = visible.map { Double($0.size) / Double(totalSize) * Double(size.width * size.height) }
        if otherSize > 0 {
            weights.append(Double(otherSize) / Double(totalSize) * Double(size.width * size.height))
        }

        let rects = TreemapLayout.layout(weights: weights, in: CGRect(origin: .zero, size: size))

        var cells: [TreemapCell] = []
        for (entry, rect) in zip(visible, rects) {
            let weight = Double(entry.size) / Double(totalSize)
            cells.append(TreemapCell(
                id: entry.id,
                name: entry.name,
                path: entry.path,
                size: entry.size,
                isDir: entry.isDir,
                weight: weight,
                rect: rect,
                color: treemapColor(for: entry)
            ))
        }
        if otherSize > 0, let otherRect = rects.last {
            cells.append(TreemapCell(
                id: "__other__",
                name: "Other (\(entries.count - visible.count) items)",
                path: "",
                size: otherSize,
                isDir: false,
                weight: Double(otherSize) / Double(totalSize),
                rect: otherRect,
                color: Brand.textDim
            ))
        }
        return cells
    }

    // MARK: - Canvas Drawing

    private func drawCell(context: inout GraphicsContext, cell: TreemapCell) {
        let rect = cell.rect

        // Skip invisible cells
        guard rect.width >= 2, rect.height >= 2 else { return }

        // Tiny cells: minimal dot with no labels
        if rect.width < 6 || rect.height < 6 {
            let dotRect = rect.insetBy(dx: 0.5, dy: 0.5)
            let dotPath = Path(roundedRect: dotRect, cornerRadius: 1)
            context.fill(dotPath, with: .color(cell.color.opacity(0.5)))
            context.stroke(dotPath, with: .color(Brand.lineColor.opacity(0.25)), lineWidth: 0.5)
            return
        }

        let isHovered = cell.id == hoveredID

        // Cell padding (gap between cells)
        let cellPadding: CGFloat = 1.5
        let drawRect: CGRect
        if rect.width >= 6, rect.height >= 6 {
            drawRect = rect.insetBy(dx: cellPadding, dy: cellPadding)
        } else {
            drawRect = rect
        }

        // Rounded corners
        let cornerRadius: CGFloat = min(3, min(drawRect.width, drawRect.height) / 3)
        let path = Path(roundedRect: drawRect, cornerRadius: cornerRadius)

        // Gradient fill — higher opacity for better colour visibility
        let baseHigh: Double = isHovered ? 0.88 : 0.70
        let baseLow: Double = isHovered ? 0.68 : 0.50
        let gradient = Gradient(colors: [
            cell.color.opacity(baseHigh),
            cell.color.opacity(baseLow)
        ])
        context.fill(path, with: .linearGradient(
            gradient,
            startPoint: drawRect.origin,
            endPoint: CGPoint(x: drawRect.maxX, y: drawRect.maxY)
        ))

        // Subtle top/left highlight for 3D bevel (large cells only)
        if !isHovered, drawRect.width >= 16, drawRect.height >= 16 {
            let highlightPath = Path { p in
                p.move(to: CGPoint(x: drawRect.minX + cornerRadius, y: drawRect.minY))
                p.addLine(to: CGPoint(x: drawRect.maxX - cornerRadius, y: drawRect.minY))
            }
            context.stroke(highlightPath, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
        }

        // Border — more visible for separation
        let borderOpacity: Double = isHovered ? 0.8 : 0.45
        let borderWidth: CGFloat = isHovered ? 1.5 : 0.8
        context.stroke(path, with: .color(Brand.lineColor.opacity(borderOpacity)), lineWidth: borderWidth)

        // Labels (lower thresholds so more cells show text)
        guard drawRect.width >= 40, drawRect.height >= 18 else { return }

        // Name
        let fontSize: CGFloat = {
            if drawRect.height >= 32 { return 10 }
            else if drawRect.height >= 22 { return 8 }
            else { return 7 }
        }()
        let nameFont = Font.custom(Brand.titleFont, size: fontSize)
        let nameText = Text(cell.name).font(nameFont).foregroundColor(Brand.textPrimary)
        let namePos = CGPoint(x: drawRect.minX + 5, y: drawRect.minY + 3)
        context.draw(nameText, at: namePos, anchor: .topLeading)

        // Size (lower threshold)
        if drawRect.height >= 28 {
            let sizeText = Text(Format.bytes(cell.size))
                .font(.custom(Brand.monoFont, size: max(7, fontSize - 1)))
                .foregroundColor(Brand.accentGold)
            let sizePos = CGPoint(x: drawRect.minX + 5, y: drawRect.maxY - 3)
            context.draw(sizeText, at: sizePos, anchor: .bottomLeading)
        }

        // SF Symbol icon (lower threshold)
        if drawRect.width >= 64, drawRect.height >= 40 {
            let iconName = cell.isDir ? "folder.fill" : "doc.fill"
            let icon = Image(systemName: iconName)
            let iconSize: CGFloat = min(16, min(drawRect.width, drawRect.height) * 0.35)
            let iconRect = CGRect(
                x: drawRect.midX - iconSize / 2,
                y: drawRect.midY - iconSize / 2,
                width: iconSize, height: iconSize
            )
            context.draw(icon, in: iconRect)
        }
    }

    // MARK: - Hover

    private func drawHover(context: inout GraphicsContext, cell: TreemapCell) {
        let rect = cell.rect
        let hoverRect = rect.insetBy(dx: 2, dy: 2)
        let cornerRadius: CGFloat = min(3, min(hoverRect.width, hoverRect.height) / 3)
        let path = Path(roundedRect: hoverRect, cornerRadius: cornerRadius)

        // Outer glow stroke
        context.stroke(path, with: .color(Brand.accentOrange.opacity(0.7)), lineWidth: 2.5)

        // Inner glow fill
        context.fill(path, with: .color(Brand.accentOrange.opacity(0.08)))

        // Corner reticle marks — NASA-Punk aesthetic
        // Only draw full reticle on cells large enough; skip on very small cells
        guard hoverRect.width >= 28, hoverRect.height >= 28 else { return }

        let armLength: CGFloat = min(8, min(hoverRect.width, hoverRect.height) * 0.25)
        let gap: CGFloat = 3
        let reticlePath = Path { p in
            // Top-left
            p.move(to: CGPoint(x: hoverRect.minX + gap, y: hoverRect.minY))
            p.addLine(to: CGPoint(x: hoverRect.minX + gap, y: hoverRect.minY + armLength))
            p.move(to: CGPoint(x: hoverRect.minX, y: hoverRect.minY + gap))
            p.addLine(to: CGPoint(x: hoverRect.minX + armLength, y: hoverRect.minY + gap))
            // Top-right
            p.move(to: CGPoint(x: hoverRect.maxX - gap, y: hoverRect.minY))
            p.addLine(to: CGPoint(x: hoverRect.maxX - gap, y: hoverRect.minY + armLength))
            p.move(to: CGPoint(x: hoverRect.maxX, y: hoverRect.minY + gap))
            p.addLine(to: CGPoint(x: hoverRect.maxX - armLength, y: hoverRect.minY + gap))
            // Bottom-left
            p.move(to: CGPoint(x: hoverRect.minX + gap, y: hoverRect.maxY))
            p.addLine(to: CGPoint(x: hoverRect.minX + gap, y: hoverRect.maxY - armLength))
            p.move(to: CGPoint(x: hoverRect.minX, y: hoverRect.maxY - gap))
            p.addLine(to: CGPoint(x: hoverRect.minX + armLength, y: hoverRect.maxY - gap))
            // Bottom-right
            p.move(to: CGPoint(x: hoverRect.maxX - gap, y: hoverRect.maxY))
            p.addLine(to: CGPoint(x: hoverRect.maxX - gap, y: hoverRect.maxY - armLength))
            p.move(to: CGPoint(x: hoverRect.maxX, y: hoverRect.maxY - gap))
            p.addLine(to: CGPoint(x: hoverRect.maxX - armLength, y: hoverRect.maxY - gap))
        }
        context.stroke(reticlePath, with: .color(Brand.accentOrange.opacity(0.45)), lineWidth: 1)
    }
}

#Preview {
    let sample = DiskScanResult(
        path: "/Users/nigang",
        totalSize: 250_000_000_000,
        totalFiles: 1247,
        entries: [
            DiskScanEntry(id: "1", name: "Applications", path: "/Users/nigang/Applications", size: 86_000_000_000, isDir: true),
            DiskScanEntry(id: "2", name: "Library", path: "/Users/nigang/Library", size: 54_000_000_000, isDir: true),
            DiskScanEntry(id: "3", name: "Documents", path: "/Users/nigang/Documents", size: 12_000_000_000, isDir: true),
            DiskScanEntry(id: "4", name: "Downloads", path: "/Users/nigang/Downloads", size: 8_000_000_000, isDir: true),
        ],
        scannedAt: Date()
    )

    TreemapCanvasView(
        entries: sample.entries,
        onSelect: { _ in },
        onRevealInFinder: { _ in }
    )
    .frame(width: 500, height: 400)
    .background(Brand.bgNavy)
}
