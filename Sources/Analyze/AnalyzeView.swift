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
    var body: some View {
        SceneKitEarthView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SceneKit NSViewRepresentable

struct SceneKitEarthView: NSViewRepresentable {
    typealias NSViewType = EarthSCNView

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

        return scnView
    }

    func updateNSView(_ nsView: EarthSCNView, context: Context) {}

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
