import SceneKit
import AppKit

// MARK: - Jupiter particle scene (port of jupiter.js Three.js point cloud)

final class JupiterScene: SCNScene {
    // MARK: - Scene graph nodes
    let interactionNode = SCNNode()       // rotated by user drag
    let spinNode = SCNNode()              // planet self-rotation
    let atmosphereNode = SCNNode()        // atmospheric haze (separate rotation)
    let ringNode = SCNNode()              // dark ring assembly
    let redSpotNode = SCNNode()           // Great Red Spot drift container

    // MARK: - Camera
    let cameraNode = SCNNode()
    var targetZoom: CGFloat = 28

    // MARK: - Reactive animation properties

    /// Master animation intensity: 0 = idle, 1 = running full speed
    var animationIntensity: CGFloat = 0 {
        didSet { spinSpeedMultiplier = 1.0 + animationIntensity * 3.0 }
    }
    private var spinSpeedMultiplier: CGFloat = 1.0

    /// Camera zoom smoothing target (existing, reused here)
    /// - idle: 28  - running: 42 (pull back to see the whole system)

    /// Updates animation intensity based on the current Optimize state.
    func updateForRunning(_ isRunning: Bool) {
        animationIntensity = isRunning ? 1.0 : 0.0
        targetZoom = isRunning ? 42 : 28
    }

    /// Brief celebratory pulse when optimization completes.
    func pulseDone() {
        // Quick flash: spin up then settle
        animationIntensity = 0.3
        targetZoom = 26
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.animationIntensity = 0
            self?.targetZoom = 28
        }
    }

    // MARK: - Moon data
    private struct Moon {
        let node: SCNNode
        let orbitRadius: CGFloat
        let orbitSpeed: CGFloat
        var angle: CGFloat
        let spinNode: SCNNode
    }
    private var moons: [Moon] = []
    private var lastTime: TimeInterval = 0

    // MARK: - Init

    override init() {
        super.init()
        setupScene()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScene()
    }

    // MARK: - Scene setup

    private func setupScene() {
        background.contents = NSColor.clear

        // --- Camera ---
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 200
        camera.fieldOfView = 35
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 2, 28)
        rootNode.addChildNode(cameraNode)

        // --- Interaction container (draggable) ---
        rootNode.addChildNode(interactionNode)
        interactionNode.eulerAngles.x = 0.15

        // --- Axial tilt (Jupiter: 3.13°) ---
        let tiltNode = SCNNode()
        tiltNode.eulerAngles.z = 3.13 * (.pi / 180)
        interactionNode.addChildNode(tiltNode)

        // --- Self-rotation container ---
        tiltNode.addChildNode(spinNode)

        // --- GRS drift container (inside spin, slightly independent) ---
        spinNode.addChildNode(redSpotNode)

        // Build visual elements
        let planetBody = makePointCloud(
            count: 200,
            sphereRadius: 5.0,
            spread: 0.02,
            pointSize: 1.5,
            colorFn: planetParticleColor
        )
        spinNode.addChildNode(planetBody)

        buildAtmosphere()
        buildRings()
        buildGreatRedSpot()
        buildMoons(in: interactionNode)
    }

    // MARK: - Particle geometry factory

    private func makePointCloud(
        count: Int,
        sphereRadius: Double,
        spread: Double,
        pointSize: Float,
        opacity: Float = 1.0,
        additive: Bool = false,
        colorFn: (Double, Double, Double) -> (Float, Float, Float)
    ) -> SCNNode {
        var positions = [Float](repeating: 0, count: count * 3)
        var colors    = [Float](repeating: 0, count: count * 3)

        for i in 0..<count {
            let theta = Float.random(in: 0...(2 * .pi))
            let phi   = Float(acos(Double(2 * Float.random(in: 0...1) - 1)))
            let r     = sphereRadius + Double.random(in: -spread...spread)

            let x = Float(r) * sin(phi) * cos(theta)
            let y = Float(r) * cos(phi)
            let z = Float(r) * sin(phi) * sin(theta)

            positions[i * 3]     = x
            positions[i * 3 + 1] = y
            positions[i * 3 + 2] = z

            let lat = Double(y) / sphereRadius               // -1 … +1
            let v   = (lat + 1) / 2                          //  0 … +1  (0=south)
            let u   = Double(theta) / (2 * .pi)               // longitude 0…1
            let (cr, cg, cb) = colorFn(u, v, Double(phi))

            colors[i * 3]     = cr
            colors[i * 3 + 1] = cg
            colors[i * 3 + 2] = cb
        }

        let posData = Data(bytes: positions, count: positions.count * MemoryLayout<Float>.size)
        let colData = Data(bytes: colors,    count: colors.count    * MemoryLayout<Float>.size)

        let posSource = SCNGeometrySource(
            data: posData, semantic: .vertex,
            vectorCount: count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<Float>.size * 3
        )
        let colSource = SCNGeometrySource(
            data: colData, semantic: .color,
            vectorCount: count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<Float>.size * 3
        )

        let element = SCNGeometryElement(
            data: nil,
            primitiveType: .point,
            primitiveCount: count,
            bytesPerIndex: 0
        )

        let geometry = SCNGeometry(sources: [posSource, colSource], elements: [element])

        let mat = SCNMaterial()
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = opacity >= 1
        if opacity < 1 {
            mat.transparency = CGFloat(opacity)
            mat.transparencyMode = .dualLayer
        }
        if additive {
            mat.blendMode = .add
        }

        // Metal shader modifier for point size
        mat.shaderModifiers = [
            .geometry: """
            #pragma body
            _geometry.pointSize = \(pointSize);
            """
        ]
        geometry.materials = [mat]

        return SCNNode(geometry: geometry)
    }

    // MARK: - Jupiter band colour at normalised latitude v (0 = south, 1 = north)

    private func planetParticleColor(u: Double, v: Double, _ phi: Double) -> (Float, Float, Float) {
        struct BC { let v: Double; let r: Double; let g: Double; let b: Double }
        let bands: [BC] = [
            BC(v: 0.00, r: 0.40, g: 0.35, b: 0.33),
            BC(v: 0.06, r: 0.50, g: 0.38, b: 0.35),
            BC(v: 0.13, r: 0.78, g: 0.58, b: 0.45),
            BC(v: 0.22, r: 0.55, g: 0.40, b: 0.30),
            BC(v: 0.31, r: 0.82, g: 0.68, b: 0.55),
            BC(v: 0.40, r: 0.60, g: 0.45, b: 0.33),
            BC(v: 0.49, r: 0.92, g: 0.87, b: 0.80),
            BC(v: 0.58, r: 0.62, g: 0.50, b: 0.38),
            BC(v: 0.67, r: 0.82, g: 0.72, b: 0.60),
            BC(v: 0.76, r: 0.55, g: 0.40, b: 0.30),
            BC(v: 0.86, r: 0.78, g: 0.62, b: 0.50),
            BC(v: 0.94, r: 0.45, g: 0.38, b: 0.35),
            BC(v: 1.00, r: 0.38, g: 0.35, b: 0.33),
        ]

        // turbulence — sine waves distort latitude
        let turbV = v + 0.035 * sin(u * 14 + v * 6) + 0.018 * sin(u * 28 + v * 4 + 1.3)
        let cv = max(0.0, min(1.0, turbV))
        let bw = 0.06

        var tw = 0.0, rA = 0.0, gA = 0.0, bA = 0.0
        for b in bands {
            let d = cv - b.v
            let w = exp(-(d * d) / (2 * bw * bw))
            rA += b.r * w; gA += b.g * w; bA += b.b * w
            tw += w
        }
        guard tw > 0 else { return (0.7, 0.6, 0.5) }

        let grain = (Double.random(in: 0...1) - 0.5) * 0.04
        return (
            Float(max(0, min(1, rA / tw + grain))),
            Float(max(0, min(1, gA / tw + grain))),
            Float(max(0, min(1, bA / tw + grain)))
        )
    }

    // MARK: - Great Red Spot particle colour (inside GRS region)

    private func redSpotColor(u: Double, v: Double) -> (Float, Float, Float) {
        // longitude offset from GRS centre (u=0.5) and latitude offset from 22°S (v=0.38)
        let du = u - 0.5, dv = v - 0.38
        let d = (du * du) / (0.12 * 0.12) + (dv * dv) / (0.07 * 0.07)
        guard d < 1 else {
            // outside GRS — fall through to planet colour
            let (r, g, b) = planetParticleColor(u: u, v: v, 0.0)
            return (r, g, b)
        }

        let coreR: Double = 0.76, coreG: Double = 0.37, coreB: Double = 0.25
        let outerR: Double = 0.54, outerG: Double = 0.25, outerB: Double = 0.18
        let inner  = d < 0.3 ? (1 - d / 0.3) * 0.35 : 0
        let r = coreR * inner + outerR * (1 - inner)
        let g = coreG * inner + outerG * (1 - inner)
        let b = coreB * inner + outerB * (1 - inner)
        return (Float(r), Float(g), Float(b))
    }

    // MARK: - Atmosphere haze particle colour

    private func hazeColor(u: Double, v: Double, _ phi: Double) -> (Float, Float, Float) {
        (0.85, 0.80, 0.70)
    }

    // MARK: - Atmosphere (haze particle cloud)

    private func buildAtmosphere() {
        let node = makePointCloud(
            count: 3_000,
            sphereRadius: 5.15,
            spread: 0.15,
            pointSize: 2.0,
            opacity: 0.08,
            additive: true,
            colorFn: hazeColor
        )
        atmosphereNode.addChildNode(node)
        spinNode.addChildNode(atmosphereNode)
    }

    // MARK: - Dark ring system (planar particle cloud)

    private func buildRings() {
        let count = 4_000
        var positions = [Float](repeating: 0, count: count * 3)
        var colors    = [Float](repeating: 0, count: count * 3)

        for i in 0..<count {
            let t      = Double.random(in: 0...1)
            let radius = 11.0 + pow(t, 1.2) * 3.0       // 11 … 14
            let angle  = Double.random(in: 0...(2 * .pi))
            let x = Float(radius * cos(angle))
            let z = Float(radius * sin(angle))
            let y = Float.random(in: -0.06...0.06)

            positions[i * 3]     = x
            positions[i * 3 + 1] = y
            positions[i * 3 + 2] = z

            let bright = 0.12 + 0.08 * sin((radius - 11) / 3.0 * .pi)
            let a = Float.random(in: 0.6...1.4)
            let b = Float(bright)
            colors[i * 3]     = b * 0.3 * a
            colors[i * 3 + 1] = b * 0.25 * a
            colors[i * 3 + 2] = b * 0.2 * a
        }

        let posData = Data(bytes: positions, count: positions.count * MemoryLayout<Float>.size)
        let colData = Data(bytes: colors,    count: colors.count    * MemoryLayout<Float>.size)

        let posSource = SCNGeometrySource(
            data: posData, semantic: .vertex,
            vectorCount: count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<Float>.size * 3
        )
        let colSource = SCNGeometrySource(
            data: colData, semantic: .color,
            vectorCount: count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<Float>.size * 3
        )

        let element = SCNGeometryElement(data: nil, primitiveType: .point, primitiveCount: count, bytesPerIndex: 0)
        let geometry = SCNGeometry(sources: [posSource, colSource], elements: [element])

        let mat = SCNMaterial()
        mat.isDoubleSided = true
        mat.transparency = 0.5
        mat.transparencyMode = .dualLayer
        mat.writesToDepthBuffer = false
        mat.shaderModifiers = [
            .geometry: "#pragma body\n_geometry.pointSize = 2.0;"
        ]
        geometry.materials = [mat]

        let node = SCNNode(geometry: geometry)
        node.eulerAngles.x = -.pi / 2   // lay flat in XZ plane
        ringNode.addChildNode(node)
        spinNode.addChildNode(ringNode)
    }

    // MARK: - Great Red Spot (separate particle cloud for drift animation)

    private func buildGreatRedSpot() {
        let count = 1_500
        var positions = [Float](repeating: 0, count: count * 3)
        var colors    = [Float](repeating: 0, count: count * 3)
        let rBase = 5.0

        let spotLat = -22.0 * .pi / 180
        let spotLon = 0.5
        let w = 1.6, h = 1.0

        var idx = 0
        for _ in 0..<count {
            let t     = Double.random(in: 0...1)
            let dist  = pow(t, 0.6)
            let angle = Double.random(in: 0...(2 * .pi))

            // skip sparse outer fringe
            if dist > 0.8, Double.random(in: 0...1) > 0.4 { continue }

            let dLat = sin(angle) * dist * 0.22 * h
            let dLon = cos(angle) * dist * 0.22 * w

            let finalLat = spotLat + dLat
            let finalLon = spotLon + dLon

            let heightOffset = cos(dist * .pi / 2) * 0.06
            let r = rBase + heightOffset

            let x = Float(r * cos(finalLat) * sin(finalLon))
            let y = Float(r * sin(finalLat))
            let z = Float(r * cos(finalLat) * cos(finalLon))

            positions[idx * 3]     = x
            positions[idx * 3 + 1] = y
            positions[idx * 3 + 2] = z

            // colour — deep red/orange with brighter core
            let spiral = sin(dist * 10 + angle * 2)
            let (cr, cg, cb): (Double, Double, Double)
            if dist < 0.7 {
                cr = 0.54 + spiral * 0.1
                cg = 0.25 + spiral * 0.05
                cb = 0.18
            } else {
                let mf = (dist - 0.7) / 0.3
                cr = 0.54 * (1 - mf) + 0.35 * mf
                cg = 0.25 * (1 - mf) + 0.20 * mf
                cb = 0.18 * (1 - mf) + 0.15 * mf
            }
            let variation = 0.85 + Double.random(in: 0...1) * 0.3
            colors[idx * 3]     = Float(cr * variation)
            colors[idx * 3 + 1] = Float(cg * variation)
            colors[idx * 3 + 2] = Float(cb * variation)

            idx += 1
        }

        let actualCount = idx
        let posSlice = Array(positions[0..<(actualCount * 3)])
        let colSlice = Array(colors[0..<(actualCount * 3)])

        let posData = Data(bytes: posSlice, count: posSlice.count * MemoryLayout<Float>.size)
        let colData = Data(bytes: colSlice, count: colSlice.count * MemoryLayout<Float>.size)

        let posSource = SCNGeometrySource(
            data: posData, semantic: .vertex,
            vectorCount: actualCount, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<Float>.size * 3
        )
        let colSource = SCNGeometrySource(
            data: colData, semantic: .color,
            vectorCount: actualCount, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0, dataStride: MemoryLayout<Float>.size * 3
        )

        let element = SCNGeometryElement(data: nil, primitiveType: .point, primitiveCount: actualCount, bytesPerIndex: 0)
        let geometry = SCNGeometry(sources: [posSource, colSource], elements: [element])

        let mat = SCNMaterial()
        mat.isDoubleSided = true
        mat.shaderModifiers = [
            .geometry: "#pragma body\n_geometry.pointSize = 3.0;"
        ]
        geometry.materials = [mat]

        let node = SCNNode(geometry: geometry)
        redSpotNode.addChildNode(node)
    }

    // MARK: - Galilean moon system

    private func buildMoons(in parent: SCNNode) {
        let configs: [(name: String, distance: CGFloat, speed: CGFloat, size: CGFloat, color: NSColor)] = [
            ("Io",       8.5,  0.30, 0.28, NSColor(calibratedRed: 0.85, green: 0.72, blue: 0.35, alpha: 1)),
            ("Europa",  11.0,  0.20, 0.24, NSColor(calibratedRed: 0.75, green: 0.88, blue: 0.95, alpha: 1)),
            ("Ganymede",14.5,  0.14, 0.38, NSColor(calibratedRed: 0.55, green: 0.52, blue: 0.48, alpha: 1)),
            ("Callisto",19.0,  0.08, 0.34, NSColor(calibratedRed: 0.35, green: 0.33, blue: 0.30, alpha: 1)),
        ]

        for c in configs {
            let orbitNode = SCNNode()
            parent.addChildNode(orbitNode)

            let sphere = SCNSphere(radius: c.size)
            sphere.segmentCount = 16
            let mat = SCNMaterial()
            mat.diffuse.contents = c.color
            mat.specular.contents = NSColor(white: 0.3, alpha: 0.3)
            sphere.materials = [mat]
            let moonNode = SCNNode(geometry: sphere)
            moonNode.position = SCNVector3(c.distance, 0, 0)
            orbitNode.addChildNode(moonNode)

            // orbit ring
            let ring = SCNTorus(ringRadius: c.distance, pipeRadius: 0.015)
            ring.ringSegmentCount = 96
            let rm = SCNMaterial()
            rm.diffuse.contents = c.color.withAlphaComponent(0.08)
            rm.isDoubleSided = true
            ring.materials = [rm]
            let rn = SCNNode(geometry: ring)
            rn.eulerAngles.x = .pi / 2
            parent.addChildNode(rn)

            let spinNode = SCNNode()
            moonNode.addChildNode(spinNode)

            // particle detail
            let dc = 60
            var dp = [Float](repeating: 0, count: dc * 3)
            for i in 0..<dc {
                let t = Float.random(in: 0...(2 * .pi))
                let p = Float(acos(Double(2 * Float.random(in: 0...1) - 1)))
                let r = Float(c.size) * 0.85
                dp[i * 3]     = r * sin(p) * cos(t)
                dp[i * 3 + 1] = r * sin(p) * sin(t)
                dp[i * 3 + 2] = r * cos(p)
            }
            let pd = Data(bytes: dp, count: dp.count * MemoryLayout<Float>.size)
            let ps = SCNGeometrySource(data: pd, semantic: .vertex, vectorCount: dc, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: MemoryLayout<Float>.size * 3)
            let pe = SCNGeometryElement(data: nil, primitiveType: .point, primitiveCount: dc, bytesPerIndex: 0)
            let pg = SCNGeometry(sources: [ps], elements: [pe])
            let pm = SCNMaterial()
            pm.diffuse.contents = c.color.blended(withFraction: 0.3, of: .white) ?? c.color
            pm.shaderModifiers = [.geometry: "#pragma body\n_geometry.pointSize = 1.5;"]
            pg.materials = [pm]
            let pn = SCNNode(geometry: pg)
            spinNode.addChildNode(pn)

            moons.append(Moon(
                node: orbitNode,
                orbitRadius: c.distance,
                orbitSpeed: c.speed,
                angle: CGFloat.random(in: 0...(2 * .pi)),
                spinNode: spinNode
            ))
        }
    }

    // MARK: - Per-frame animation

    func animate(at time: TimeInterval) {
        if lastTime == 0 { lastTime = time; return }
        let dt = min(time - lastTime, 0.05)
        lastTime = time
        let delta = CGFloat(dt)

        // Camera zoom smoothing (lerp)
        let currentZ = cameraNode.position.z
        let diff = targetZoom - CGFloat(currentZ)
        if abs(diff) > 0.01 {
            cameraNode.position.z = currentZ + diff * min(1, CGFloat(dt) * 4)
        }

        // Camera lateral sway during running (gentle orbit feel)
        if animationIntensity > 0 {
            cameraNode.position.x = sin(time * 0.3) * animationIntensity * 0.8
        } else {
            cameraNode.position.x = 0
        }

        // Planet core — dramatic speed up during optimize
        spinNode.eulerAngles.y     += delta * 0.175 * spinSpeedMultiplier

        // Great Red Spot — drifts faster, oscillates more during running
        redSpotNode.eulerAngles.y  -= delta * 0.025 * spinSpeedMultiplier
        redSpotNode.eulerAngles.x   = CGFloat(0.002 * sin(time * 0.5) + animationIntensity * 0.004 * sin(time * 1.3))

        // Atmosphere — parallax layer, extra speed during running
        atmosphereNode.eulerAngles.y += delta * 0.12 * (1.0 + animationIntensity * 2.0)

        // Rings — subtle tilt wobble during optimization
        let ringWobble = animationIntensity * 0.02 * sin(time * 0.8)
        ringNode.eulerAngles.x = -.pi / 2 + ringWobble
        ringNode.eulerAngles.y += delta * 0.175 * spinSpeedMultiplier

        // Moons — orbit faster during running
        let moonSpeedBoost = 1.0 + animationIntensity * 1.5
        for i in 0..<moons.count {
            moons[i].angle += moons[i].orbitSpeed * delta * moonSpeedBoost
            moons[i].node.eulerAngles.y = moons[i].angle
            moons[i].spinNode.eulerAngles.y = -moons[i].angle
        }
    }
}

// MARK: - Renderer delegate

extension JupiterScene: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        animate(at: time)
    }
}
