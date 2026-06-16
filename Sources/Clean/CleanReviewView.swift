import SwiftUI

/// Review scan results before cleaning. Shows a sortable list with reticle checkboxes.
struct CleanReviewView: View {
    @ObservedObject var vm: CleanViewModel
    let result: DiskScanResult

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.bottom, Brand.margin)

            // File list
            fileList

            // Footer with action buttons
            footer
                .padding(.top, Brand.margin)
        }
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

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Select all / deselect all toggle
                selectAllRow
                    .padding(.bottom, 2)

                Divider()
                    .background(Brand.lineColor)

                if result.entries.isEmpty {
                    Text(L10n.cleanReviewNoFiles)
                        .monoFont(12)
                        .foregroundColor(Brand.textDim)
                        .padding(.vertical, 32)
                } else {
                    ForEach(result.entries) { entry in
                        FileEntryRow(
                            entry: entry,
                            isSelected: vm.selectedPaths.contains(entry.path),
                            onToggle: { vm.toggleSelection(entry.path) }
                        )
                        Divider()
                            .background(Brand.lineColor.opacity(0.3))
                    }
                }
            }
        }
        .background(Brand.bgCard.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Brand.lineColor, lineWidth: 0.5)
        )
    }

    // MARK: - Select All Row

    private var selectAllRow: some View {
        let allSelected = vm.selectedPaths.count == result.entries.count

        return Button(action: {
            if allSelected {
                vm.selectedPaths = []
            } else {
                vm.selectedPaths = Set(result.entries.map(\.path))
            }
        }) {
            HStack(spacing: 6) {
                ReticleCheck(selected: allSelected)
                    .frame(width: 14, height: 14)
                Text(allSelected ? L10n.cleanReviewDeselectAll : L10n.cleanReviewSelectAll)
                    .monoFont(10)
                    .foregroundColor(Brand.accentGold)
                Spacer()
            }
            .padding(.horizontal, Brand.marginTight + 6)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: { vm.reset() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                    Text(L10n.cleanReviewBack)
                        .titleFont(11)
                        .kerning(3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Brand.lineColor, lineWidth: 1)
                )
                .foregroundColor(Brand.textDim)
            }
            .buttonStyle(.plain)

            Spacer()

            // Selected stats
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: L10n.cleanReviewFilesSelected, vm.selectedCount(from: result)))
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
                Text(formatBytes(vm.selectedTotalBytes(from: result)))
                    .monoFont(12)
                    .foregroundColor(Brand.accentGold)
            }

            // Clean button
            Button(action: { vm.startClean() }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text(L10n.cleanReviewExecute)
                        .titleFont(12)
                        .kerning(4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    vm.selectedPaths.isEmpty
                        ? Brand.lineColor.opacity(0.3)
                        : Brand.accentOrange.opacity(0.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            vm.selectedPaths.isEmpty ? Brand.lineColor : Brand.accentOrange,
                            lineWidth: 1
                        )
                )
                .foregroundColor(
                    vm.selectedPaths.isEmpty ? Brand.textDim : Brand.accentOrange
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.selectedPaths.isEmpty)
        }
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
                DiskScanEntry(id: "/1", name: "Library", path: "/Users/nico/Library", size: 2_100_000_000, isDir: true),
                DiskScanEntry(id: "/2", name: ".cache", path: "/Users/nico/.cache", size: 800_000_000, isDir: true),
                DiskScanEntry(id: "/3", name: "Downloads", path: "/Users/nico/Downloads", size: 500_000_000, isDir: true),
                DiskScanEntry(id: "/4", name: "node_modules", path: "/Users/nico/node_modules", size: 300_000_000, isDir: true),
            ],
            scannedAt: Date()
        )
    )
    .frame(width: 900, height: 600)
    .background(Brand.bgNavy)
    .environment(\.colorScheme, .dark)
}
