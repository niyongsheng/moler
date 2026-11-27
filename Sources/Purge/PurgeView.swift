import SwiftUI

struct PurgeView: View {
    @StateObject private var vm = PurgeViewModel()
    @ObservedObject private var activity = AppActivityMonitor.shared
    let isVisible: Bool

    init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }

    private var sceneVisible: Bool { isVisible && activity.isWindowVisible }

    var body: some View {
        ZStack {
            // Mercury 3D background
            SceneKitMercuryView(isScanning: vm.isScanning, isVisible: sceneVisible)

            // Foreground UI
            Group {
                if isIdle {
                    PageChrome(
                        icon: Pane.purge.iconName,
                        title: L10n.purgeTitle,
                        subtitle: L10n.purgeSubtitle
                    ) {
                        idleView
                    }
                } else {
                    content
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if let error = vm.errorMessage { errorBanner(error) }
        }
    }

    private var isIdle: Bool {
        if case .idle = vm.state { return true }
        return false
    }

    @ViewBuilder private var content: some View {
        switch vm.state {
        case .idle: idleView
        case .scanning(let p): scanningView(p)
        case .review(let plan): reviewView(plan)
        case .running(let log): runView(log)
        case .done(let f, let c, let fail): doneView(f, c, fail)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        PageContentColumn {
            // Scan target selector
            VStack(spacing: 10) {
                // Header
                HStack {
                    Text(String(
                        format: L10n.purgeSelectedCount,
                        vm.scanTargets.filter(\.isSelected).count,
                        vm.scanTargets.count
                    ))
                        .monoFont(10).foregroundColor(Brand.accentOrange)
                    Spacer()
                    Button(action: {
                        let all = vm.scanTargets.allSatisfy(\.isSelected)
                        vm.selectAllTargets(!all)
                    }) {
                        Text(vm.scanTargets.allSatisfy(\.isSelected) ? L10n.cleanReviewDeselectAll : L10n.cleanReviewSelectAll)
                            .monoFont(10).foregroundColor(Brand.accentGold)
                    }
                    .buttonStyle(.plain)
                }

                // Preset targets row
                if !presetTargets.isEmpty {
                    HStack(spacing: 6) {
                        Text(L10n.purgePathsSectionDefaults)
                            .monoFont(8).kerning(2).foregroundColor(Brand.textDim.opacity(0.5))
                        Brand.lineColor.frame(height: 0.5)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presetTargets) { target in
                                targetPill(target, accentColor: Brand.accentOrange, showRemove: false)
                            }
                        }
                    }
                }

                // Custom targets row (with ADD_PATH at the front)
                    HStack(spacing: 6) {
                        Text(L10n.purgePathsSectionCustom)
                            .monoFont(8).kerning(2).foregroundColor(Brand.textDim.opacity(0.5))
                        Brand.lineColor.frame(height: 0.5)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // ADD_PATH button at the front of the row
                            Button(action: addCustomPath) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 10))
                                    Text(L10n.purgePathsAdd)
                                        .monoFont(9)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Brand.accentGreen.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.accentGreen, style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])))
                                .foregroundColor(Brand.accentGreen)
                            }
                            .buttonStyle(.plain)
                            .cornerRadius(4)

                            ForEach(customTargets) { target in
                                targetPill(target, accentColor: Brand.accentGreen, showRemove: true)
                            }
                        }
                    }

                HStack(spacing: 4) {
                    Image(systemName: "info.circle").font(.system(size: 9))
                    Text(vm.usingDefaults ? L10n.purgePathsDefaults : L10n.purgePathsCustom)
                        .monoFont(8)
                    Spacer()
                }
                .foregroundColor(Brand.textDim.opacity(0.7))

                HStack(spacing: 4) {
                    Image(systemName: "link").font(.system(size: 8))
                    Text(L10n.purgePathsShared).monoFont(8)
                    Spacer()
                }
                .foregroundColor(Brand.textDim.opacity(0.5))
            }
            .padding(20)
            .background(Brand.bgCard.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Brand.lineColor, lineWidth: 0.5))
            .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                Button(action: { vm.startScan() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(L10n.purgeInitiate).titleFont(14).kerning(6)
                    }
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(vm.hasSelectedTargets ? Brand.accentOrange.opacity(0.15) : Brand.lineColor.opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(vm.hasSelectedTargets ? Brand.accentOrange : Brand.lineColor, lineWidth: 1))
                    .foregroundColor(vm.hasSelectedTargets ? Brand.accentOrange : Brand.textDim)
                }
                .buttonStyle(.plain)
                .disabled(!vm.hasSelectedTargets)

                Spacer()
            }
        }
    }

    /// Preset (built-in) scan targets.
    private var presetTargets: [ScanTarget] {
        vm.scanTargets.filter { !vm.isCustomTarget($0.id) }
    }

    /// Custom (user-added) scan targets.
    private var customTargets: [ScanTarget] {
        vm.scanTargets.filter { vm.isCustomTarget($0.id) }
    }

    /// A single toggleable pill for a scan target.
    private func targetPill(_ target: ScanTarget, accentColor: Color, showRemove: Bool) -> some View {
        HStack(spacing: 0) {
            Button(action: { vm.toggleTarget(target.id) }) {
                HStack(spacing: 4) {
                    Image(systemName: target.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10))
                    Text(target.name)
                        .monoFont(10)
                }
                .padding(.leading, 12)
                .padding(.vertical, 6)
                .padding(.trailing, showRemove ? 2 : 12)
            }
            .buttonStyle(.plain)

            if showRemove {
                Button(action: { vm.removeTarget(target.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(accentColor.opacity(0.6))
                        .padding(.trailing, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .help(L10n.purgePathsRemove)
            }
        }
        .background(
            target.isSelected
                ? accentColor.opacity(0.2)
                : Brand.bgCard
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(target.isSelected ? accentColor : Brand.lineColor,
                        lineWidth: target.isSelected ? 1 : 0.5)
        )
        .foregroundColor(target.isSelected ? accentColor : Brand.textDim)
        .cornerRadius(4)
    }

    /// Open a folder picker and add the chosen path as a custom scan target.
    private func addCustomPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.message = L10n.purgePickerMessage
        panel.prompt = L10n.purgePickerPrompt
        panel.begin { [self] response in
            if response == .OK, let url = panel.url {
                vm.addCustomPath(url.path)
            }
        }
    }

    // MARK: - Scanning

    private func scanningView(_ progress: ScanProgress) -> some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Text(L10n.purgeScanning).titleFont(18).kerning(6).foregroundColor(Brand.accentOrange)
                Text(L10n.purgeScanningHint).monoFont(10).foregroundColor(Brand.textDim)
                HStack(spacing: 24) {
                    DataRow(label: L10n.cleanFiles, value: "\(progress.currentItem)/\(progress.totalItems)")
                    DataRow(label: L10n.cleanSize, value: Format.bytes(progress.scannedBytes))
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

    private func reviewView(_ plan: PurgePlan) -> some View {
        VStack(spacing: 0) {
            InstrumentPanel(
                title: L10n.purgeReviewTitle,
                subtitle: nil,
                badge: "\(plan.displayItemCount)"
            ) {
                HStack(spacing: 24) {
                    DataRow(label: L10n.purgeReviewTotal, value: Format.bytes(plan.totalBytes))
                    DataRow(
                        label: L10n.purgeReviewPaths,
                        value: "\(vm.scanTargets.filter(\.isSelected).count)"
                    )
                }
            }.frame(maxHeight: 100).padding(.bottom, Brand.margin)

            notices(plan)

            if plan.entries.isEmpty {
                Spacer()
                Text(L10n.purgeReviewEmpty)
                    .monoFont(11).foregroundColor(Brand.textDim)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(plan.entries) { entry in
                            PurgeEntryRow(entry: entry)
                            Divider().background(Brand.lineColor.opacity(0.3))
                        }
                    }
                }
                .background(Brand.bgCard.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.lineColor, lineWidth: 0.5))
            }

            footer(plan)
        }
    }

    @ViewBuilder
    private func notices(_ plan: PurgePlan) -> some View {
        VStack(spacing: 6) {
            if plan.cloudCount > 0 {
                NoticeRow(
                    icon: "icloud",
                    text: String(format: L10n.purgeReviewCloudNote, plan.cloudCount),
                    color: Brand.accentGold,
                    lineLimit: 2
                )
            }
            if !plan.warnings.isEmpty {
                NoticeRow(
                    icon: "exclamationmark.triangle",
                    text: plan.warnings.prefix(2).joined(separator: " · "),
                    color: Brand.accentOrange,
                    lineLimit: 2
                )
            }
            HStack(spacing: 4) {
                Image(systemName: "shield").font(.system(size: 8))
                Text(L10n.purgeReviewNote).monoFont(8)
                Spacer()
            }
            .foregroundColor(Brand.textDim.opacity(0.6))
        }
        .padding(.bottom, Brand.marginTight)
    }

    private func footer(_ plan: PurgePlan) -> some View {
        HStack(spacing: 12) {
            Button(action: { vm.reset() }) {
                Image(systemName: "arrow.left").font(.system(size: 12, weight: .medium))
            }.buttonStyle(.plain).foregroundColor(Brand.textDim)
            Divider().frame(height: 20).overlay(Brand.lineColor)
            Text(Format.bytes(plan.totalBytes))
                .monoFont(12).foregroundColor(Brand.accentOrange)
            Text("· \(plan.displayItemCount) \(L10n.purgeReviewItems)")
                .monoFont(9).foregroundColor(Brand.textDim)
            Spacer()
            Button(action: { vm.startPurge() }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash").font(.system(size: 11))
                    Text(L10n.purgeReviewExecute).titleFont(11).kerning(3)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(plan.entries.isEmpty ? Brand.lineColor.opacity(0.3) : Brand.accentOrange)
                .foregroundColor(plan.entries.isEmpty ? Brand.textDim : .white)
                .clipShape(Capsule())
            }.buttonStyle(.plain).disabled(plan.entries.isEmpty)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Brand.bgElevated.opacity(0.95)).clipShape(Capsule())
        .overlay(Capsule().stroke(Brand.lineColor, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 8, y: -2)
        .padding(.horizontal, 40).padding(.bottom, 16).padding(.top, Brand.margin)
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
                .onChange(of: log.count) {
                    if let last = log.last { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                }
            }
        }
    }

    // MARK: - Done

    private func doneView(_ freedBytes: Int64, _ itemsRemoved: Int, _ itemsFailed: Int = 0) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: itemsFailed > 0 ? "checkmark.circle.trianglebadge.exclamationmark" : "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(itemsFailed > 0 ? Brand.accentOrange : Brand.accentGreen)
            VStack(spacing: 6) {
                Text(L10n.purgeDoneTitle).titleFont(24).kerning(6).foregroundColor(Brand.accentOrange)
                Text(L10n.purgeDoneSubtitle).monoFont(10).foregroundColor(Brand.textDim)
            }
            GlassCard {
                VStack(spacing: Brand.unit * 2) {
                    DataRow(label: L10n.purgeDoneSpaceFreed, value: Format.bytes(freedBytes))
                    DataRow(label: L10n.purgeDoneItemsRemoved, value: "\(itemsRemoved)")
                    if itemsFailed > 0 {
                        DataRow(label: L10n.purgeDoneFailed, value: "\(itemsFailed)")
                    }
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
        ErrorBanner(message: message) { vm.errorMessage = nil }
    }
}

// MARK: - Purge Entry Row

struct PurgeEntryRow: View {
    let entry: PurgeEntry

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(entry.name).monoFont(11).foregroundColor(Brand.textPrimary)
                    if entry.isCloud {
                        Image(systemName: "icloud")
                            .font(.system(size: 9))
                            .foregroundColor(Brand.accentGold)
                    }
                }
                Text(entry.path).monoFont(8).foregroundColor(Brand.textDim).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(Format.bytes(entry.size)).monoFont(10).foregroundColor(Brand.accentGold)
        }
        .padding(.horizontal, Brand.marginTight + 6).padding(.vertical, 6)
    }
}

#Preview("Idle") { PurgeView().frame(width: 900, height: 640) }
