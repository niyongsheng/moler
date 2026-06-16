import SwiftUI

/// A terminal-style data row: `> LABEL: VALUE` with NASA-Punk typography.
/// Small, dense, monospace — evokes an instrument readout.
struct DataRow: View {
    let label: String
    let value: String
    var dimmed: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(">")
                .monoFont(10)
                .foregroundColor(Brand.accentOrange)

            Text(label)
                .monoFont(11)
                .foregroundColor(dimmed ? Brand.textDim : Brand.textPrimary)

            Text(":")
                .monoFont(11)
                .foregroundColor(Brand.lineColor)

            Text(value)
                .monoFont(11)
                .foregroundColor(dimmed ? Brand.textDim : Brand.accentGold)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// A clickable file entry row for the clean review list.
struct FileEntryRow: View {
    let entry: DiskScanEntry
    let isSelected: Bool
    let onToggle: () -> Void

    private var sizeText: String {
        formatBytes(entry.size)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Brand.unit * 2) {
                // Check indicator (reticle-style)
                ReticleCheck(selected: isSelected)
                    .frame(width: 14, height: 14)

                // Kind badge
                Text(entry.kind.uppercased())
                    .monoFont(8)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Brand.accentBlue.opacity(0.3))
                    .foregroundColor(Brand.accentGold)
                    .cornerRadius(2)

                // Path
                Text(entry.name)
                    .monoFont(11)
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // Size
                Text(sizeText)
                    .monoFont(11)
                    .foregroundColor(Brand.accentGold)
            }
            .padding(.horizontal, Brand.marginTight)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Brand.accentOrange.opacity(0.08) : Color.clear)
    }
}

// MARK: - Helpers

/// Reticle-style checkbox (four corner brackets).
struct ReticleCheck: View {
    let selected: Bool

    var body: some View {
        ZStack {
            if selected {
                // Filled center
                RoundedRectangle(cornerRadius: 2)
                    .fill(Brand.accentOrange.opacity(0.6))
                // Corner brackets
                CornerBrackets()
                    .stroke(Brand.accentOrange, lineWidth: 1.5)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Brand.lineColor, lineWidth: 1)
            }
        }
    }
}

/// The four-corner bracket reticle shape.
struct CornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let len: CGFloat = 4
        var p = Path()

        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))

        // Top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))

        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))

        return p
    }
}

#Preview {
    VStack(spacing: 8) {
        DataRow(label: "TGT_SIZE", value: "2.4GB")
        DataRow(label: "TGT_FILES", value: "1,247")
        DataRow(label: "STATUS", value: "IDLE", dimmed: true)
        FileEntryRow(
            entry: DiskScanEntry(id: "/a", name: "cache.db", path: "/tmp/cache.db", size: 1024000, isDir: false),
            isSelected: true,
            onToggle: {}
        )
    }
    .padding()
    .background(Brand.bgNavy)
    .environment(\.colorScheme, .dark)
}
