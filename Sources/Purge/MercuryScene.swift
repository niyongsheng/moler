import SceneKit
import AppKit
import SwiftUI

// MARK: - Simplex noise (reused from MarsScene)

private final class MSNoise {
    private var perm: [Int]
    private let grad3: [(Double,Double,Double)] = [
        (1,1,0),(-1,1,0),(1,-1,0),(-1,-1,0),
        (1,0,1),(-1,0,1),(1,0,-1),(-1,0,-1),
        (0,1,1),(0,-1,1),(0,1,-1),(0,-1,-1),
    ]
    init(seed:String){var h=0;for c in seed.utf8{h=h&*31&+Int(c)};perm=(0..<256).map{($0&+h)&255}.shuffled()}
    private func fade(_ t:Double)->Double{t*t*t*(t*(t*6-15)+10)}
    private func lerp(_ a:Double,_ b:Double,_ t:Double)->Double{a+(b-a)*t}
    func noise3D(_ x:Double,_ y:Double,_ z:Double)->Double{
        let X=Int(floor(x))&255,Y=Int(floor(y))&255,Z=Int(floor(z))&255
        let fx=x-floor(x),fy=y-floor(y),fz=z-floor(z),u=fade(fx),v=fade(fy),w=fade(fz)
        func h(_ x:Int,_ y:Int,_ z:Int)->Int{perm[(perm[(perm[x&255]&+y)&255]&+z)&255]}
        func g(_ h:Int,_ dx:Double,_ dy:Double,_ dz:Double)->Double{let g=grad3[h%12];return g.0*dx+g.1*dy+g.2*dz}
        let n0=g(h(X,Y,Z),fx,fy,fz),n1=g(h(X+1,Y,Z),fx-1,fy,fz),nx0=lerp(n0,n1,u)
        let n2=g(h(X,Y+1,Z),fx,fy-1,fz),n3=g(h(X+1,Y+1,Z),fx-1,fy-1,fz),nx1=lerp(n2,n3,u),ny0=lerp(nx0,nx1,v)
        let n4=g(h(X,Y,Z+1),fx,fy,fz-1),n5=g(h(X+1,Y,Z+1),fx-1,fy,fz-1),nx2=lerp(n4,n5,u)
        let n6=g(h(X,Y+1,Z+1),fx,fy-1,fz-1),n7=g(h(X+1,Y+1,Z+1),fx-1,fy-1,fz-1),nx3=lerp(n6,n7,u),ny1=lerp(nx2,nx3,v)
        return lerp(ny0,ny1,w)
    }
}

// MARK: -

final class MercuryScene: SCNScene {
    let interactionNode = SCNNode()
    let spinNode = SCNNode()
    let cameraNode = SCNNode()
    var targetZoom: CGFloat = 38

    /// 0 = idle, 1 = scanning full speed
    var animationIntensity: CGFloat = 0

    func updateForScanning(_ isScanning: Bool) {
        animationIntensity = isScanning ? 1.0 : 0.0
        targetZoom = isScanning ? 45 : 38
        interactionNode.eulerAngles.x = isScanning ? 0.35 : 0.2
    }

    private var lastTime: TimeInterval = 0

    override init() { super.init(); setupScene() }
    required init?(coder: NSCoder) { super.init(coder: coder); setupScene() }

    private func setupScene() {
        background.contents = NSColor.clear
        let cam = SCNCamera(); cam.zNear = 0.1; cam.zFar = 200; cam.fieldOfView = 35
        cameraNode.camera = cam; cameraNode.position = SCNVector3(0, 1, 38)
        rootNode.addChildNode(cameraNode)
        rootNode.addChildNode(interactionNode); interactionNode.eulerAngles.x = 0.2
        tiltNode.eulerAngles.z = 0.03 * (.pi / 180) // Mercury's tiny axial tilt
        interactionNode.addChildNode(tiltNode)
        tiltNode.addChildNode(spinNode)
        buildSurface()
        buildTail()
    }

    private let calorisRimNode = SCNNode()
    private let tiltNode = SCNNode()

    private func buildSurface() {
        let noise = MSNoise(seed: "mercury-surface")
        let count = 5_500
        var p = [Float](repeating: 0, count: count * 3)
        var c = [Float](repeating: 0, count: count * 3)

        // Mercury gray tones
        let colBase = SIMD3<Float>(0.58, 0.56, 0.52)       // #948f84
        let colDark = SIMD3<Float>(0.38, 0.36, 0.33)       // #615c54
        let colLight = SIMD3<Float>(0.72, 0.70, 0.66)      // #b7b2a8

        // Caloris Basin — warm golden tan interior, highly visible
        let colCaloris = SIMD3<Float>(0.92, 0.82, 0.58)    // bright gold #ebd194

        // Caloris Basin center (upper-right quadrant, always visible)
        let basinTheta: Double = 3.8
        let basinPhi: Double = 1.0
        let basinRadius: Double = 0.55

        // Bias: allocate ~15% of particles to the basin region for density
        let basinPct = 0.06
        var idx = 0
        while idx < count {
            let isBasinBiased = Double.random(in: 0...1) < basinPct
            let theta: Double, phi: Double
            if isBasinBiased {
                // Concentrate sampling inside the basin
                let r = sqrt(Double.random(in: 0...1)) * basinRadius * 0.9
                let a = Double.random(in: 0...(2 * .pi))
                theta = basinTheta + r * cos(a)
                phi = basinPhi + r * sin(a) * 0.6
            } else {
                theta = Double.random(in: 0...(2 * .pi))
                phi = acos(2 * Double.random(in: 0...1) - 1)
            }

            let x = 5.0 * sin(phi) * cos(theta)
            let y = 5.0 * cos(phi)
            let z = 5.0 * sin(phi) * sin(theta)

            let dTheta = abs(theta - basinTheta)
            let dPhi = abs(phi - basinPhi)
            let angDist = sqrt(dTheta * dTheta + dPhi * dPhi)
            let inBasin = angDist < basinRadius

            let nBase = noise.noise3D(x * 0.25, y * 0.25, z * 0.25)
            let nDetail = noise.noise3D(x * 0.8, y * 0.8, z * 0.8)
            let nCrater = abs(noise.noise3D(x * 2.0, y * 2.0, z * 2.0))

            let craterDepth = nCrater < 0.3 ? (0.3 - nCrater) * 0.12 : 0.0
            let isCraterRim = nCrater > 0.7 && nCrater < 0.85

            // Basin elevation
            let basinFloor = inBasin ? 0.04 : 0.0

            let h = nBase * 0.025 + nDetail * 0.01 - craterDepth + basinFloor
            let r = 5.0 + h
            p[idx * 3] = Float(r * sin(phi) * cos(theta))
            p[idx * 3 + 1] = Float(r * cos(phi))
            p[idx * 3 + 2] = Float(r * sin(phi) * sin(theta))

            let v = Float.random(in: 0.92...1.08)
            var cc: SIMD3<Float>
            if inBasin {
                // Warm golden interior
                let distFromCenter = Float(angDist / basinRadius)
                let edgeFade = max(0, 1 - distFromCenter * distFromCenter)
                cc = colCaloris * edgeFade + colLight * (1 - edgeFade) * 0.5
            } else if isCraterRim {
                cc = SIMD3<Float>(0.80, 0.78, 0.74)
            } else if nBase > 0.3 || nDetail > 0.2 {
                cc = colLight * 0.6 + colBase * 0.4
            } else if nCrater > 0.4 {
                cc = colDark
            } else {
                cc = colBase
            }
            c[idx * 3] = min(1, max(0, cc.x * v))
            c[idx * 3 + 1] = min(1, max(0, cc.y * v))
            c[idx * 3 + 2] = min(1, max(0, cc.z * v))
            idx += 1
        }

        spinNode.addChildNode(SCNNode(geometry: makeGeo(p: p, col: c, count: idx)))
        buildCalorisRim()
        buildWireframe()
    }

    // MARK: - Caloris Rim Ring (separate bright particle ring)

    private func buildCalorisRim() {
        let rc = 80
        var p = [Float](repeating: 0, count: rc * 3)
        var col = [Float](repeating: 0, count: rc * 3)
        let basinTheta: Double = 3.8, basinPhi: Double = 1.0, rimR: Double = 0.50

        for i in 0..<rc {
            let a = Double.random(in: 0...(2 * .pi))
            let theta = basinTheta + rimR * cos(a)
            let phi = basinPhi + rimR * sin(a) * 0.6
            let h = Double.random(in: 0.02...0.06)
            let r = 5.0 + h
            p[i * 3]     = Float(r * sin(phi) * cos(theta))
            p[i * 3 + 1] = Float(r * cos(phi))
            p[i * 3 + 2] = Float(r * sin(phi) * sin(theta))
            let b = Float.random(in: 0.50...0.65)
            col[i * 3]     = b
            col[i * 3 + 1] = b * 0.92
            col[i * 3 + 2] = b * 0.80
        }
        let node = SCNNode(geometry: makeGeo(p: p, col: col, count: rc, ps: 2.0, opacity: 0.3))
        calorisRimNode.addChildNode(node)
        spinNode.addChildNode(calorisRimNode)
    }

    private func buildWireframe() {
        let w = SCNBox(width: 10.02, height: 10.02, length: 10.02, chamferRadius: 5.01)
        w.widthSegmentCount = 24; w.heightSegmentCount = 16; w.lengthSegmentCount = 24
        let wm = SCNMaterial()
        wm.diffuse.contents = NSColor(calibratedRed: 0.45, green: 0.43, blue: 0.40, alpha: 0.06)
        wm.isDoubleSided = true
        w.materials = [wm]
        spinNode.addChildNode(SCNNode(geometry: w))
    }

    // MARK: - Sodium Tail

    private let tailNode = SCNNode()
    private var tailPhase: TimeInterval = 0

    private func buildTail() {
        let count = 1_200
        var p = [Float](repeating: 0, count: count * 3)
        var col = [Float](repeating: 0, count: count * 3)

        // Mercury's sodium tail: extremely diffuse, fan-shaped, blown by solar wind
        // Points in a fixed direction (away from "sun"), does NOT rotate with the planet
        for i in 0..<count {
            let dist = Double.random(in: 5.5...16.0)
            // Wide fan shape — spread grows with distance
            let spread = pow((dist - 5.5) / 11.0, 0.6) * 3.5
            let angle = Double.random(in: 0...(2 * .pi))
            let radius = spread * (0.5 + Double.random(in: 0...1.0))

            // Tail extends in -X, spreads in Y+Z as a wide cone
            p[i * 3]     = Float(-dist)
            p[i * 3 + 1] = Float(cos(angle) * radius * 0.6)
            p[i * 3 + 2] = Float(sin(angle) * radius)

            // Extremely faint sodium D-line glow
            let fade = max(0, 1.0 - (dist - 5.5) / 11.0)
            let intensity = Float(fade * fade * 0.35)
            let bright = Float.random(in: 0.5...1.0)
            col[i * 3]     = 1.0 * intensity * bright
            col[i * 3 + 1] = 0.55 * intensity * bright
            col[i * 3 + 2] = 0.15 * intensity * bright
        }

        let geo = makeGeo(p: p, col: col, count: count, ps: 3.0, opacity: 0.3)
        tailNode.addChildNode(SCNNode(geometry: geo))

        // Parent under tiltNode (matches planet orientation, no spin) — tail fixed direction
        tiltNode.addChildNode(tailNode)
    }

    private func makeGeo(p: [Float], col: [Float], count: Int, ps: Float = 1.5, opacity: Float = 1) -> SCNGeometry {
        let pd = Data(bytes: p, count: count * 3 * 4)
        let cd = Data(bytes: col, count: count * 3 * 4)
        let psrc = SCNGeometrySource(data: pd, semantic: .vertex, vectorCount: count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
        let csrc = SCNGeometrySource(data: cd, semantic: .color, vectorCount: count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
        let el = SCNGeometryElement(data: nil, primitiveType: .point, primitiveCount: count, bytesPerIndex: 0)
        let g = SCNGeometry(sources: [psrc, csrc], elements: [el])
        let m = SCNMaterial()
        m.isDoubleSided = true; m.writesToDepthBuffer = opacity >= 1
        if opacity < 1 { m.transparency = CGFloat(opacity); m.transparencyMode = .dualLayer }
        m.shaderModifiers = [.geometry: "#pragma body\n_geometry.pointSize = \(ps);"]
        g.materials = [m]
        return g
    }

    func animate(at time: TimeInterval) {
        if lastTime == 0 { lastTime = time; return }
        let dt = min(time - lastTime, 0.05); lastTime = time; let d = CGFloat(dt)

        // Camera zoom
        let cz = cameraNode.position.z; let df = targetZoom - CGFloat(cz)
        if abs(df) > 0.01 { cameraNode.position.z = cz + df * min(1, CGFloat(dt) * 4) }

        // Camera sway during scanning
        if animationIntensity > 0 {
            cameraNode.position.x = sin(time * 0.6) * animationIntensity * 1.2
        } else {
            cameraNode.position.x = 0
        }

        // Spin — idle 0.12 rad/s, scanning ~6x faster
        let speedMul = 1.0 + animationIntensity * 8.0
        spinNode.eulerAngles.y += d * 0.12 * speedMul

        // Sodium tail — gentle sway, brighten during scanning
        tailPhase += dt
        tailNode.eulerAngles.x = CGFloat(sin(tailPhase * 0.8) * 0.04)
        tailNode.eulerAngles.z = CGFloat(sin(tailPhase * 0.5 + 1.0) * 0.03)
        tailNode.opacity = 0.5 + 0.3 * CGFloat(animationIntensity) + 0.1 * CGFloat(sin(tailPhase * 1.5))
    }
}

extension MercuryScene: SCNSceneRendererDelegate {
    func renderer(_: SCNSceneRenderer, updateAtTime time: TimeInterval) { animate(at: time) }
}

// MARK: - Custom SCNView

final class MercurySCNView: SCNView {
    override var mouseDownCanMoveWindow: Bool { false }
    weak var sceneRef: MercuryScene?
    override func scrollWheel(with event: NSEvent) {
        guard let s = sceneRef else { return }
        s.targetZoom = max(25, min(70, s.targetZoom - event.scrollingDeltaY * 0.4))
    }
}

// MARK: - NSViewRepresentable

struct SceneKitMercuryView: NSViewRepresentable {
    typealias NSViewType = MercurySCNView
    let isScanning: Bool
    let isVisible: Bool

    init(isScanning: Bool = false, isVisible: Bool = true) {
        self.isScanning = isScanning; self.isVisible = isVisible
    }

    func makeNSView(context: Context) -> MercurySCNView {
        let scene = MercuryScene(); let v = MercurySCNView()
        v.scene = scene; v.backgroundColor = .clear; v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X; v.delegate = scene; v.loops = true
        v.isPlaying = isVisible || isScanning; v.sceneRef = scene
        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        v.addGestureRecognizer(pan); context.coordinator.scene = scene
        scene.updateForScanning(isScanning)
        return v
    }

    func updateNSView(_ nsView: MercurySCNView, context: Context) {
        nsView.isPlaying = isVisible || isScanning
        guard let scene = nsView.sceneRef else { return }
        scene.updateForScanning(isScanning)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var scene: MercuryScene?
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
