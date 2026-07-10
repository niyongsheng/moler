import SceneKit
import AppKit

private final class SimpleNoise {
    private var perm: [Int] = (0..<256).shuffled()
    private let grad3: [(Double, Double, Double)] = [
        (1,1,0),(-1,1,0),(1,-1,0),(-1,-1,0),
        (1,0,1),(-1,0,1),(1,0,-1),(-1,0,-1),
        (0,1,1),(0,-1,1),(0,1,-1),(0,-1,-1),
    ]
    init(seed: String) {
        var h = 0
        for c in seed.utf8 { h = h &* 31 &+ Int(c) }
        perm = (0..<256).map { ($0 &+ h) & 255 }.shuffled()
    }
    private func fade(_ t: Double) -> Double { t*t*t*(t*(t*6-15)+10) }
    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a+(b-a)*t }
    func noise3D(_ x: Double, _ y: Double, _ z: Double) -> Double {
        let X = Int(floor(x))&255; let Y = Int(floor(y))&255; let Z = Int(floor(z))&255
        let fx = x-floor(x); let fy = y-floor(y); let fz = z-floor(z)
        let u = fade(fx); let v = fade(fy); let w = fade(fz)
        func h(_ x: Int, _ y: Int, _ z: Int) -> Int { perm[(perm[(perm[x&255]&+y)&255]&+z)&255] }
        func g(_ h: Int, _ dx: Double, _ dy: Double, _ dz: Double) -> Double {
            let g = grad3[h%12]; return g.0*dx + g.1*dy + g.2*dz
        }
        let n0 = g(h(X,Y,Z), fx, fy, fz); let n1 = g(h(X+1,Y,Z), fx-1, fy, fz)
        let nx0 = lerp(n0, n1, u)
        let n2 = g(h(X,Y+1,Z), fx, fy-1, fz); let n3 = g(h(X+1,Y+1,Z), fx-1, fy-1, fz)
        let nx1 = lerp(n2, n3, u); let ny0 = lerp(nx0, nx1, v)
        let n4 = g(h(X,Y,Z+1), fx, fy, fz-1); let n5 = g(h(X+1,Y,Z+1), fx-1, fy, fz-1)
        let nx2 = lerp(n4, n5, u)
        let n6 = g(h(X,Y+1,Z+1), fx, fy-1, fz-1); let n7 = g(h(X+1,Y+1,Z+1), fx-1, fy-1, fz-1)
        let nx3 = lerp(n6, n7, u); let ny1 = lerp(nx2, nx3, v)
        return lerp(ny0, ny1, w)
    }
}

// MARK: -

final class EarthScene: SCNScene {
    let interactionNode = SCNNode()
    let spinNode = SCNNode()
    let leoGroup = SCNNode()
    let moonOrbitGroup = SCNNode()
    let cameraNode = SCNNode()
    var targetZoom: CGFloat = 25

    // MARK: - Reactive animation (driven by AnalyzeView state)
    /// 0 = idle, 1 = scanning full speed — read directly in animate(at:)
    var animationIntensity: CGFloat = 0

    func updateForScanning(_ isScanning: Bool) {
        let wasScanning = animationIntensity > 0
        animationIntensity = isScanning ? 1.0 : 0.0
        targetZoom = isScanning ? 35 : 25
        // Toggle wireframe visibility as a visible indicator of scanning state
        if isScanning {
            background.contents = NSColor.clear
        }
        if isScanning {
            interactionNode.eulerAngles.x = 0.4
        } else if wasScanning {
            interactionNode.eulerAngles.x = 0.4
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.interactionNode.eulerAngles.x = 0.2
            }
        } else {
            interactionNode.eulerAngles.x = 0.2
        }
    }

    private struct Moon { let orbitNode: SCNNode; let bodyNode: SCNNode; let speed: CGFloat; var angle: CGFloat }
    private var moon: Moon?
    private struct LEO { let orbitNode: SCNNode; let bodyNode: SCNNode; let speed: CGFloat; var angle: CGFloat }
    private var leoSats: [LEO] = []
    private var lastTime: TimeInterval = 0

    override init() { super.init(); setupScene() }
    required init?(coder: NSCoder) { super.init(coder: coder); setupScene() }

    private func setupScene() {
        background.contents = NSColor.clear
        let cam = SCNCamera()
        cam.zNear = 0.1; cam.zFar = 200; cam.fieldOfView = 35
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 1, 25)
        rootNode.addChildNode(cameraNode)
        rootNode.addChildNode(interactionNode)
        interactionNode.eulerAngles.x = 0.2
        let tilt = SCNNode()
        tilt.eulerAngles.z = 23.44 * (.pi / 180)
        interactionNode.addChildNode(tilt)
        tilt.addChildNode(spinNode)
        tilt.addChildNode(leoGroup)
        moonOrbitGroup.eulerAngles.z = 5.14 * (.pi / 180)
        interactionNode.addChildNode(moonOrbitGroup)
        buildEarth(); buildWireframe(); buildLEO(); buildMoon()
    }

    private func buildEarth() {
        let noise = SimpleNoise(seed: "terra-firma")
        let count = 12_000
        var p = [Float](repeating: 0, count: count*3)
        var c = [Float](repeating: 0, count: count*3)
        let colBase = SIMD3<Float>(0.24, 0.42, 0.28)
        let colHigh = SIMD3<Float>(0.60, 0.75, 0.54)
        let colPeak = SIMD3<Float>(1.0, 1.0, 1.0)
        var idx = 0
        let colOcean = SIMD3<Float>(0.10, 0.17, 0.29)
        while idx < count {
            let theta = Double.random(in: 0...(2 * .pi))
            let phi = acos(2 * Double.random(in: 0...1) - 1)
            let x = 5.0 * sin(phi) * cos(theta)
            let y = 5.0 * cos(phi)
            let z = 5.0 * sin(phi) * sin(theta)
            var n = noise.noise3D(x*0.15, y*0.15, z*0.15) * 1.2
            n += noise.noise3D(x*0.6, y*0.6, z*0.6) * 0.25
            let isLand = n > 0.1
            let r: Double
            let cc: SIMD3<Float>
            let v = Float.random(in: 0.88...1.12)
            if isLand {
                let h = (n - 0.1) * 1.2
                let relief = min(h, 0.5) / 0.5
                r = 5.0 + max(0, h) * 0.06
                if relief < 0.5 {
                    let t = Float(relief / 0.5)
                    cc = colBase * (1 - t) + colHigh * t
                } else {
                    let t = Float((relief - 0.5) / 0.5)
                    cc = colHigh * (1 - t) + colPeak * t
                }
            } else {
                // Keep only ~15% of ocean particles for sparse sea
                if Double.random(in: 0...1) < 0.85 { continue }
                r = 5.0
                cc = colOcean
            }
            p[idx*3]   = Float(r * sin(phi) * cos(theta))
            p[idx*3+1] = Float(r * cos(phi))
            p[idx*3+2] = Float(r * sin(phi) * sin(theta))
            c[idx*3]   = min(1, max(0, cc.x*v))
            c[idx*3+1] = min(1, max(0, cc.y*v))
            c[idx*3+2] = min(1, max(0, cc.z*v))
            idx += 1
        }
        spinNode.addChildNode(SCNNode(geometry: makeGeo(positions: p, colors: c, count: idx, pointSize: 1.5)))
    }

    private func buildWireframe() {
        let w = SCNBox(width: 10.02, height: 10.02, length: 10.02, chamferRadius: 5.01)
        w.widthSegmentCount = 24; w.heightSegmentCount = 16; w.lengthSegmentCount = 24
        let m = SCNMaterial()
        m.diffuse.contents = NSColor(calibratedRed: 0.23, green: 0.31, blue: 0.42, alpha: 0.06)
        m.isDoubleSided = true
        w.materials = [m]
        spinNode.addChildNode(SCNNode(geometry: w))
    }

    private func buildLEO() {
        let configs: [(r: Float, spd: Float, inc: Float, col: NSColor)] = [
            (6.0, 0.005, 0, NSColor.white),
            (6.5, -0.003, .pi/2, NSColor(calibratedRed: 0.878, green: 0.384, blue: 0.212, alpha: 1)),
            (5.8, 0.006, .pi/4, NSColor(calibratedRed: 0.184, green: 0.298, blue: 0.475, alpha: 1)),
            (7.0, 0.002, -.pi/6, NSColor(white: 0.8, alpha: 1)),
        ]
        for c in configs {
            let ring = SCNTorus(ringRadius: CGFloat(c.r), pipeRadius: 0.01)
            ring.ringSegmentCount = 64
            let rm = SCNMaterial()
            rm.diffuse.contents = c.col.withAlphaComponent(0.12)
            rm.isDoubleSided = true
            ring.materials = [rm]
            let rn = SCNNode(geometry: ring)
            rn.eulerAngles.x = .pi/2 + CGFloat(c.inc)
            leoGroup.addChildNode(rn)
            let box = SCNBox(width: 0.08, height: 0.04, length: 0.04, chamferRadius: 0.01)
            let bm = SCNMaterial()
            bm.diffuse.contents = c.col
            box.materials = [bm]
            let bn = SCNNode(geometry: box)
            bn.position = SCNVector3(c.r, 0, 0)
            let on = SCNNode()
            on.eulerAngles.x = CGFloat(c.inc)
            on.addChildNode(bn)
            leoGroup.addChildNode(on)
            leoSats.append(LEO(orbitNode: on, bodyNode: bn, speed: CGFloat(c.spd), angle: CGFloat.random(in: 0...(2 * .pi))))
        }
    }

    private func buildMoon() {
        let noise = SimpleNoise(seed: "luna"); let cnt = 1_200
        var p = [Float](repeating: 0, count: cnt*3)
        var c = [Float](repeating: 0, count: cnt*3)
        let maria = SIMD3<Float>(0.12, 0.14, 0.17)
        let high = SIMD3<Float>(0.90, 0.91, 0.92)
        let rego = SIMD3<Float>(0.48, 0.49, 0.52)
        for i in 0..<cnt {
            let th = Double.random(in: 0...(2 * .pi))
            let ph = acos(2 * Double.random(in: 0...1) - 1)
            let r = 0.8 * (0.98 + Double.random(in: 0...0.04))
            p[i*3]   = Float(r * sin(ph) * cos(th))
            p[i*3+1] = Float(r * cos(ph))
            p[i*3+2] = Float(r * sin(ph) * sin(th))
            let nv = noise.noise3D(Double(p[i*3])*3, Double(p[i*3+1])*3, Double(p[i*3+2])*3)
            let v = Float.random(in: 0.85...1.15)
            var ccol = SIMD3<Float>(0.5, 0.5, 0.5)
            if nv < 0.45 { let t = Float((nv+0.5)/0.95); ccol = maria*(1-t) + rego*t }
            else { let t = Float((nv-0.45)/0.55); ccol = rego*(1-t) + high*t }
            c[i*3]   = min(1, max(0, ccol.x*v))
            c[i*3+1] = min(1, max(0, ccol.y*v))
            c[i*3+2] = min(1, max(0, ccol.z*v))
        }
        let geo = makeGeo(positions: p, colors: c, count: cnt)
        let body = SCNNode(geometry: geo)
        let w = SCNBox(width: 1.6, height: 1.6, length: 1.6, chamferRadius: 0.8)
        w.widthSegmentCount = 16; w.heightSegmentCount = 16; w.lengthSegmentCount = 16
        let wm = SCNMaterial()
        wm.diffuse.contents = NSColor(calibratedRed: 0.36, green: 0.43, blue: 0.49, alpha: 0.12)
        wm.isDoubleSided = true
        w.materials = [wm]
        body.addChildNode(SCNNode(geometry: w))
        let orb = SCNTorus(ringRadius: 8.5, pipeRadius: 0.015)
        orb.ringSegmentCount = 96
        let om = SCNMaterial()
        om.diffuse.contents = NSColor(white: 0.67, alpha: 0.08)
        om.isDoubleSided = true
        orb.materials = [om]
        let on = SCNNode(geometry: orb)
        on.eulerAngles.x = .pi / 2
        moonOrbitGroup.addChildNode(on)
        let mc = SCNNode()
        mc.addChildNode(body)
        body.position = SCNVector3(8.5, 0, 0)
        moonOrbitGroup.addChildNode(mc)
        let sn = SCNNode()
        body.addChildNode(sn)
        moon = Moon(orbitNode: mc, bodyNode: sn, speed: 0.0035, angle: CGFloat.random(in: 0...(2 * .pi)))
    }

    private func makeGeo(positions: [Float], colors: [Float], count: Int, pointSize: Float = 1.5, opacity: Float = 1) -> SCNGeometry {
        let pd = Data(bytes: positions, count: count*3*4)
        let cd = Data(bytes: colors, count: count*3*4)
        let ps = SCNGeometrySource(data: pd, semantic: .vertex, vectorCount: count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
        let cs = SCNGeometrySource(data: cd, semantic: .color, vectorCount: count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
        let el = SCNGeometryElement(data: nil, primitiveType: .point, primitiveCount: count, bytesPerIndex: 0)
        let g = SCNGeometry(sources: [ps, cs], elements: [el])
        let m = SCNMaterial()
        m.isDoubleSided = true
        m.writesToDepthBuffer = opacity >= 1
        if opacity < 1 { m.transparency = CGFloat(opacity); m.transparencyMode = .dualLayer }
        m.shaderModifiers = [.geometry: "#pragma body\n_geometry.pointSize = \(pointSize);"]
        g.materials = [m]
        return g
    }

    func animate(at time: TimeInterval) {
        if lastTime == 0 { lastTime = time; return }
        let dt = min(time-lastTime, 0.05)
        lastTime = time
        let d = CGFloat(dt)
        let cz = cameraNode.position.z
        let df = targetZoom - CGFloat(cz)
        if abs(df) > 0.01 { cameraNode.position.z = cz + df * min(1, CGFloat(dt)*4) }

        // Camera lateral sway during scanning (gentle orbit feel)
        if animationIntensity > 0 {
            cameraNode.position.x = sin(time * 0.5) * animationIntensity * 1.5
        } else {
            cameraNode.position.x = 0
        }

        // Earth spins faster during scanning: idle 0.09 → scanning 0.9 rad/s (10x)
        let spinSpeed = 0.09 * (1.0 + animationIntensity * 9.0)
        spinNode.eulerAngles.y += d * spinSpeed

        let speedBoost = 1.0 + animationIntensity * 2.0
        for i in 0..<leoSats.count {
            leoSats[i].angle += leoSats[i].speed * d * 60 * speedBoost
            leoSats[i].orbitNode.eulerAngles.y = leoSats[i].angle
            leoSats[i].bodyNode.eulerAngles.x += d * 1.2
            leoSats[i].bodyNode.eulerAngles.y += d * 1.8
        }
        if var m = moon {
            m.angle += m.speed * d * 60 * speedBoost
            m.orbitNode.eulerAngles.y = m.angle
            m.bodyNode.eulerAngles.y = -m.angle
            moon = m
        }
    }
}

extension EarthScene: SCNSceneRendererDelegate {
    func renderer(_: SCNSceneRenderer, updateAtTime time: TimeInterval) { animate(at: time) }
}
