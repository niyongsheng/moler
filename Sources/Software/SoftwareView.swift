import SwiftUI
import SceneKit

// MARK: - Custom SCNView

final class MarsSCNView: SCNView {
    override var mouseDownCanMoveWindow: Bool { false }
    weak var sceneRef: MarsScene?
    override func scrollWheel(with event: NSEvent) {
        guard let s = sceneRef else { return }
        s.targetZoom = max(15, min(60, s.targetZoom - event.scrollingDeltaY * 0.4))
    }
}

// MARK: - Software Tab View

struct SoftwareView: View {
    @StateObject private var vm = SoftwareViewModel()

    private var isLoading: Bool {
        if case .loading = vm.state { return true }
        return false
    }

    var body: some View {
        ZStack {
            // 3D Mars background
            SceneKitMarsView(isLoading: isLoading)

            // Foreground UI
            content
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if let error = vm.errorMessage {
                errorBanner(error)
            }
        }
    }

    // MARK: - Content by State

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .error:
            idleView
        case .loading:
            loadingView
        case .loaded:
            loadedView
        case .running(let detail):
            runningView(detail)
        case .done(let result):
            SoftwareDoneView(result: result, onReset: { vm.reset() })
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Reticle(strokeColor: Brand.accentOrange.opacity(0.5), lineWidth: 0.5, armLength: 20)
                    .frame(width: 120, height: 120)

                Image(systemName: "gearshape.2")
                    .font(.system(size: 42))
                    .foregroundColor(Brand.accentOrange)
            }

            VStack(spacing: 6) {
                Text(L10n.softwareTitle)
                    .titleFont(28)
                    .kerning(8)
                    .foregroundColor(Brand.accentOrange)

                Text(L10n.softwareSubtitle)
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }

            GlassCard {
                VStack(spacing: Brand.unit * 2) {
                    DataRow(label: L10n.softwareLastScan, value: Store.shared.lastSoftwareDate?.formatted() ?? L10n.softwareNever)
                    DataRow(label: L10n.softwareTotalRemoved, value: "\(Store.shared.totalSoftwareRemoved)")
                }
            }
            .frame(maxWidth: 400)

            Button(action: { vm.loadAppList() }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(L10n.softwareScanApps)
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

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            PulseGlow()
                .frame(width: 24, height: 24)
            Text(L10n.softwareLoading)
                .titleFont(16)
                .kerning(4)
                .foregroundColor(Brand.accentOrange)
            Spacer()
        }
    }

    // MARK: - Running State

    private func runningView(_ detail: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            PulseGlow()
                .frame(width: 24, height: 24)
            Text(detail)
                .titleFont(16)
                .kerning(4)
                .foregroundColor(Brand.accentOrange)
            Spacer()
        }
    }

    // MARK: - Loaded State (App List)

    private var loadedView: some View {
        VStack(spacing: 0) {
            // Top bar: sort + search + refresh
            topBar
                .padding(.bottom, 8)

            // App list
            if vm.filteredApps.isEmpty {
                Spacer()
                Text(L10n.softwareNoApps)
                    .monoFont(12)
                    .foregroundColor(Brand.textDim)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(vm.filteredApps) { app in
                            AppRow(
                                app: app,
                                isSelected: vm.selected.contains(app.id),
                                isExpanded: vm.expandedAppID == app.id,
                                preview: vm.previews[app.id],
                                previewLoading: vm.previewLoading.contains(app.id),
                                pathSelections: vm.pathSelections[app.id] ?? [],
                                onToggle: { vm.toggleSelection(app.id) },
                                onExpand: { vm.toggleExpansion(app) },
                                onToggleFile: { path in vm.toggleFileSelection(appID: app.id, path: path) },
                                onSelectAll: { vm.selectAllFiles(appID: app.id) },
                                onDeselectAll: { vm.deselectAllFiles(appID: app.id) }
                            )
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            // Bottom bar
            if !vm.selected.isEmpty {
                bottomBar
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 8) {
            // Sort toggle
            Button(action: {
                if vm.sortByName { vm.sortByName = false; vm.sortAscending = false }
                else { vm.sortByName = true; vm.sortAscending = true }
            }) {
                HStack(spacing: 4) {
                    Text(vm.sortByName ? L10n.softwareSortedByName : L10n.softwareSortedBySize)
                        .monoFont(10)
                    Image(systemName: vm.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundColor(Brand.accentOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Brand.lineColor, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9))
                    .foregroundColor(Brand.textDim)
                TextField("", text: $vm.query)
                    .textFieldStyle(.plain)
                    .monoFont(10)
                    .foregroundColor(Brand.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Brand.bgCard.opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Brand.lineColor, lineWidth: 0.5))

            // Refresh
            Button(action: { vm.loadAppList() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundColor(Brand.textDim)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // App icons
            HStack(spacing: -4) {
                ForEach(vm.selectedApps.prefix(3)) { app in
                    Image(nsImage: SoftwareIcons.icon(for: app.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Brand.lineColor, lineWidth: 0.5))
                }
            }

            Text(vm.selectionLabel)
                .monoFont(10)
                .foregroundColor(Brand.textPrimary)

            Spacer()

            Button(action: { vm.clearSelection() }) {
                Text(L10n.softwareDeselectAll)
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }
            .buttonStyle(.plain)

            Button(action: { vm.confirmAndRemove() }) {
                Text(L10n.softwareRemove)
                    .monoFont(10)
                    .foregroundColor(Brand.accentOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Brand.accentOrange.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.accentOrange, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Brand.bgCard.opacity(0.8))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.lineColor, lineWidth: 0.5))
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        ErrorBanner(message: message) { vm.errorMessage = nil }
    }
}

// MARK: - App Row

struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let isExpanded: Bool
    let preview: UninstallPreview?
    let previewLoading: Bool
    let pathSelections: Set<String>
    let onToggle: () -> Void
    let onExpand: () -> Void
    let onToggleFile: (String) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 8) {
                Button(action: onExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(Brand.textDim)
                }
                .buttonStyle(.plain)

                Image(nsImage: SoftwareIcons.icon(for: app.path))
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .monoFont(11)
                        .foregroundColor(Brand.textPrimary)
                        .lineLimit(1)
                    Text(app.source)
                        .monoFont(8)
                        .foregroundColor(Brand.textDim)
                }

                Spacer()

                Text(app.sizeStr)
                    .monoFont(10)
                    .foregroundColor(Brand.accentGold)

                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? Brand.accentOrange : Brand.textDim)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Brand.accentOrange.opacity(0.06) : Color.clear)
            .cornerRadius(4)

            // Expanded preview
            if isExpanded {
                expandedContent
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if previewLoading {
            HStack {
                PulseGlow().frame(width: 8, height: 8)
                Text("Loading...")
                    .monoFont(9)
                    .foregroundColor(Brand.textDim)
                Spacer()
            }
            .padding(.leading, 48)
            .padding(.vertical, 4)
        } else if let preview {
            VStack(alignment: .leading, spacing: 4) {
                // Auto selected section
                let auto = preview.entries.filter(\.kind.autoSelected)
                if !auto.isEmpty {
                    sectionHeader(L10n.softwareAutoSelected, selected: auto.allSatisfy { pathSelections.contains($0.path) },
                                  onToggle: {
                        let allAuto = Set(auto.map(\.path))
                        let current = pathSelections
                        if allAuto.isSubset(of: current) {
                            onDeselectAll()
                        } else {
                            onSelectAll()
                        }
                    })
                    ForEach(auto) { entry in
                        fileRow(entry)
                    }
                }

                // Needs review section
                let review = preview.entries.filter { !$0.kind.autoSelected }
                if !review.isEmpty {
                    sectionHeader(L10n.softwareNeedsReview, selected: false, onToggle: {})
                    ForEach(review) { entry in
                        fileRow(entry)
                    }
                }
            }
            .padding(.leading, 48)
            .padding(.vertical, 4)
        }
    }

    private func sectionHeader(_ title: String, selected: Bool, onToggle: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .monoFont(8)
                .foregroundColor(Brand.textDim)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func fileRow(_ entry: UninstallPreview.Entry) -> some View {
        let isSel = pathSelections.contains(entry.path)
        return HStack(spacing: 4) {
            Button(action: { onToggleFile(entry.path) }) {
                Image(systemName: isSel ? "checkmark.square.fill" : "square")
                    .font(.system(size: 10))
                    .foregroundColor(isSel ? Brand.accentOrange : Brand.textDim)
            }
            .buttonStyle(.plain)

            Text(entry.path)
                .monoFont(8)
                .foregroundColor(Brand.textPrimary.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
        .padding(.vertical, 1)
    }
}

// MARK: - SceneKit NSViewRepresentable

struct SceneKitMarsView: NSViewRepresentable {
    typealias NSViewType = MarsSCNView
    let isLoading: Bool

    init(isLoading: Bool = false) {
        self.isLoading = isLoading
    }

    func makeNSView(context: Context) -> MarsSCNView {
        let scene = MarsScene(); let v = MarsSCNView()
        v.scene = scene; v.backgroundColor = .clear; v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X; v.delegate = scene; v.loops = true; v.isPlaying = true
        v.sceneRef = scene
        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        v.addGestureRecognizer(pan); context.coordinator.scene = scene
        scene.updateForLoading(isLoading)
        return v
    }

    func updateNSView(_ nsView: MarsSCNView, context: Context) {
        guard let scene = nsView.sceneRef else { return }
        scene.updateForLoading(isLoading)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var scene: MarsScene?
        private var last: CGPoint?; private var tx: CGFloat = 0.2; private var ty: CGFloat = 0
        @objc func handlePan(_ g: NSPanGestureRecognizer) {
            guard let s = scene else { return }; let loc = g.location(in: g.view)
            switch g.state {
            case .began: last = loc
            case .changed: guard let l = last else { return }
                tx = max(-0.8, min(1.2, tx + (loc.y - l.y) * 0.005)); ty += (loc.x - l.x) * 0.005
                s.interactionNode.eulerAngles = SCNVector3(tx, ty, 0); last = loc
            default: last = nil
            }
        }
    }
}
