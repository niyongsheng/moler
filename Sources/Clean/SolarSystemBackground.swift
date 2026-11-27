import AppKit
import SceneKit
import SwiftUI

// MARK: - Scene

/// A real 3D solar system: the sun and eight planets are particle spheres
/// (the same point-cloud treatment as the planet pages) orbiting on slightly
/// inclined planes. The camera looks down on the system and can be orbited
/// with a drag or pulled closer with the scroll wheel.
final class SolarSystemScene: SCNScene {
    let cameraNode = SCNNode()

    /// Distance from the sun to the camera; the scroll wheel changes this.
    var targetDistance: CGFloat = 46

    /// While true the whole system accelerates to visualise the scan.
    private(set) var isScanning = false

    private let systemNode = SCNNode()
    private let sunSpin = SCNNode()

    private var distance: CGFloat = 46
    private var yaw: CGFloat = 0.32
    private var pitch: CGFloat = 0.62
    private var lastTime: TimeInterval = 0
    /// Orbital clock multiplied by `speed`, so acceleration never jumps phase.
    private var simTime: Double = 0
    private var speed: Double = 1

    private struct Orbiter {
        let carrier: SCNNode
        let spin: SCNNode
        let period: TimeInterval
        let spinPeriod: TimeInterval
        let phase: Double
        let spinPhase: Double
    }
    private var orbiters: [Orbiter] = []

    override init() { super.init(); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        background.contents = NSColor.clear

        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 400
        camera.fieldOfView = 34
        cameraNode.camera = camera
        rootNode.addChildNode(cameraNode)
        updateCamera()

        rootNode.addChildNode(systemNode)
        buildSun()
        buildPlanets()
    }

    // MARK: - Scanning

    func updateForScanning(_ scanning: Bool) {
        isScanning = scanning
        targetDistance = scanning ? 38 : 46
    }

    // MARK: - Interaction

    /// Rotate the camera around the system. Called from the pan gesture.
    func orbitCamera(dx: CGFloat, dy: CGFloat) {
        yaw += dx * 0.005
        pitch = min(max(pitch + dy * 0.004, 0.16), 1.15)
        updateCamera()
    }

    private func updateCamera() {
        let horizontal = distance * cos(pitch)
        cameraNode.position = SCNVector3(
            Float(horizontal * sin(yaw)),
            Float(distance * sin(pitch)),
            Float(horizontal * cos(yaw))
        )
        cameraNode.look(at: SCNVector3Zero)
    }

    // MARK: - Animation

    func animate(at time: TimeInterval) {
        guard lastTime > 0 else {
            lastTime = time
            return
        }
        let dt = min(time - lastTime, 0.05)
        lastTime = time

        // Scanning spins the planets up; the ramp keeps the change smooth.
        let targetSpeed: Double = isScanning ? 6 : 1
        speed += (targetSpeed - speed) * min(1, dt * 3)
        simTime += dt * speed

        // Ease the camera toward the wheel's target distance.
        if abs(targetDistance - distance) > 0.01 {
            distance += (targetDistance - distance) * min(1, CGFloat(dt) * 6)
            updateCamera()
        }

        for o in orbiters {
            let orbit = o.phase + (simTime / o.period).truncatingRemainder(dividingBy: 1) * 2 * .pi
            o.carrier.eulerAngles.y = CGFloat(orbit)

            let spin = o.spinPhase + (simTime / o.spinPeriod).truncatingRemainder(dividingBy: 1) * 2 * .pi
            o.spin.eulerAngles.y = CGFloat(spin)
        }

        sunSpin.eulerAngles.y = CGFloat((simTime / 26).truncatingRemainder(dividingBy: 1) * 2 * .pi)
    }

    // MARK: - Sun

    private func buildSun() {
        let radius: Float = 1.15
        let holder = SCNNode()

        sunSpin.addChildNode(SCNNode(geometry: sunGeometry(radius: radius)))
        holder.addChildNode(sunSpin)

        let glow = SCNPlane(
            width: CGFloat(radius) * 5.5,
            height: CGFloat(radius) * 5.5
        )
        let material = SCNMaterial()
        material.diffuse.contents = Self.glowImage
        material.lightingModel = .constant
        material.blendMode = .add
        material.writesToDepthBuffer = false
        material.isDoubleSided = true
        glow.materials = [material]

        let glowNode = SCNNode(geometry: glow)
        glowNode.constraints = [SCNBillboardConstraint()]
        holder.addChildNode(glowNode)

        systemNode.addChildNode(holder)
    }

    private func sunGeometry(radius: Float) -> SCNGeometry {
        let count = 3_200
        var positions = [Float](repeating: 0, count: count * 3)
        var colors = [Float](repeating: 0, count: count * 3)
        let noise = SeededNoise3D(seed: "moler-sun")

        for i in 0..<count {
            let z = Float.random(in: -1...1)
            let theta = Float.random(in: 0...(2 * .pi))
            let ring = max(0, 1 - z * z).squareRoot()
            let x = ring * cos(theta)
            let y = z
            let zz = ring * sin(theta)

            let n = Float(noise.noise3D(Double(x) * 2.5, Double(y) * 2.5, Double(zz) * 2.5))
            let h = 1 + n * 0.03
            positions[i * 3] = x * radius * h
            positions[i * 3 + 1] = y * radius * h
            positions[i * 3 + 2] = zz * radius * h

            let shade = 0.85 + n * 0.12
            colors[i * 3] = min(1, 1.0 * shade)
            colors[i * 3 + 1] = min(1, Float.random(in: 0.58...0.78) * shade)
            colors[i * 3 + 2] = min(1, Float.random(in: 0.15...0.30) * shade)
        }

        return PlanetGeometry.pointCloud(
            positions: positions,
            colors: colors,
            count: count,
            pointSize: 1.7,
            opacity: 1,
            additive: true
        )
    }

    private static let glowImage: NSImage = {
        let size = 256
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            let colors = [
                NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.30, alpha: 0.38).cgColor,
                NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.10, alpha: 0.10).cgColor,
                NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.05, alpha: 0.0).cgColor,
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.4, 1]
            ) {
                let center = CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
                context.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: CGFloat(size) / 2,
                    options: []
                )
            }
        }
        image.unlockFocus()
        return image
    }()

    // MARK: - Planets

    private struct PlanetSpec {
        let name: String
        let orbitRadius: Float
        let radius: Float
        let period: TimeInterval
        let spinPeriod: TimeInterval
        let base: SIMD3<Float>
        let accent: SIMD3<Float>?
        let count: Int
        let inclination: Float
        let bands: Float
        let hasRing: Bool
    }

    private let specs: [PlanetSpec] = [
        PlanetSpec(name: "MERC", orbitRadius: 3.0, radius: 0.15, period: 8, spinPeriod: 5,
                   base: SIMD3(0.62, 0.60, 0.56), accent: SIMD3(0.46, 0.44, 0.41),
                   count: 120, inclination: 0.03, bands: 0, hasRing: false),
        PlanetSpec(name: "VEN", orbitRadius: 4.1, radius: 0.24, period: 14, spinPeriod: 6,
                   base: SIMD3(0.88, 0.72, 0.42), accent: SIMD3(0.72, 0.58, 0.34),
                   count: 220, inclination: -0.05, bands: 0, hasRing: false),
        PlanetSpec(name: "TER", orbitRadius: 5.2, radius: 0.27, period: 22, spinPeriod: 5,
                   base: SIMD3(0.32, 0.60, 0.62), accent: SIMD3(0.22, 0.36, 0.58),
                   count: 250, inclination: 0.02, bands: 0, hasRing: false),
        PlanetSpec(name: "MARS", orbitRadius: 6.3, radius: 0.21, period: 32, spinPeriod: 5,
                   base: SIMD3(0.76, 0.35, 0.24), accent: SIMD3(0.52, 0.23, 0.16),
                   count: 170, inclination: 0.06, bands: 0, hasRing: false),
        PlanetSpec(name: "JUP", orbitRadius: 7.7, radius: 0.48, period: 48, spinPeriod: 3.5,
                   base: SIMD3(0.85, 0.55, 0.30), accent: SIMD3(0.60, 0.40, 0.29),
                   count: 720, inclination: -0.03, bands: 9, hasRing: true),
        PlanetSpec(name: "SAT", orbitRadius: 9.0, radius: 0.40, period: 70, spinPeriod: 4,
                   base: SIMD3(0.82, 0.70, 0.44), accent: SIMD3(0.60, 0.51, 0.34),
                   count: 600, inclination: 0.05, bands: 7, hasRing: true),
        PlanetSpec(name: "URA", orbitRadius: 10.2, radius: 0.30, period: 95, spinPeriod: 6,
                   base: SIMD3(0.50, 0.72, 0.78), accent: SIMD3(0.38, 0.58, 0.68),
                   count: 350, inclination: -0.07, bands: 0, hasRing: false),
        PlanetSpec(name: "NEP", orbitRadius: 11.3, radius: 0.29, period: 130, spinPeriod: 7,
                   base: SIMD3(0.28, 0.40, 0.78), accent: SIMD3(0.20, 0.30, 0.62),
                   count: 320, inclination: 0.04, bands: 0, hasRing: false),
    ]

    private func buildPlanets() {
        for (index, spec) in specs.enumerated() {
            let plane = SCNNode()
            plane.eulerAngles = SCNVector3(spec.inclination, 0, spec.inclination * 0.6)
            systemNode.addChildNode(plane)

            let orbitColor = spec.name == "JUP"
                ? NSColor(calibratedRed: 0.88, green: 0.38, blue: 0.20, alpha: 1)
                : NSColor(calibratedRed: 0.23, green: 0.31, blue: 0.42, alpha: 1)
            plane.addChildNode(orbitRing(
                radius: spec.orbitRadius,
                color: orbitColor,
                opacity: spec.name == "JUP" ? 0.4 : 0.26
            ))

            let carrier = SCNNode()
            let phase = Double(index) * 1.3
            carrier.eulerAngles.y = CGFloat(phase)
            plane.addChildNode(carrier)

            let holder = SCNNode()
            holder.position = SCNVector3(spec.orbitRadius, 0, 0)
            carrier.addChildNode(holder)

            let axial = SCNNode()
            axial.eulerAngles.z = CGFloat(spec.inclination * 5)
            holder.addChildNode(axial)

            let spin = SCNNode()
            axial.addChildNode(spin)
            spin.addChildNode(SCNNode(geometry: planetGeometry(spec)))

            if spec.hasRing {
                let saturn = spec.name == "SAT"
                let torus = SCNTorus(
                    ringRadius: CGFloat(spec.radius) * (saturn ? 1.9 : 1.6),
                    pipeRadius: CGFloat(spec.radius) * (saturn ? 0.045 : 0.02)
                )
                torus.ringSegmentCount = 96
                torus.pipeSegmentCount = 8

                let material = SCNMaterial()
                material.diffuse.contents = saturn
                    ? NSColor(calibratedRed: 0.82, green: 0.70, blue: 0.46, alpha: 1)
                    : NSColor(calibratedRed: 0.88, green: 0.42, blue: 0.24, alpha: 1)
                material.lightingModel = .constant
                material.isDoubleSided = true
                material.transparency = saturn ? 0.7 : 0.45
                torus.materials = [material]

                let ringNode = SCNNode(geometry: torus)
                ringNode.eulerAngles = SCNVector3(0.35, 0, 0.2)
                axial.addChildNode(ringNode)
            }

            orbiters.append(Orbiter(
                carrier: carrier,
                spin: spin,
                period: spec.period,
                spinPeriod: spec.spinPeriod,
                phase: phase,
                spinPhase: Double(index) * 0.7
            ))
        }
    }

    private func planetGeometry(_ spec: PlanetSpec) -> SCNGeometry {
        let count = spec.count
        var positions = [Float](repeating: 0, count: count * 3)
        var colors = [Float](repeating: 0, count: count * 3)
        let noise = SeededNoise3D(seed: spec.name)

        for i in 0..<count {
            let z = Float.random(in: -1...1)
            let theta = Float.random(in: 0...(2 * .pi))
            let ring = max(0, 1 - z * z).squareRoot()
            let x = ring * cos(theta)
            let y = z
            let zz = ring * sin(theta)

            let h = 1 + Float(noise.noise3D(Double(x) * 3, Double(y) * 3, Double(zz) * 3)) * 0.035
            positions[i * 3] = x * spec.radius * h
            positions[i * 3 + 1] = y * spec.radius * h
            positions[i * 3 + 2] = zz * spec.radius * h

            let n = Float(noise.noise3D(Double(x) * 2, Double(y) * 2, Double(zz) * 2))
            var color = spec.base
            if let accent = spec.accent {
                let mix = min(max((n + 0.7) * 0.7, 0), 1)
                color = spec.base * (1 - mix) + accent * mix
            }
            if spec.bands > 0 {
                let band = sin(Double(y) * Double(spec.bands) + Double(n) * 0.6)
                color = color * Float(0.66 + (band + 1) * 0.17)
            } else {
                color = color * (0.82 + n * 0.1)
            }

            colors[i * 3] = min(1, max(0, color.x))
            colors[i * 3 + 1] = min(1, max(0, color.y))
            colors[i * 3 + 2] = min(1, max(0, color.z))
        }

        return PlanetGeometry.pointCloud(
            positions: positions,
            colors: colors,
            count: count,
            pointSize: 1.5
        )
    }

    // MARK: - Orbit rings

    private func orbitRing(radius: Float, color: NSColor, opacity: CGFloat) -> SCNNode {
        let dashes = max(48, Int(radius * 9))
        let step = Float.pi * 2 / Float(dashes)
        let span = step * 0.55

        var vertices: [SCNVector3] = []
        vertices.reserveCapacity(dashes * 2)
        for i in 0..<dashes {
            let a0 = Float(i) * step
            let a1 = a0 + span
            vertices.append(SCNVector3(radius * cos(a0), 0, radius * sin(a0)))
            vertices.append(SCNVector3(radius * cos(a1), 0, radius * sin(a1)))
        }

        let source = SCNGeometrySource(vertices: vertices)
        let indices = (0..<UInt32(vertices.count)).map { $0 }
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .constant
        material.transparency = opacity
        material.writesToDepthBuffer = false
        material.isDoubleSided = true
        geometry.materials = [material]

        return SCNNode(geometry: geometry)
    }
}

extension SolarSystemScene: SCNSceneRendererDelegate {
    func renderer(_: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        animate(at: time)
    }
}

// MARK: - SCNView

final class SolarSystemSCNView: SCNView {
    override var mouseDownCanMoveWindow: Bool { false }

    weak var sceneRef: SolarSystemScene?

    override func scrollWheel(with event: NSEvent) {
        guard let scene = sceneRef else { return }
        scene.targetDistance = max(28, min(78, scene.targetDistance - event.scrollingDeltaY * 0.35))
    }
}

// MARK: - SwiftUI wrapper

struct SolarSystemBackground: NSViewRepresentable {
    typealias NSViewType = SolarSystemSCNView

    let isVisible: Bool
    let isScanning: Bool

    func makeNSView(context: Context) -> SolarSystemSCNView {
        let scene = SolarSystemScene()
        let view = SolarSystemSCNView()
        view.scene = scene
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.delegate = scene
        view.loops = true
        view.preferredFramesPerSecond = 30
        view.isPlaying = isVisible
        view.showsStatistics = false
        view.sceneRef = scene

        let pan = NSPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        view.addGestureRecognizer(pan)
        context.coordinator.scene = scene
        scene.updateForScanning(isScanning)

        return view
    }

    func updateNSView(_ nsView: SolarSystemSCNView, context: Context) {
        nsView.isPlaying = isVisible
        nsView.sceneRef?.updateForScanning(isScanning)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var scene: SolarSystemScene?
        private var lastLocation: CGPoint?

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let scene else { return }
            let location = gesture.location(in: gesture.view)

            switch gesture.state {
            case .began:
                lastLocation = location
            case .changed:
                guard let last = lastLocation else { return }
                scene.orbitCamera(dx: location.x - last.x, dy: location.y - last.y)
                lastLocation = location
            default:
                lastLocation = nil
            }
        }
    }
}
