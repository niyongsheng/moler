import SwiftUI
import SceneKit

// MARK: - Custom SCNView

final class EarthSCNView: SCNView {
    override var mouseDownCanMoveWindow: Bool { false }
    weak var sceneRef: EarthScene?

    override func scrollWheel(with event: NSEvent) {
        guard let scene = sceneRef else { return }
        let delta = -event.scrollingDeltaY * 0.4
        scene.targetZoom = max(10, min(60, scene.targetZoom + delta))
    }
}

// MARK: - Analyze Tab View

struct AnalyzeView: View {
    @StateObject private var vm = AnalyzeViewModel()

    private var isScanning: Bool {
        if case .scanning = vm.state { return true }
        return false
    }

    var body: some View {
        ZStack {
            // 3D background — driven by isScanning Bool
            SceneKitEarthView(isScanning: isScanning)

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
        case .scanning(let progress):
            scanningView(progress)
        case .loaded(let result, let breadcrumb):
            loadedView(result: result, breadcrumb: breadcrumb)
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Reticle(strokeColor: Brand.accentOrange.opacity(0.5), lineWidth: 0.5, armLength: 20)
                    .frame(width: 120, height: 120)

                Image(systemName: "chart.pie")
                    .font(.system(size: 42))
                    .foregroundColor(Brand.accentOrange)
            }

            VStack(spacing: 6) {
                Text(L10n.analyzeTitle)
                    .titleFont(28)
                    .kerning(8)
                    .foregroundColor(Brand.accentOrange)

                Text(L10n.analyzeSubtitle)
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }

            GlassCard {
                VStack(spacing: Brand.unit * 2) {
                    DataRow(label: L10n.analyzeLastScan, value: Store.shared.lastAnalyzePath)
                    DataRow(label: L10n.analyzeLastDate, value: Store.shared.lastAnalyzeDate?.formatted() ?? L10n.analyzeNever)
                    DataRow(label: L10n.analyzeTotalCount, value: "\(Store.shared.totalAnalyzeCount)")
                }
            }
            .frame(maxWidth: 400)

            // Scan target picker
            VStack(spacing: 12) {
                // Current path indicator
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                    Text(vm.selectedPath)
                        .monoFont(11)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .foregroundColor(Brand.accentOrange)

                // Preset pill buttons
                if !vm.scanPresets.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.scanPresets) { preset in
                                Button(action: { vm.selectPath(preset.path) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: preset.id)
                                            .font(.system(size: 10))
                                        Text(preset.label)
                                            .monoFont(10)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        vm.selectedPath == preset.path
                                            ? Brand.accentOrange.opacity(0.2)
                                            : Brand.bgCard
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(
                                                vm.selectedPath == preset.path
                                                    ? Brand.accentOrange : Brand.lineColor,
                                                lineWidth: vm.selectedPath == preset.path ? 1 : 0.5
                                            )
                                    )
                                    .foregroundColor(
                                        vm.selectedPath == preset.path
                                            ? Brand.accentOrange : Brand.textDim
                                    )
                                }
                                .buttonStyle(.plain)
                                .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxWidth: 400)
                }

                // Divider with OR
                HStack {
                    Brand.lineColor.frame(height: 0.5)
                    Text(L10n.analyzeOr)
                        .monoFont(9)
                        .foregroundColor(Brand.textDim)
                    Brand.lineColor.frame(height: 0.5)
                }
                .frame(maxWidth: 400)

                // Select folder button
                Button(action: {
                    Task {
                        if let path = await vm.pickFolder() {
                            vm.selectPath(path)
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 11))
                        Text(L10n.analyzeSelectFolder)
                            .monoFont(10)
                    }
                    .foregroundColor(Brand.textDim)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Brand.lineColor, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)

                // START SCAN button
                Button(action: { vm.startScan() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text(L10n.analyzeScanHome)
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
            }
            .frame(maxWidth: 400)

            Spacer()
        }
    }

    // MARK: - Scanning State

    private func scanningView(_ progress: AnalyzeProgress) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.pie")
                .font(.system(size: 42))
                .foregroundColor(Brand.accentOrange)

            VStack(spacing: 6) {
                Text(L10n.analyzeScanning)
                    .titleFont(18)
                    .kerning(6)
                    .foregroundColor(Brand.accentOrange)

                Text(progress.currentPath)
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)
            }

            ProgressGlow(progress: min(0.3 + Double(progress.elapsedSeconds) * 0.02, 0.9))
                .frame(width: 200)

            Button(action: { vm.cancel() }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                    Text(L10n.analyzeCancel)
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

            Spacer()
        }
    }

    // MARK: - Loaded State (Treemap + Sidebar)

    private func loadedView(result: DiskScanResult, breadcrumb: [BreadcrumbItem]) -> some View {
        HStack(spacing: 0) {
            // Sidebar
            AnalyzeSidebarView(
                result: result,
                breadcrumb: breadcrumb,
                onSelect: { entry in
                    if entry.isDir { vm.drillInto(entry: entry) }
                },
                onNavigate: { crumb in vm.navigateToCrumb(crumb) },
                onGoBack: { vm.goBack() }
            )

            // Treemap canvas
            TreemapCanvasView(
                entries: result.entries,
                onSelect: { entry in
                    guard entry.isDir, entry.id != "__other__" else { return }
                    if let fullEntry = result.entries.first(where: { $0.id == entry.id }) {
                        vm.drillInto(entry: fullEntry)
                    }
                },
                onRevealInFinder: { entry in
                    guard !entry.path.isEmpty else { return }
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: entry.path)
                }
            )
        }
        .padding(0)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        ErrorBanner(message: message) { vm.errorMessage = nil }
    }
}

// MARK: - SceneKit NSViewRepresentable

struct SceneKitEarthView: NSViewRepresentable {
    typealias NSViewType = EarthSCNView

    let isScanning: Bool

    func makeNSView(context: Context) -> EarthSCNView {
        let scene = EarthScene()
        let scnView = EarthSCNView()
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X
        scnView.delegate = scene
        scnView.loops = true
        scnView.isPlaying = true
        scnView.showsStatistics = false
        scnView.sceneRef = scene

        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(pan)
        context.coordinator.scene = scene

        apply(isScanning: isScanning, to: scene)

        return scnView
    }

    func updateNSView(_ nsView: EarthSCNView, context: Context) {
        guard let scene = nsView.sceneRef else { return }
        apply(isScanning: isScanning, to: scene)
    }

    private func apply(isScanning: Bool, to scene: EarthScene) {
        scene.updateForScanning(isScanning)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        weak var scene: EarthScene?
        private var lastLocation: CGPoint?
        private var tiltX: CGFloat = 0.2
        private var tiltY: CGFloat = 0

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let scene = scene else { return }
            let location = gesture.location(in: gesture.view)

            switch gesture.state {
            case .began:
                lastLocation = location
            case .changed:
                guard let last = lastLocation else { return }
                let dx = (location.x - last.x) * 0.005
                let dy = (location.y - last.y) * 0.005
                tiltX = max(-0.8, min(1.2, tiltX + dy))
                tiltY += dx
                scene.interactionNode.eulerAngles = SCNVector3(tiltX, tiltY, 0)
                lastLocation = location
            default:
                lastLocation = nil
            }
        }
    }
}
