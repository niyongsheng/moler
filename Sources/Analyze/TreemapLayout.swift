import Foundation
import CoreGraphics

// MARK: - Squarified Treemap Layout

/// Pure-functional implementation of Bruls, Huijsen & van Wijk's squarified
/// treemap algorithm (2000). No SwiftUI or I/O dependencies.
///
/// Usage:
/// ```
/// let rects = TreemapLayout.layout(weights: [6, 5, 3, 2, 1], in: CGRect(x: 0, y: 0, width: 400, height: 300))
/// ```
enum TreemapLayout {

    /// Compute a squarified treemap layout.
    /// - Parameter weights: Relative sizes (sorted descending is ideal but not required).
    /// - Parameter rect: The bounding rectangle to fill.
    /// - Returns: `CGRect` values in the same order as `weights`.
    static func layout(weights: [Double], in rect: CGRect) -> [CGRect] {
        guard !weights.isEmpty else { return [] }

        // Pair each weight with its original index
        let indexed: [(index: Int, weight: Double)] = weights.enumerated().map { ($0, max($1, 0)) }
        let total = indexed.map(\.weight).reduce(0, +)
        guard total > 0 else { return weights.map { _ in .zero } }

        // Work with normalised area weights
        let areas: [(index: Int, area: Double)] = indexed.map { ($0.index, $0.weight / total * rect.width * rect.height) }

        return squarify(items: areas, rect: rect)
            .sorted { $0.index < $1.index }
            .map(\.rect)
    }

    /// Fold entries beyond `maxVisible` into a single "Other" summary.
    /// Returns (kept items, other total size).
    static func foldOther(entries: [DiskScanEntry], maxVisible: Int = 120) -> (visible: [DiskScanEntry], otherSize: Int64) {
        guard entries.count > maxVisible else { return (entries, 0) }
        let visible = Array(entries.prefix(maxVisible))
        let otherSize = entries.dropFirst(maxVisible).reduce(0) { $0 + $1.size }
        return (visible, otherSize)
    }

    // MARK: - Private

    private struct IndexedRect {
        let index: Int
        let rect: CGRect
    }

    /// Recursive squarify implementation.
    private static func squarify(items: [(index: Int, area: Double)], rect: CGRect) -> [IndexedRect] {
        guard !items.isEmpty else { return [] }

        let w = rect.width < rect.height ? rect.width : rect.height
        let first = items[0]
        let rest = Array(items[1...])

        // Try to build the best row starting with the first item
        let (row, remaining) = buildRow(items: rest, row: [first], rowArea: first.area, w: w, rect: rect)
        let rowRects = layoutRow(items: row, rect: rect)

        // Compute the remaining rectangle
        let remainingRect = remainingRect(for: row, totalRect: rect)

        // Recursively layout the rest
        return rowRects + squarify(items: remaining, rect: remainingRect)
    }

    /// Greedily build a row by adding items while aspect ratio improves.
    private static func buildRow(
        items: [(index: Int, area: Double)],
        row: [(index: Int, area: Double)],
        rowArea: Double,
        w: Double,
        rect: CGRect
    ) -> (row: [(index: Int, area: Double)], remaining: [(index: Int, area: Double)]) {
        guard let next = items.first else { return (row, []) }

        let newRow = row + [next]
        let newRowArea = rowArea + next.area

        let currentWorst = worst(row: row, rowArea: rowArea, w: w)
        let newWorst = worst(row: newRow, rowArea: newRowArea, w: w)

        // If adding the next item improves (reduces) the worst aspect ratio, keep it
        if currentWorst.isZero || newWorst < currentWorst {
            return buildRow(
                items: Array(items[1...]),
                row: newRow,
                rowArea: newRowArea,
                w: w,
                rect: rect
            )
        }

        return (row, items)
    }

    /// Calculate the worst aspect ratio in a row.
    private static func worst(row: [(index: Int, area: Double)], rowArea: Double, w: Double) -> Double {
        guard !row.isEmpty, rowArea > 0 else { return 0 }

        let s2 = rowArea * rowArea
        let w2 = w * w

        var maxRatio = 0.0
        var minRatio = Double.infinity

        for item in row {
            let r = (w2 * item.area) / s2
            let ratio = r > 0 ? (s2 / (w2 * item.area)) : 0
            if r > maxRatio { maxRatio = r }
            if ratio < minRatio { minRatio = ratio }
        }

        return maxRatio / minRatio
    }

    /// Layout a row along the longer edge of the rectangle.
    /// The row fills the full extent of the longer side; thickness (short-side extent)
    /// = totalArea / longerSide. Items are arranged along the longer side.
    private static func layoutRow(items: [(index: Int, area: Double)], rect: CGRect) -> [IndexedRect] {
        guard !items.isEmpty else { return [] }

        let totalArea = items.map(\.area).reduce(0, +)
        guard totalArea > 0 else { return items.map { IndexedRect(index: $0.index, rect: .zero) } }

        let longer = max(rect.width, rect.height)
        let thickness = totalArea / longer
        let isLandscape = rect.width >= rect.height

        var offset: CGFloat = 0
        var result: [IndexedRect] = []

        for item in items {
            let itemExtent: CGFloat = item.area / thickness
            let cellRect: CGRect

            if isLandscape {
                // Landscape: items arranged HORIZONTALLY (along X). Thickness = height.
                cellRect = CGRect(x: rect.minX + offset, y: rect.minY,
                                 width: itemExtent, height: thickness)
            } else {
                // Portrait: items arranged VERTICALLY (along Y). Thickness = width.
                cellRect = CGRect(x: rect.minX, y: rect.minY + offset,
                                 width: thickness, height: itemExtent)
            }

            result.append(IndexedRect(index: item.index, rect: cellRect))
            offset += itemExtent
        }

        return result
    }

    /// Compute the remaining rectangle after placing a row.
    /// Row fills the full longer side; remaining space is on the opposite short side.
    private static func remainingRect(for row: [(index: Int, area: Double)], totalRect: CGRect) -> CGRect {
        let totalArea = row.map(\.area).reduce(0, +)
        guard totalArea > 0 else { return totalRect }

        let longer = max(totalRect.width, totalRect.height)
        let thickness = totalArea / longer
        let isLandscape = totalRect.width >= totalRect.height

        if isLandscape {
            // Landscape: row at top, remaining BELOW
            return CGRect(x: totalRect.minX, y: totalRect.minY + thickness,
                         width: totalRect.width, height: totalRect.height - thickness)
        } else {
            // Portrait: row on left, remaining to the RIGHT
            return CGRect(x: totalRect.minX + thickness, y: totalRect.minY,
                         width: totalRect.width - thickness, height: totalRect.height)
        }
    }
}
