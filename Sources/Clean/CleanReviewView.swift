import SwiftUI

// MARK: - Category grouping

private enum ReviewCategory: String, CaseIterable {
    case devTools = "Developer Tools"
    case appCaches = "App Caches"
    case browser = "Browser"
    case logs = "Logs"
    case trash = "Trash"
    case other = "Other"

    init(for entry: DiskScanEntry) {
        let p = entry.path.lowercased()
        if p.contains("deriveddata") || p.contains("xcode") || p.contains("node_modules") || p.contains(".gradle") || p.contains("carthage") { self = .devTools; return }
        if p.contains("library/caches") || p.contains(".cache") || p.contains("cache") { self = .appCaches; return }
        if p.contains("safari") || p.contains("chrome") || p.contains("firefox") || p.contains("chromium") || p.contains("cookies") { self = .browser; return }
        if p.contains(".log") || p.contains("diagnosticreports") || p.contains("crash") { self = .logs; return }
        if p.contains(".trash") || p.contains("trash") { self = .trash; return }
        self = .other
    }
}

/// Review scan results before cleaning.
struct CleanReviewView: View {
    @ObservedObject var vm: CleanViewModel
    let result: DiskScanResult

    private var grouped: [(ReviewCategory, [DiskScanEntry])] {
        Dictionary(grouping: result.entries, by: ReviewCategory.init)
            .sorted { $0.key.rawValue < $1.key.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header.frame(maxHeight: 100).padding(.bottom, Brand.margin)

            // Stale banner
            if result.isStale {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                    Text("Scan results are over 5 minutes old — rescan before cleaning.")
                        .monoFont(9)
                    Spacer()
                    Button("Rescan") { vm.startScan() }
                        .monoFont(9).foregroundColor(Brand.accentOrange)
                }
                .foregroundColor(Brand.accentGold)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Brand.accentGold.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.bottom, 8)
            }

            fileList

            // Floating pill footer
            pillFooter
        }
        .overlay(alignment: .bottom) { pillFooter }
    }

    // MARK: - Header

    private var header: some View {
        InstrumentPanel(
            title: L10n.cleanReviewTitle,
            subtitle: L10n.cleanReviewSubtitle,
            badge: "\(vm.selectedCount(from: result))/\(result.entries.count)"
        ) {
            HStack(spacing: 24) {
                DataRow(label: L10n.cleanReviewScanPath, value: result.path)
                DataRow(label: L10n.cleanReviewTotalSize, value: formatBytes(result.totalSize))
                DataRow(label: L10n.cleanReviewTotalFiles, value: Format.count(result.totalFiles))
                DataRow(label: L10n.cleanReviewSelected, value: formatBytes(vm.selectedTotalBytes(from: result)))
            }
        }
    }

    // MARK: - File List (grouped by category)

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                // Select all / deselect all
                selectAllRow

                if result.entries.isEmpty {
                    Text(L10n.cleanReviewNoFiles)
                        .monoFont(12).foregroundColor(Brand.textDim).padding(.vertical, 32)
                } else {
                    ForEach(grouped, id: \.0.rawValue) { category, entries in
                        categoryCard(category: category, entries: entries)
                    }
                }
            }
        }
        .background(Brand.bgCard.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.lineColor, lineWidth: 0.5))
    }

    // MARK: - Category Card

    private func categoryCard(category: ReviewCategory, entries: [DiskScanEntry]) -> some View {
        let selected = entries.filter { vm.selectedPaths.contains($0.path) }
        let allSelected = selected.count == entries.count
        let mixed = selected.count > 0 && !allSelected

        return VStack(spacing: 0) {
            Button(action: {
                if allSelected || mixed {
                    for e in entries { vm.selectedPaths.remove(e.path) }
                } else {
                    for e in entries { vm.selectedPaths.insert(e.path) }
                }
            }) {
                HStack(spacing: 8) {
                    // Tri-state indicator
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Brand.lineColor, lineWidth: 1)
                            .frame(width: 14, height: 14)
                        if allSelected {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                .foregroundColor(Brand.accentOrange)
                        } else if mixed {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Brand.accentOrange)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(category.rawValue.uppercased())
                        .titleFont(11).kerning(2).foregroundColor(Brand.textPrimary)
                    Spacer()
                    Text("\(formatBytes(entries.reduce(0){$0+$1.size})) • \(entries.count)")
                        .monoFont(9).foregroundColor(Brand.textDim)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Brand.bgElevated.opacity(0.5))

            ForEach(entries) { entry in
                FileEntryRow(
                    entry: entry,
                    isSelected: vm.selectedPaths.contains(entry.path),
                    onToggle: { vm.toggleSelection(entry.path) }
                )
                Divider().background(Brand.lineColor.opacity(0.15))
            }
        }
        .background(Brand.bgCard.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.lineColor.opacity(0.2), lineWidth: 0.5))
    }

    // MARK: - Select All Row

    private var selectAllRow: some View {
        let allSelected = vm.selectedPaths.count == result.entries.count
        return Button(action: {
            vm.selectedPaths = allSelected ? [] : Set(result.entries.map(\.path))
        }) {
            HStack(spacing: 6) {
                ReticleCheck(selected: allSelected).frame(width: 14, height: 14)
                Text(allSelected ? L10n.cleanReviewDeselectAll : L10n.cleanReviewSelectAll)
                    .monoFont(10).foregroundColor(Brand.accentGold)
                Spacer()
                if result.isStale {
                    Text("STALE").monoFont(8).foregroundColor(Brand.accentRed)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Brand.accentRed.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, Brand.marginTight + 6).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Floating Pill Footer

    private var pillFooter: some View {
        let count = vm.selectedCount(from: result)
        let bytes = vm.selectedTotalBytes(from: result)
        let hasSelection = !vm.selectedPaths.isEmpty

        return HStack(spacing: 12) {
            // Back
            Button(action: { vm.reset() }) {
                Image(systemName: "arrow.left").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain).foregroundColor(Brand.textDim)

            Divider().frame(height: 20).overlay(Brand.lineColor)

            // Live totals
            if hasSelection {
                Text("\(count) selected")
                    .monoFont(10).foregroundColor(Brand.textPrimary)
                Text(formatBytes(bytes))
                    .monoFont(12).foregroundColor(Brand.accentOrange)
            } else {
                Text("Nothing selected")
                    .monoFont(10).foregroundColor(Brand.textDim)
            }

            Spacer()

            // Execute
            Button(action: { vm.startClean() }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash").font(.system(size: 11))
                    Text(L10n.cleanReviewExecute).titleFont(11).kerning(3)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(hasSelection ? Brand.accentOrange : Brand.lineColor.opacity(0.3))
                .foregroundColor(hasSelection ? .white : Brand.textDim)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain).disabled(!hasSelection)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Brand.bgElevated.opacity(0.95))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Brand.lineColor, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 8, y: -2)
        .padding(.horizontal, 40).padding(.bottom, 16)
    }
}

#Preview {
    CleanReviewView(
        vm: CleanViewModel(),
        result: DiskScanResult(
            path: "/Users/nico",
            totalSize: 4_200_000_000,
            totalFiles: 1247,
            entries: [
                DiskScanEntry(id: "/1", name: "Library", path: "/Users/nico/Library/Caches", size: 2_100_000_000, isDir: true),
                DiskScanEntry(id: "/2", name: ".cache", path: "/Users/nico/.cache", size: 800_000_000, isDir: true),
                DiskScanEntry(id: "/3", name: "Downloads", path: "/Users/nico/Downloads", size: 500_000_000, isDir: true),
                DiskScanEntry(id: "/4", name: "node_modules", path: "/Users/nico/node_modules", size: 300_000_000, isDir: true),
            ],
            scannedAt: Date().addingTimeInterval(-400)
        )
    )
    .frame(width: 900, height: 600)
    .background(Brand.bgNavy)
    .environment(\.colorScheme, .dark)
}
