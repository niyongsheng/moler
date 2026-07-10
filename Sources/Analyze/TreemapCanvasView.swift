import SwiftUI

/// SwiftUI Canvas-based squarified treemap renderer.
/// Uses immediate-mode drawing for performance (not per-item SwiftUI views).
struct TreemapCanvasView: View {
    let entries: [DiskScanEntry]
    let onSelect: (DiskScanEntry) -> Void
    let onRevealInFinder: (DiskScanEntry) -> Void

    @State private var hoveredID: String?

    private let colorer = TreemapCellGenerator()

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

        // Compute weights
        let totalSize = max(entries.map(\.size).reduce(0, +), 1)
        let weights = entries.map { Double($0.size) / Double(totalSize) * Double(size.width * size.height) }

        // Layout
        let rects = TreemapLayout.layout(weights: weights, in: CGRect(origin: .zero, size: size))

        // Build cells (all entries, no "Other" folding — every item gets its own block)
        return zip(entries, rects).map { entry, rect in
            let weight = Double(entry.size) / Double(totalSize)
            return TreemapCell(
                id: entry.id,
                name: entry.name,
                path: entry.path,
                size: entry.size,
                isDir: entry.isDir,
                weight: weight,
                rect: rect,
                color: treemapColor(for: entry)
            )
        }
    }

    // MARK: - Canvas Drawing

    private func drawCell(context: inout GraphicsContext, cell: TreemapCell) {
        let rect = cell.rect
        let isHovered = cell.id == hoveredID
        let inset = isHovered ? rect.insetBy(dx: 1, dy: 1) : rect

        // Fill with gradient
        let gradient = Gradient(colors: [
            cell.color.opacity(isHovered ? 0.7 : 0.5),
            cell.color.opacity(isHovered ? 0.5 : 0.3)
        ])
        let path = Path(inset)
        context.fill(path, with: .linearGradient(
            gradient,
            startPoint: inset.origin,
            endPoint: CGPoint(x: inset.maxX, y: inset.maxY)
        ))

        // Border
        context.stroke(path, with: .color(Brand.lineColor.opacity(isHovered ? 0.7 : 0.3)), lineWidth: isHovered ? 1 : 0.5)

        // Labels (only for large enough cells)
        guard rect.width >= 66, rect.height >= 28 else { return }

        // Name
        let fontSize: CGFloat = rect.height >= 40 ? 11 : 9
        let nameFont = Font.custom(Brand.titleFont, size: fontSize)
        let nameText = Text(cell.name).font(nameFont).foregroundColor(Brand.textPrimary)
        let namePos = CGPoint(x: rect.minX + 6, y: rect.minY + 4)
        context.draw(nameText, at: namePos, anchor: .topLeading)

        // Size (only if enough height for two lines)
        if rect.height >= 44 {
            let sizeText = Text(Format.bytes(cell.size))
                .font(.custom(Brand.monoFont, size: 9))
                .foregroundColor(Brand.accentGold)
            let sizePos = CGPoint(x: rect.minX + 6, y: rect.maxY - 4)
            context.draw(sizeText, at: sizePos, anchor: .bottomLeading)
        }

        // SF Symbol icon (only for very large cells)
        if rect.width >= 96, rect.height >= 52 {
            let iconName = cell.isDir ? "folder.fill" : "doc.fill"
            let icon = Image(systemName: iconName)
            let iconRect = CGRect(
                x: rect.midX - 10, y: rect.midY - 16,
                width: 20, height: 20
            )
            context.draw(icon, in: iconRect)
        }
    }

    private func drawHover(context: inout GraphicsContext, cell: TreemapCell) {
        let rect = cell.rect.insetBy(dx: 1, dy: 1)
        let path = Path(rect)

        // Glow stroke
        context.stroke(path, with: .color(Brand.accentOrange.opacity(0.5)), lineWidth: 2)

        // Inner glow (semi-transparent overlay)
        let glowPath = Path(rect)
        context.fill(glowPath, with: .color(Brand.accentOrange.opacity(0.06)))
    }
}

// MARK: - Helper

/// Pre-computes treemap cell colours from entries.
private struct TreemapCellGenerator {
    func color(for entry: DiskScanEntry) -> SwiftUI.Color {
        treemapColor(for: entry)
    }

    func weight(_ size: Int64, total: Int64) -> Double {
        total > 0 ? Double(size) / Double(total) : 0
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
