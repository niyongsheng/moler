import SwiftUI
import SceneKit

// MARK: - Custom SCNView that prevents window dragging & handles scroll‑to‑zoom

final class JupiterSCNView: SCNView {
    override var mouseDownCanMoveWindow: Bool { false }

    weak var sceneRef: JupiterScene?

    override func scrollWheel(with event: NSEvent) {
        guard let scene = sceneRef else { return }
        // Each scroll tick adjusts the target zoom.
        // event.scrollingDeltaY is positive = scroll up (zoom in).
        let delta = -event.scrollingDeltaY * 0.5
        scene.targetZoom = max(12, min(60, scene.targetZoom + delta))
    }
}

// MARK: - Optimize Tab View

struct OptimizeView: View {
    var body: some View {
        ZStack {
            SceneKitJupiterView()

            // Scanning in progress…
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SceneKit NSViewRepresentable

struct SceneKitJupiterView: NSViewRepresentable {
    typealias NSViewType = JupiterSCNView

    func makeNSView(context: Context) -> JupiterSCNView {
        let scene = JupiterScene()
        let scnView = JupiterSCNView()
        scnView.scene = scene
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X
        scnView.delegate = scene
        scnView.loops = true
        scnView.isPlaying = true
        scnView.showsStatistics = false

        scnView.sceneRef = scene      // for scroll‑wheel zoom

        // Mouse drag for camera rotation
        let pan = NSPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        scnView.addGestureRecognizer(pan)
        context.coordinator.scene = scene

        return scnView
    }

    func updateNSView(_ nsView: JupiterSCNView, context: Context) {}

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

// MARK: - Solar System Monitor Overlay (inspired by planetUi.js system monitor)

// Solar system monitor moved to Sources/Components/SystemMonitorOverlay.swift


