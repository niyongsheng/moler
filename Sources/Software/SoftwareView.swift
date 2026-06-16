import SwiftUI
import SceneKit

final class MarsSCNView: SCNView {
    override var mouseDownCanMoveWindow: Bool { false }
    weak var sceneRef: MarsScene?
    override func scrollWheel(with event: NSEvent) {
        guard let s = sceneRef else { return }
        s.targetZoom = max(15, min(60, s.targetZoom - event.scrollingDeltaY * 0.4))
    }
}

struct SoftwareView: View {
    var body: some View {
        SceneKitMarsView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SceneKitMarsView: NSViewRepresentable {
    typealias NSViewType = MarsSCNView
    func makeNSView(context: Context) -> MarsSCNView {
        let scene = MarsScene(); let v = MarsSCNView()
        v.scene = scene; v.backgroundColor = .clear; v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X; v.delegate = scene; v.loops = true; v.isPlaying = true
        v.sceneRef = scene
        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        v.addGestureRecognizer(pan); context.coordinator.scene = scene; return v
    }
    func updateNSView(_: MarsSCNView, context: Context) {}
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
