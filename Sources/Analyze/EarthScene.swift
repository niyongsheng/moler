import SceneKit
import AppKit

// MARK: -

/// Real-world coastline lookup backed by an equirectangular raster mask
/// (Natural Earth 1:50m land, public domain). Row 0 is +90° latitude,
/// column 0 is −180° longitude; white pixels are land.
private final class LandMask {
    private let width: Int
    private let height: Int
    private let pixels: [UInt8]

    init?() {
        guard let url = Bundle.main.url(forResource: "EarthLandMask", withExtension: "png"),
              let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return nil }

        var data = [UInt8](repeating: 0, count: w * h)
        let decoded = data.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress,
                                      width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return false }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard decoded else { return nil }

        width = w
        height = h
        pixels = data
    }

    func contains(latitude: Double, longitude: Double) -> Bool {
        var u = (longitude + 180.0) / 360.0
        u -= floor(u)
        let v = min(max((90.0 - latitude) / 180.0, 0.0), 0.999999)
        let x = min(width - 1, Int(u * Double(width)))
        let y = min(height - 1, Int(v * Double(height)))
        return pixels[y * width + x] > 127
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
        let noise = SeededNoise3D(seed: "terra-firma")
        let landMask = LandMask()
        let count = 24_000
        var p = [Float](repeating: 0, count: count*3)
        var c = [Float](repeating: 0, count: count*3)
        let colBase = SIMD3<Float>(0.30, 0.55, 0.36)
        let colHigh = SIMD3<Float>(0.62, 0.80, 0.55)
        let colPeak = SIMD3<Float>(0.88, 0.97, 0.82)
        let colIce = SIMD3<Float>(0.55, 0.66, 0.78)
        let colOcean = SIMD3<Float>(0.08, 0.13, 0.22)
        var idx = 0
        while idx < count {
            let theta = Double.random(in: 0...(2 * .pi))
            let phi = acos(2 * Double.random(in: 0...1) - 1)
            let x = 5.0 * sin(phi) * cos(theta)
            let y = 5.0 * cos(phi)
            let z = 5.0 * sin(phi) * sin(theta)

            // Noise now only drives terrain shading; the real coastline mask
            // decides what is land.
            var n = noise.noise3D(x*0.15, y*0.15, z*0.15) * 1.2
            n += noise.noise3D(x*0.6, y*0.6, z*0.6) * 0.25

            let lat = 90.0 - phi * 180.0 / .pi
            // The (x, z) = (cos θ, sin θ) embedding is left-handed with +Y
            // up, so sampling the map with +z mirrors the continents when
            // seen from outside. Using −z restores real-Earth east/west
            // (east is to the viewer's right when north is up).
            let lon = atan2(-z, x) * 180.0 / .pi
            let isLand = landMask?.contains(latitude: lat, longitude: lon) ?? (n > 0.1)

            let r: Double
            var cc: SIMD3<Float>
            let v = Float.random(in: 0.88...1.12)
            if isLand {
                let relief = Float(min(max((n + 0.05) / 0.75, 0), 1))
                r = 5.0 + Double(relief) * 0.05
                if relief < 0.55 {
                    let t = relief / 0.55
                    cc = colBase * (1 - t) + colHigh * t
                } else {
                    let t = (relief - 0.55) / 0.45
                    cc = colHigh * (1 - t) + colPeak * t
                }
                // Pale ice over the polar caps (Greenland, Antarctica, Arctic islands).
                let iceRaw = min(max((abs(lat) - 64.0) / 14.0, 0), 1)
                let ice = Float(iceRaw * iceRaw * (3 - 2 * iceRaw)) * 0.75
                cc = cc * (1 - ice) + colIce * ice
            } else {
                // Keep only ~10% of ocean particles for sparse sea
                if Double.random(in: 0...1) < 0.90 { continue }
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
        spinNode.addChildNode(SCNNode(geometry: PlanetGeometry.pointCloud(positions: p, colors: c, count: idx)))
    }

    private func buildWireframe() {
        let tint = NSColor(calibratedRed: 0.23, green: 0.31, blue: 0.42, alpha: 0.06)
        spinNode.addChildNode(SCNNode(geometry: PlanetGeometry.wireframe(tint: tint)))
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
        let noise = SeededNoise3D(seed: "luna"); let cnt = 1_200
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
        let geo = PlanetGeometry.pointCloud(positions: p, colors: c, count: cnt)
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
