import SwiftUI

/// Sidebar panel for the Analyze treemap — shows summary stats, breadcrumb, and top entries.
struct AnalyzeSidebarView: View {
    let result: DiskScanResult
    let breadcrumb: [BreadcrumbItem]
    let onSelect: (DiskScanEntry) -> Void
    let onNavigate: (BreadcrumbItem) -> Void
    let onGoBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary header
            InstrumentPanel(title: "TARGET", badge: "TOP 40") {
                VStack(alignment: .leading, spacing: 2) {
                    DataRow(label: "PATH", value: result.path)
                    DataRow(label: "SIZE", value: Format.bytes(result.totalSize))
                    DataRow(label: "FILES", value: Format.count(result.totalFiles))
                }
                .padding(.horizontal, Brand.margin)
                .padding(.vertical, Brand.marginTight)
            }

            // Separator
            Brand.lineColor.opacity(0.3)
                .frame(height: 0.5)

            // Breadcrumb
            AnalyzeBreadcrumbView(
                crumbs: breadcrumb,
                onNavigate: onNavigate,
                onGoBack: onGoBack
            )
            .padding(.horizontal, Brand.margin)
            .padding(.vertical, Brand.marginTight)

            // Separator
            Brand.lineColor.opacity(0.3)
                .frame(height: 0.5)

            // Entries list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(entries) { entry in
                        SidebarEntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect(entry) }
                    }
                }
                .padding(.horizontal, Brand.marginTight)
                .padding(.vertical, 4)
            }
        }
        .frame(width: 232)
        .background(Brand.bgCard.opacity(0.4))
        .overlay(
            Rectangle()
                .fill(Brand.lineColor.opacity(0.3))
                .frame(width: 0.5),
            alignment: .trailing
        )
    }

    /// All entries shown in order (no folding — matches treemap behaviour).
    private var entries: [DiskScanEntry] {
        Array(result.entries)
    }
}

// MARK: - Entry Row

private struct SidebarEntryRow: View {
    let entry: DiskScanEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isDir ? "folder.fill" : "doc.fill")
                .font(.system(size: 10))
                .foregroundColor(entry.isDir ? Brand.accentOrange : Brand.textDim)

            Text(entry.name)
                .monoFont(10)
                .foregroundColor(Brand.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text(Format.bytes(entry.size))
                .monoFont(9)
                .foregroundColor(Brand.accentGold)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(Brand.accentOrange.opacity(0.06))
        .cornerRadius(2)
    }
}
