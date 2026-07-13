import SwiftUI
import SceneKit

// MARK: - Custom SCNView that prevents window dragging & handles scroll-to-zoom

final class JupiterSCNView: SCNView {
    override var mouseDownCanMoveWindow: Bool { false }

    weak var sceneRef: JupiterScene?

    override func scrollWheel(with event: NSEvent) {
        guard let scene = sceneRef else { return }
        let delta = -event.scrollingDeltaY * 0.5
        scene.targetZoom = max(12, min(60, scene.targetZoom + delta))
    }
}

// MARK: - Optimize Tab View

struct OptimizeView: View {
    @StateObject private var vm = OptimizeViewModel()
    let isVisible: Bool

    init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }

    /// Current animation driving state derived from vm.state
    private var isAnimating: Bool {
        if case .running = vm.state { return true }
        return false
    }

    /// Non-idle states (running or done) trigger different scene behaviour
    private var scenePhase: ScenePhase {
        switch vm.state {
        case .running:   return .active
        case .done:      return .done
        default:         return .idle
        }
    }

    enum ScenePhase { case idle, active, done }

    var body: some View {
        ZStack {
            // 3D background — phase + tab visibility
            SceneKitJupiterView(scenePhase: scenePhase, isVisible: isVisible)

            // Foreground UI
            VStack(spacing: 0) {
                content
            }
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
        case .running(let progress):
            OptimizeRunView(
                progress: progress,
                onCancel: { vm.cancel() }
            )
        case .done(let result):
            OptimizeDoneView(
                result: result,
                onReset: { vm.reset() }
            )
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Central icon with reticle
            ZStack {
                Reticle(strokeColor: Brand.accentOrange.opacity(0.5), lineWidth: 0.5, armLength: 20)
                    .frame(width: 120, height: 120)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 42))
                    .foregroundColor(Brand.accentOrange)
            }

            // Title
            VStack(spacing: 6) {
                Text(L10n.optimizeTitle)
                    .titleFont(28)
                    .kerning(8)
                    .foregroundColor(Brand.accentOrange)

                Text(L10n.optimizeSubtitle)
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }

            // Stats from last optimize
            GlassCard {
                VStack(spacing: Brand.unit * 2) {
                    DataRow(label: L10n.optimizeLastRun, value: Store.shared.lastOptimizeDate?.formatted() ?? L10n.optimizeNever)
                    DataRow(label: L10n.optimizeTotalCount, value: "\(Store.shared.totalOptimizeCount)")
                    DataRow(label: L10n.optimizeTotalOpts, value: "\(Store.shared.lastOptimizeOptimizations)")
                }
            }
            .frame(maxWidth: 400)

            // Action buttons
            HStack(spacing: 16) {
                // Preview button
                Button(action: { vm.startPreview() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                        Text(L10n.optimizePreview)
                            .titleFont(14)
                            .kerning(6)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Brand.accentGold.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Brand.accentGold, lineWidth: 1)
                    )
                    .foregroundColor(Brand.accentGold)
                }
                .buttonStyle(.plain)

                // Optimize button
                Button(action: { vm.startOptimize() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(L10n.optimizeInitiate)
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

            Spacer()
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        ErrorBanner(message: message) { vm.errorMessage = nil }
    }
}

// MARK: - SceneKit NSViewRepresentable

struct SceneKitJupiterView: NSViewRepresentable {
    typealias NSViewType = JupiterSCNView

    /// Current scene animation phase — drives the Jupiter visual state.
    let scenePhase: OptimizeView.ScenePhase
    /// Whether the parent tab is currently active in RootView.
    let isVisible: Bool

    init(scenePhase: OptimizeView.ScenePhase, isVisible: Bool = true) {
        self.scenePhase = scenePhase
        self.isVisible = isVisible
    }

    func makeNSView(context: Context) -> JupiterSCNView {
        let scene = JupiterScene()
        let scnView = JupiterSCNView()
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X
        scnView.delegate = scene
        scnView.loops = true
        scnView.isPlaying = isVisible
        scnView.showsStatistics = false

        scnView.sceneRef = scene

        // Mouse drag for camera rotation
        let pan = NSPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        scnView.addGestureRecognizer(pan)
        context.coordinator.scene = scene

        // Apply initial phase
        apply(phase: scenePhase, to: scene)

        return scnView
    }

    func updateNSView(_ nsView: JupiterSCNView, context: Context) {
        nsView.isPlaying = isVisible || scenePhase == .active
        guard let scene = nsView.scene as? JupiterScene else { return }
        apply(phase: scenePhase, to: scene)
    }

    private func apply(phase: OptimizeView.ScenePhase, to scene: JupiterScene) {
        switch phase {
        case .active:
            scene.updateForRunning(true)
        case .done:
            scene.updateForRunning(false)
            scene.pulseDone()
        case .idle:
            scene.updateForRunning(false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

// MARK: - Coordinator (gesture handling)

final class Coordinator: NSObject {
    weak var scene: JupiterScene?
    private var lastLocation: CGPoint?
    private var tiltX: CGFloat = 0.15
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

#Preview("Idle") {
    OptimizeView()
        .frame(width: 900, height: 640)
}
