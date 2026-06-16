import SwiftUI

struct PurgeView: View {
    @StateObject private var vm = PurgeViewModel()

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if let error = vm.errorMessage { errorBanner(error) }
        }
    }

    @ViewBuilder private var content: some View {
        switch vm.state {
        case .idle: idleView
        case .scanning(let p): scanningView(p)
        case .review(let entries): reviewView(entries)
        case .running(let log): runView(log)
        case .done(let f, let c): doneView(f, c)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Reticle(strokeColor: Brand.accentOrange.opacity(0.5), lineWidth: 0.5, armLength: 20)
                    .frame(width: 120, height: 120)
                Image(systemName: "hammer.fill").font(.system(size: 42)).foregroundColor(Brand.accentOrange)
            }
            VStack(spacing: 6) {
                Text(L10n.purgeTitle).titleFont(28).kerning(8).foregroundColor(Brand.accentOrange)
                Text(L10n.purgeSubtitle).monoFont(10).foregroundColor(Brand.textDim)
            }
            GlassCard {
                VStack(spacing: Brand.unit * 2) {
                    DataRow(label: L10n.purgeScanPath, value: "~/Library/Developer, ~/Library/Caches, ~/.gradle …")
                }
            }.frame(maxWidth: 400)
            Button(action: { vm.startScan() }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(L10n.purgeInitiate).titleFont(14).kerning(6)
                }
                .padding(.horizontal, 32).padding(.vertical, 12)
                .background(Brand.accentOrange.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.accentOrange, lineWidth: 1))
                .foregroundColor(Brand.accentOrange)
            }.buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Scanning

    private func scanningView(_ progress: ScanProgress) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ScanLine().frame(width: 300, height: 300)
            VStack(spacing: 8) {
                Text(L10n.purgeScanning).titleFont(18).kerning(6).foregroundColor(Brand.accentOrange)
                Text(L10n.purgeScanningHint).monoFont(10).foregroundColor(Brand.textDim)
                HStack(spacing: 24) {
                    DataRow(label: L10n.cleanFiles, value: "\(progress.currentItem)/\(progress.totalItems)")
                    DataRow(label: L10n.cleanSize, value: formatBytes(progress.scannedBytes))
                    DataRow(label: L10n.cleanElapsed, value: "\(progress.elapsedSeconds)s")
                }
            }
            ProgressGlow(progress: min(0.3 + Double(progress.elapsedSeconds) * 0.02, 0.9)).frame(width: 200)
            HStack(spacing: 12) {
                Button(action: { vm.cancelScan() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark").font(.system(size: 10))
                        Text(L10n.purgeCancel).monoFont(10)
                    }
                    .foregroundColor(Brand.textDim).padding(.horizontal, 16).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.lineColor, lineWidth: 0.5))
                }.buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Review

    private func reviewView(_ entries: [PurgeEntry]) -> some View {
        let selected = vm.selectedPaths
        return VStack(spacing: 0) {
            InstrumentPanel(title: L10n.purgeReviewTitle, subtitle: nil, badge: "\(vm.selectedCount(from: entries))/\(entries.count)") {
                HStack(spacing: 24) {
                    DataRow(label: L10n.purgeReviewTotal, value: formatBytes(entries.reduce(0){$0+$1.size}))
                }
            }.frame(maxHeight: 100).padding(.bottom, Brand.margin)

            ScrollView {
                LazyVStack(spacing: 0) {
                    Button(action: {
                        let all = selected.count == entries.count
                        vm.selectedPaths = all ? [] : Set(entries.map(\.path))
                    }) {
                        HStack(spacing: 6) {
                            ReticleCheck(selected: selected.count == entries.count).frame(width: 14, height: 14)
                            Text(selected.count == entries.count ? L10n.cleanReviewDeselectAll : L10n.cleanReviewSelectAll)
                                .monoFont(10).foregroundColor(Brand.accentGold)
                            Spacer()
                        }.padding(.horizontal, Brand.marginTight + 6).padding(.vertical, 6)
                    }.buttonStyle(.plain)
                    Divider().background(Brand.lineColor)

                    ForEach(entries) { entry in
                        PurgeEntryRow(entry: entry, isSelected: selected.contains(entry.path), onToggle: { vm.toggleSelection(entry.path) })
                        Divider().background(Brand.lineColor.opacity(0.3))
                    }
                }
            }
            .background(Brand.bgCard.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.lineColor, lineWidth: 0.5))

            // Floating pill
            let hasSel = !selected.isEmpty
            HStack(spacing: 12) {
                Button(action: { vm.reset() }) {
                    Image(systemName: "arrow.left").font(.system(size: 12, weight: .medium))
                }.buttonStyle(.plain).foregroundColor(Brand.textDim)
                Divider().frame(height: 20).overlay(Brand.lineColor)
                if hasSel {
                    Text("\(vm.selectedCount(from: entries)) selected").monoFont(10).foregroundColor(Brand.textPrimary)
                    Text(formatBytes(vm.selectedTotalBytes(from: entries))).monoFont(12).foregroundColor(Brand.accentOrange)
                } else {
                    Text("Nothing selected").monoFont(10).foregroundColor(Brand.textDim)
                }
                Spacer()
                Button(action: { vm.startPurge() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash").font(.system(size: 11))
                        Text(L10n.purgeReviewExecute).titleFont(11).kerning(3)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(hasSel ? Brand.accentOrange : Brand.lineColor.opacity(0.3))
                    .foregroundColor(hasSel ? .white : Brand.textDim)
                    .clipShape(Capsule())
                }.buttonStyle(.plain).disabled(!hasSel)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Brand.bgElevated.opacity(0.95)).clipShape(Capsule())
            .overlay(Capsule().stroke(Brand.lineColor, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.3), radius: 8, y: -2)
            .padding(.horizontal, 40).padding(.bottom, 16).padding(.top, Brand.margin)
        }
    }

    // MARK: - Running

    private func runView(_ log: [String]) -> some View {
        VStack(spacing: 0) {
            InstrumentPanel(title: L10n.purgeRunTitle, subtitle: L10n.purgeRunSubtitle, badge: nil) {
                DataRow(label: L10n.cleanRunStatus, value: L10n.purgeRunExecuting)
            }.frame(maxHeight: 100).padding(.bottom, Brand.margin)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                            Text(line).monoFont(9).foregroundColor(Brand.textPrimary).id(line)
                        }
                    }.padding(.horizontal, 8).padding(.vertical, 4)
                }
                .background(Brand.bgCard.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.lineColor, lineWidth: 0.5))
                .onChange(of: log.count) { _ in
                    if let last = log.last { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                }
            }
        }
    }

    // MARK: - Done

    private func doneView(_ freedBytes: Int64, _ itemsRemoved: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundColor(.green)
            VStack(spacing: 6) {
                Text(L10n.purgeDoneTitle).titleFont(24).kerning(6).foregroundColor(Brand.accentOrange)
                Text(L10n.purgeDoneSubtitle).monoFont(10).foregroundColor(Brand.textDim)
            }
            GlassCard {
                VStack(spacing: Brand.unit * 2) {
                    DataRow(label: L10n.purgeDoneSpaceFreed, value: formatBytes(freedBytes))
                    DataRow(label: L10n.purgeDoneItemsRemoved, value: "\(itemsRemoved)")
                }
            }.frame(maxWidth: 300)
            Button(action: { vm.reset() }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(L10n.purgeDoneNewScan).titleFont(12).kerning(4)
                }
                .padding(.horizontal, 24).padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.accentOrange, lineWidth: 1))
                .foregroundColor(Brand.accentOrange)
            }.buttonStyle(.plain)
            Spacer()
        }
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Brand.accentRed)
            Text(message).monoFont(11).foregroundColor(Brand.accentRed)
            Spacer()
            Button(L10n.errorDismiss) { vm.errorMessage = nil }.monoFont(10).foregroundColor(Brand.textDim)
        }
        .padding(Brand.marginTight).background(Brand.bgCard.opacity(0.95))
        .overlay(Rectangle().fill(Brand.accentRed).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - Purge Entry Row

struct PurgeEntryRow: View {
    let entry: PurgeEntry
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                ReticleCheck(selected: isSelected).frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name).monoFont(11).foregroundColor(Brand.textPrimary)
                    Text(entry.path).monoFont(8).foregroundColor(Brand.textDim).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text(formatBytes(entry.size)).monoFont(10).foregroundColor(Brand.accentGold)
            }
            .padding(.horizontal, Brand.marginTight + 6).padding(.vertical, 6)
        }.buttonStyle(.plain)
    }
}

#Preview("Idle") { PurgeView().frame(width: 900, height: 640) }
