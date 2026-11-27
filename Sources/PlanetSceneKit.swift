import SceneKit
import AppKit

// MARK: - Noise

/// Deterministic 3D value/gradient noise shared by the planet scenes.
final class SeededNoise3D {
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

// MARK: - Geometry

/// Shared SceneKit geometry builders for the planet scenes.
enum PlanetGeometry {

    /// Build a point-cloud geometry from packed position and colour arrays.
    static func pointCloud(
        positions: [Float],
        colors: [Float],
        count: Int,
        pointSize: Float = 1.5,
        opacity: Float = 1,
        additive: Bool = false
    ) -> SCNGeometry {
        let pd = Data(bytes: positions, count: count * 3 * 4)
        let cd = Data(bytes: colors, count: count * 3 * 4)
        let ps = SCNGeometrySource(
            data: pd, semantic: .vertex, vectorCount: count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12
        )
        let cs = SCNGeometrySource(
            data: cd, semantic: .color, vectorCount: count, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: 4, dataOffset: 0, dataStride: 12
        )
        let element = SCNGeometryElement(
            data: nil, primitiveType: .point, primitiveCount: count, bytesPerIndex: 0
        )
        let geometry = SCNGeometry(sources: [ps, cs], elements: [element])
        let material = SCNMaterial()
        material.isDoubleSided = true
        material.writesToDepthBuffer = opacity >= 1
        if opacity < 1 {
            material.transparency = CGFloat(opacity)
            material.transparencyMode = .dualLayer
        }
        if additive {
            material.blendMode = .add
        }
        material.shaderModifiers = [.geometry: "#pragma body\n_geometry.pointSize = \(pointSize);"]
        geometry.materials = [material]
        return geometry
    }

    /// Subtle wireframe shell around a planet (10-unit diameter).
    static func wireframe(tint: NSColor) -> SCNGeometry {
        let box = SCNBox(width: 10.02, height: 10.02, length: 10.02, chamferRadius: 5.01)
        box.widthSegmentCount = 24
        box.heightSegmentCount = 16
        box.lengthSegmentCount = 24
        let material = SCNMaterial()
        material.diffuse.contents = tint
        material.isDoubleSided = true
        box.materials = [material]
        return box
    }
}
