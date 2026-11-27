import SwiftUI

/// The Clean tab — NASA-Punk themed disk scan and cleanup.
/// State-driven: renders different content for each `CleanState`.
struct CleanView: View {
    @StateObject private var vm = CleanViewModel()
    @ObservedObject private var activity = AppActivityMonitor.shared
    let isVisible: Bool

    init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }

    var body: some View {
        ZStack {
            // 3D solar-system backdrop. While a scan runs its planets speed up,
            // becoming the scan animation itself.
            SolarSystemBackground(
                isVisible: isVisible && activity.isWindowVisible,
                isScanning: isScanning
            )

            Group {
                if isIdle {
                    PageChrome(
                        icon: Pane.clean.iconName,
                        title: L10n.cleanTitle,
                        subtitle: L10n.cleanSubtitle
                    ) {
                        idleView
                    }
                } else {
                    // Active states keep the full height they were designed for.
                    content
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Error banner
        .overlay(alignment: .top) {
            if let error = vm.errorMessage {
                errorBanner(error)
            }
        }
    }

    private var isIdle: Bool {
        if case .idle = vm.state { return true }
        return false
    }

    private var isScanning: Bool {
        if case .scanning = vm.state { return true }
        return false
    }

    // MARK: - Content by State

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle:
            idleView
        case .scanning(let progress):
            scanningView(progress)
        case .review(let plan):
            CleanReviewView(vm: vm, plan: plan)
        case .running(let log, let progress):
            CleanRunView(log: log, progress: progress, elapsedSeconds: Int(Date().timeIntervalSince(vm.cleanStartTime ?? Date())), onCancel: { vm.cancelClean() })
        case .done(let freedBytes, let filesRemoved, let partial):
            CleanResultView(
                freedBytes: freedBytes,
                filesRemoved: filesRemoved,
                partial: partial,
                onDone: { vm.reset() }
            )
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        PageContentColumn {
            // Stats from last clean
            GlassCard {
                VStack(alignment: .leading, spacing: Brand.unit * 2) {
                    DataRow(label: L10n.cleanLastScan, value: Store.shared.lastScanPath)
                    DataRow(label: L10n.cleanLastClean, value: Store.shared.lastCleanDate?.formatted() ?? L10n.cleanNever)
                    DataRow(label: L10n.cleanTotalFreed, value: Format.bytes(Store.shared.totalFreedBytes))
                    DataRow(label: L10n.cleanCleanCount, value: "\(Store.shared.totalCleanCount)")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Initiate button
            HStack {
                Spacer()

                Button(action: { vm.startScan() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(L10n.cleanInitiate)
                            .titleFont(14)
                            .kerning(6)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Brand.accentOrange.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Brand.accentOrange, lineWidth: 1)
                    )
                    .foregroundColor(Brand.accentOrange)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    // MARK: - Scanning State

    private func scanningView(_ progress: ScanProgress) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // The 3D solar system behind the page is the scan animation now.
            // Keep its footprint so the readout stays below the system.
            Color.clear
                .frame(width: 300, height: 300)

            // Progress readout
            VStack(spacing: 8) {
                Text(L10n.cleanScanning)
                    .titleFont(18)
                    .kerning(6)
                    .foregroundColor(Brand.accentOrange)

                TypewriterLabel(L10n.cleanScanningHint, speed: 0.05)

                HStack(spacing: 24) {
                    DataRow(label: L10n.cleanSections, value: "\(progress.currentItem)")
                    DataRow(label: L10n.cleanElapsed, value: "\(progress.elapsedSeconds)s")
                }

                // Current path being scanned
                Text(progress.currentPath)
                    .monoFont(9)
                    .foregroundColor(Brand.textDim.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)
            }

            ProgressGlow(progress: min(0.3 + Double(progress.elapsedSeconds) * 0.02, 0.9))
                .frame(width: 200)

            // Action buttons
            HStack(spacing: 12) {
                // Stop — preserve scanned results
                Button(action: { vm.stopScan() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text(L10n.cleanStop)
                            .monoFont(10)
                    }
                    .foregroundColor(Brand.accentOrange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Brand.accentOrange, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Cancel — discard everything
                Button(action: { vm.cancelScan() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                        Text(L10n.cleanCancel)
                            .monoFont(10)
                    }
                    .foregroundColor(Brand.textDim)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Brand.lineColor, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        ErrorBanner(message: message) { vm.errorMessage = nil }
    }
}

#Preview("Idle") {
    CleanView()
        .frame(width: 900, height: 640)
}
