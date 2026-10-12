import SwiftUI
import SceneKit
import UIKit

// =============================================================================
// GlobeScene — Premium 3D Earth with PBR materials, two-layer ocean,
// multi-layer continents, fresnel atmosphere, and particle rings.
//
// Rotation: SCNAction-driven (60fps).
// Spin speed, camera distance, and morph progress are all SwiftUI-driven
// via explicit setters on the coordinator.
// =============================================================================

final class GlobeSceneCoordinator: NSObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let globeNode = SCNNode()
    let oceanNode = SCNNode()
    let continentNode = SCNNode()
    let gridNode = SCNNode()
    let specularNode = SCNNode()
    let atmosphereInner = SCNNode()
    let atmosphereOuter = SCNNode()
    let particleRing = SCNNode()

    // Material references for morph control
    private var continentMaterial: SCNMaterial?
    private var gridMaterial: SCNMaterial?
    private var oceanMaterial: SCNMaterial?

    private var currentSpinSpeed: Float = 0
    private var currentMorph: Float = 0
    private var currentScale: Float = 1

    override init() {
        super.init()
        configureScene()
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Scene setup

    private func configureScene() {
        scene.background.contents = UIColor.clear

        // ─── Camera ───
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 200
        camera.fieldOfView = 42
        camera.wantsHDR = true
        camera.bloomIntensity = 0.9
        camera.bloomThreshold = 0.35
        camera.bloomBlurRadius = 14
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = 0.1
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 7.5)
        scene.rootNode.addChildNode(cameraNode)

        // ─── Environment lighting (procedural HDR-like map) ───
        let envMap = Self.generateEnvironmentMap()
        scene.lightingEnvironment.contents = envMap
        scene.lightingEnvironment.intensity = 1.1

        // ─── Ambient fill ───
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(red: 0.05, green: 0.04, blue: 0.06, alpha: 1)
        ambient.intensity = 180
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // ─── Key light: warm sun ───
        let key = SCNLight()
        key.type = .directional
        key.color = UIColor(red: 1.0, green: 0.92, blue: 0.72, alpha: 1)
        key.intensity = 1100
        key.castsShadow = false
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.85, -0.65, 0)
        scene.rootNode.addChildNode(keyNode)

        // ─── Cool rim light ───
        let rim = SCNLight()
        rim.type = .omni
        rim.color = UIColor(red: 0.65, green: 0.55, blue: 0.85, alpha: 1)
        rim.intensity = 380
        rim.attenuationStartDistance = 3
        rim.attenuationEndDistance = 15
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.position = SCNVector3(2.5, -2, 2)
        scene.rootNode.addChildNode(rimNode)

        // ─── Warm bounce from below ───
        let bounce = SCNLight()
        bounce.type = .omni
        bounce.color = UIColor(red: 0.85, green: 0.60, blue: 0.30, alpha: 1)
        bounce.intensity = 220
        bounce.attenuationStartDistance = 3
        bounce.attenuationEndDistance = 14
        let bounceNode = SCNNode()
        bounceNode.light = bounce
        bounceNode.position = SCNVector3(-2, -1.5, 1.5)
        scene.rootNode.addChildNode(bounceNode)

        // ─── Build globe ───
        buildOcean()
        buildContinents()
        buildGrid()
        buildAtmosphere()
        buildParticleRing()

        // Entire globe under one parent
        globeNode.opacity = 0
        scene.rootNode.addChildNode(globeNode)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Ocean

    private func buildOcean() {
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 128

        let material = SCNMaterial()
        material.diffuse.contents = Self.generateOceanTexture()
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        material.diffuse.mipFilter = .linear
        material.metalness.contents = 0.15
        material.metalness.intensity = 0.3
        material.roughness.contents = 0.35
        material.roughness.intensity = 0.4
        material.normal.contents = Self.generateNormalMap()
        material.normal.wrapS = .repeat
        material.normal.wrapT = .repeat
        material.normal.intensity = 0.6
        material.lightingModel = .physicallyBased
        material.isDoubleSided = false
        sphere.firstMaterial = material
        oceanMaterial = material

        let oceanSphereNode = SCNNode(geometry: sphere)
        oceanNode.addChildNode(oceanSphereNode)
        globeNode.addChildNode(oceanNode)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Continents

    private func buildContinents() {
        let sphere = SCNSphere(radius: 1.002)
        sphere.segmentCount = 128

        let material = SCNMaterial()
        material.diffuse.contents = Self.generateEarthTexture()
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        material.diffuse.mipFilter = .linear
        material.emission.contents = Self.generateEmissionMap()
        material.emission.wrapS = .repeat
        material.emission.wrapT = .clamp
        material.emission.intensity = 0.3
        material.metalness.contents = 0.85
        material.metalness.intensity = 0.9
        material.roughness.contents = 0.25
        material.roughness.intensity = 0.35
        material.transparencyMode = .aOne
        material.lightingModel = .physicallyBased
        material.isDoubleSided = false
        material.blendMode = .alpha
        sphere.firstMaterial = material
        continentMaterial = material

        let node = SCNNode(geometry: sphere)
        continentNode.addChildNode(node)
        globeNode.addChildNode(continentNode)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Grid (graticule)

    private func buildGrid() {
        let sphere = SCNSphere(radius: 1.006)
        sphere.segmentCount = 64

        let material = SCNMaterial()
        material.diffuse.contents = Self.generateGraticuleTexture()
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        material.transparencyMode = .aOne
        material.lightingModel = .constant
        material.blendMode = .alpha
        material.emission.contents = UIColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 0.35)
        material.emission.intensity = 0.4
        sphere.firstMaterial = material
        gridMaterial = material

        let node = SCNNode(geometry: sphere)
        gridNode.addChildNode(node)
        globeNode.addChildNode(gridNode)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Atmosphere (two layers)

    private func buildAtmosphere() {
        // Inner tight fresnel halo
        let inner = SCNSphere(radius: 1.06)
        inner.segmentCount = 64
        let innerMaterial = SCNMaterial()
        innerMaterial.diffuse.contents = UIColor.clear
        innerMaterial.emission.contents = Self.generateFresnelAtmosphere(color: UIColor(red: 1.0, green: 0.85, blue: 0.55, alpha: 1.0))
        innerMaterial.emission.intensity = 1.4
        innerMaterial.transparencyMode = .aOne
        innerMaterial.lightingModel = .constant
        innerMaterial.blendMode = .add
        innerMaterial.isDoubleSided = true
        innerMaterial.writesToDepthBuffer = false
        inner.firstMaterial = innerMaterial
        atmosphereInner.geometry = inner
        atmosphereInner.opacity = 0
        scene.rootNode.addChildNode(atmosphereInner)

        // Outer diffuse glow
        let outer = SCNSphere(radius: 1.18)
        outer.segmentCount = 48
        let outerMaterial = SCNMaterial()
        outerMaterial.diffuse.contents = UIColor.clear
        outerMaterial.emission.contents = Self.generateFresnelAtmosphere(color: UIColor(red: 0.95, green: 0.72, blue: 0.35, alpha: 1.0))
        outerMaterial.emission.intensity = 0.7
        outerMaterial.transparencyMode = .aOne
        outerMaterial.lightingModel = .constant
        outerMaterial.blendMode = .add
        outerMaterial.isDoubleSided = true
        outerMaterial.writesToDepthBuffer = false
        outer.firstMaterial = outerMaterial
        atmosphereOuter.geometry = outer
        atmosphereOuter.opacity = 0
        scene.rootNode.addChildNode(atmosphereOuter)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Particle ring

    private func buildParticleRing() {
        let count = 320
        let ringRadius: Float = 1.38
        let thickness: Float = 0.04

        // Build a single geometry using SCNGeometry with points
        var positions: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []

        for i in 0..<count {
            let angle = Float(i) / Float(count) * Float.pi * 2
            let jitter = Float.random(in: -thickness...thickness)
            let jitterRadius = ringRadius + Float.random(in: -0.02...0.02)

            let x = cos(angle) * jitterRadius
            let y = sin(angle) * jitterRadius
            let z = jitter

            positions.append(SCNVector3(x, y, z))

            // Random brightness for sparkle
            let b = Float.random(in: 0.5...1.0)
            colors.append(SIMD4<Float>(b, b * 0.85, b * 0.4, 1))
        }

        // Position source
        let positionSource = SCNGeometrySource(vertices: positions)

        // Color source
        let colorData = colors.withUnsafeBufferPointer { Data(buffer: $0) }
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.size
        )

        // Point geometry element
        let indices = (0..<count).map { Int32($0) }
        let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        element.pointSize = 4
        element.minimumPointScreenSpaceRadius = 2
        element.maximumPointScreenSpaceRadius = 6

        let geometry = SCNGeometry(sources: [positionSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white
        material.emission.contents = UIColor(red: 1.0, green: 0.85, blue: 0.55, alpha: 1)
        material.emission.intensity = 2.2
        material.blendMode = .add
        material.writesToDepthBuffer = false
        material.isDoubleSided = true
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.eulerAngles = SCNVector3(Float.pi / 2 + 0.35, 0, 0.2)
        particleRing.addChildNode(node)
        particleRing.opacity = 0
        scene.rootNode.addChildNode(particleRing)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Public API (SwiftUI-driven)

    func setCameraDistance(_ distance: Float) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        cameraNode.position = SCNVector3(0, 0, distance)
        SCNTransaction.commit()
    }

    func setGlobeOpacity(_ value: Float) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        globeNode.opacity = CGFloat(value)
        SCNTransaction.commit()
    }

    func setAtmosphereOpacity(_ value: Float) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        atmosphereInner.opacity = CGFloat(value)
        atmosphereOuter.opacity = CGFloat(value)
        SCNTransaction.commit()
    }

    func setRingOpacity(_ value: Float) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        particleRing.opacity = CGFloat(value)
        SCNTransaction.commit()
    }

    func setSpinSpeed(_ speed: Float) {
        guard abs(speed - currentSpinSpeed) > 0.01 else { return }
        currentSpinSpeed = speed

        globeNode.removeAction(forKey: "spin")
        particleRing.removeAction(forKey: "ringSpin")

        guard speed > 0.01 else { return }

        let globeDuration = TimeInterval(8.0 / Double(speed))
        let globeSpin = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: globeDuration)
        )
        globeNode.runAction(globeSpin, forKey: "spin")

        let ringDuration = TimeInterval(20.0 / Double(speed))
        let ringSpin = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: ringDuration)
        )
        particleRing.runAction(ringSpin, forKey: "ringSpin")
    }

    func setScale(_ scale: Float) {
        guard abs(scale - currentScale) > 0.005 else { return }
        currentScale = scale
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        globeNode.scale = SCNVector3(scale, scale, scale)
        atmosphereInner.scale = SCNVector3(scale, scale, scale)
        atmosphereOuter.scale = SCNVector3(scale, scale, scale)
        particleRing.scale = SCNVector3(scale, scale, scale)
        SCNTransaction.commit()
    }

    /// 0.0 = normal globe, 1.0 = fully dissolved (gold glow only)
    func setMorphProgress(_ progress: Float) {
        let p = max(0, min(progress, 1))
        guard abs(p - currentMorph) > 0.005 else { return }
        currentMorph = p

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0

        // Continents: blur toward invisible, brighten emission
        continentMaterial?.diffuse.intensity = CGFloat(1.0 - p * 0.9)
        continentMaterial?.emission.intensity = CGFloat(0.3 + p * 2.5)

        // Grid: fade out
        gridMaterial?.diffuse.intensity = CGFloat(1.0 - p)

        // Ocean: brighten to glowing
        oceanMaterial?.emission.contents = UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1)
        oceanMaterial?.emission.intensity = CGFloat(p * 2.8)

        // Globe overall: brighten
        globeNode.opacity = CGFloat(1.0 - p * 0.6)

        // Atmosphere: expand and brighten
        atmosphereInner.opacity = CGFloat(1.0 + p * 0.5)
        atmosphereOuter.opacity = CGFloat(1.0 + p * 0.8)

        SCNTransaction.commit()
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Texture generation

    static func generateOceanTexture() -> UIImage {
        let size = CGSize(width: 1024, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Deep navy base
            let colors = [
                UIColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 1.0).cgColor,
                UIColor(red: 0.06, green: 0.10, blue: 0.22, alpha: 1.0).cgColor,
                UIColor(red: 0.08, green: 0.14, blue: 0.28, alpha: 1.0).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.5, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }

            // Cyan shimmer streaks
            cg.setStrokeColor(UIColor(red: 0.4, green: 0.75, blue: 0.9, alpha: 0.12).cgColor)
            cg.setLineWidth(1.5)
            for _ in 0..<40 {
                let y = CGFloat.random(in: 0...size.height)
                let x = CGFloat.random(in: 0...size.width)
                let len = CGFloat.random(in: 60...200)
                cg.move(to: CGPoint(x: x, y: y))
                cg.addLine(to: CGPoint(x: x + len, y: y + CGFloat.random(in: -8...8)))
            }
            cg.strokePath()

            // Tiny bright specks
            cg.setFillColor(UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.3).cgColor)
            for _ in 0..<80 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
            }
        }
    }

    static func generateNormalMap() -> UIImage {
        let size = CGSize(width: 512, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            // Neutral normal (128, 128, 255) with slight variance
            cg.setFillColor(UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            for _ in 0..<600 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let r = CGFloat.random(in: 0.5...1.5)
                let v = CGFloat.random(in: 0.4...0.6)
                cg.setFillColor(UIColor(red: v, green: v, blue: 1.0, alpha: 1).cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
    }

    static func generateEarthTexture() -> UIImage {
        let size = CGSize(width: 2048, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.clear.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            let continents = Self.continentPaths()

            // Gold gradient with multiple stops for depth
            let goldColors = [
                UIColor(red: 1.00, green: 0.94, blue: 0.65, alpha: 1.0).cgColor,
                UIColor(red: 0.95, green: 0.80, blue: 0.40, alpha: 1.0).cgColor,
                UIColor(red: 0.85, green: 0.66, blue: 0.24, alpha: 1.0).cgColor,
                UIColor(red: 0.55, green: 0.40, blue: 0.12, alpha: 1.0).cgColor
            ] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: goldColors,
                locations: [0, 0.3, 0.7, 1]
            ) else { return }

            for continent in continents {
                guard let first = continent.first else { continue }
                let path = CGMutablePath()
                path.move(to: first)
                for p in continent.dropFirst() {
                    path.addLine(to: p)
                }
                path.closeSubpath()

                // Outer coastal glow
                cg.saveGState()
                cg.addPath(path)
                cg.setShadow(
                    offset: .zero,
                    blur: 24,
                    color: UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 0.6).cgColor
                )
                cg.setFillColor(UIColor(red: 0.9, green: 0.75, blue: 0.35, alpha: 1.0).cgColor)
                cg.fillPath()
                cg.restoreGState()

                // Main fill
                cg.saveGState()
                cg.addPath(path)
                cg.clip()
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
                cg.restoreGState()

                // Inner texture noise
                cg.saveGState()
                cg.addPath(path)
                cg.clip()
                for _ in 0..<120 {
                    let px = CGFloat.random(in: 0...size.width)
                    let py = CGFloat.random(in: 0..<size.height)
                    let alpha = CGFloat.random(in: 0.05...0.2)
                    let v = CGFloat.random(in: 0.4...0.9)
                    cg.setFillColor(UIColor(red: v, green: v * 0.9, blue: v * 0.5, alpha: alpha).cgColor)
                    let r = CGFloat.random(in: 4...20)
                    cg.fillEllipse(in: CGRect(x: px, y: py, width: r, height: r))
                }
                cg.restoreGState()

                // Bright edge
                cg.saveGState()
                cg.addPath(path)
                cg.setStrokeColor(UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 0.85).cgColor)
                cg.setLineWidth(2.5)
                cg.strokePath()
                cg.restoreGState()
            }
        }
    }

    static func generateEmissionMap() -> UIImage {
        let size = CGSize(width: 2048, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            let continents = Self.continentPaths()

            for continent in continents {
                guard let first = continent.first else { continue }
                let path = CGMutablePath()
                path.move(to: first)
                for p in continent.dropFirst() {
                    path.addLine(to: p)
                }
                path.closeSubpath()

                cg.saveGState()
                cg.addPath(path)
                cg.clip()

                // Scattered emissive points near coastal areas
                for _ in 0..<60 {
                    let px = CGFloat.random(in: 0...size.width)
                    let py = CGFloat.random(in: 0..<size.height)
                    let r = CGFloat.random(in: 1...3)
                    cg.setFillColor(UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.6).cgColor)
                    cg.fillEllipse(in: CGRect(x: px, y: py, width: r, height: r))
                }
                cg.restoreGState()
            }
        }
    }

    static func generateGraticuleTexture() -> UIImage {
        let size = CGSize(width: 2048, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 0.42).cgColor)
            cg.setLineWidth(1.5)

            let lonCount = 24
            for i in 0..<lonCount {
                let x = CGFloat(i) * size.width / CGFloat(lonCount)
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x, y: size.height))
            }

            let latCount = 12
            for i in 1..<latCount {
                let y = CGFloat(i) * size.height / CGFloat(latCount)
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: size.width, y: y))
            }

            cg.strokePath()
        }
    }

    static func generateFresnelAtmosphere(color: UIColor) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            let components = color.cgColor.components ?? [1, 1, 1, 1]
            let r = components[0]
            let g = components.count > 1 ? components[1] : r
            let b = components.count > 2 ? components[2] : r

            let colors = [
                UIColor(red: r, green: g, blue: b, alpha: 0.0).cgColor,
                UIColor(red: r, green: g, blue: b, alpha: 0.0).cgColor,
                UIColor(red: r, green: g, blue: b, alpha: 0.55).cgColor,
                UIColor(red: r, green: g, blue: b, alpha: 0.95).cgColor,
                UIColor(red: r, green: g, blue: b, alpha: 0.5).cgColor,
                UIColor(red: r, green: g, blue: b, alpha: 0.0).cgColor
            ] as CFArray

            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0.0, 0.55, 0.78, 0.88, 0.95, 1.0]
            ) else { return }

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            cg.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: size.width / 2,
                options: []
            )
        }
    }

    static func generateEnvironmentMap() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0).cgColor,
                UIColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1.0).cgColor,
                UIColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1.0).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.5, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }

            // Warm spot at top-left (sun hint)
            let sun = [
                UIColor(red: 1.0, green: 0.9, blue: 0.65, alpha: 0.85).cgColor,
                UIColor(red: 1.0, green: 0.9, blue: 0.65, alpha: 0.0).cgColor
            ] as CFArray
            if let sunGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: sun,
                locations: [0, 1]
            ) {
                let center = CGPoint(x: size.width * 0.25, y: size.height * 0.2)
                cg.drawRadialGradient(
                    sunGradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: size.width * 0.5,
                    options: []
                )
            }
        }
    }

    private static func continentPaths() -> [[CGPoint]] {
        return [
            [
                CGPoint(x: 280, y: 220), CGPoint(x: 420, y: 200),
                CGPoint(x: 520, y: 280), CGPoint(x: 500, y: 380),
                CGPoint(x: 420, y: 460), CGPoint(x: 340, y: 500),
                CGPoint(x: 280, y: 440), CGPoint(x: 240, y: 340),
                CGPoint(x: 260, y: 260)
            ],
            [
                CGPoint(x: 500, y: 520), CGPoint(x: 560, y: 540),
                CGPoint(x: 590, y: 640), CGPoint(x: 570, y: 760),
                CGPoint(x: 520, y: 840), CGPoint(x: 480, y: 780),
                CGPoint(x: 470, y: 660), CGPoint(x: 480, y: 570)
            ],
            [
                CGPoint(x: 940, y: 240), CGPoint(x: 1020, y: 240),
                CGPoint(x: 1080, y: 300), CGPoint(x: 1060, y: 380),
                CGPoint(x: 980, y: 400), CGPoint(x: 920, y: 340)
            ],
            [
                CGPoint(x: 980, y: 440), CGPoint(x: 1080, y: 440),
                CGPoint(x: 1140, y: 540), CGPoint(x: 1120, y: 680),
                CGPoint(x: 1060, y: 800), CGPoint(x: 1000, y: 780),
                CGPoint(x: 960, y: 660), CGPoint(x: 950, y: 540)
            ],
            [
                CGPoint(x: 1120, y: 220), CGPoint(x: 1300, y: 200),
                CGPoint(x: 1480, y: 240), CGPoint(x: 1640, y: 320),
                CGPoint(x: 1680, y: 420), CGPoint(x: 1580, y: 480),
                CGPoint(x: 1460, y: 460), CGPoint(x: 1340, y: 460),
                CGPoint(x: 1240, y: 400), CGPoint(x: 1180, y: 320)
            ],
            [
                CGPoint(x: 1520, y: 640), CGPoint(x: 1640, y: 660),
                CGPoint(x: 1680, y: 740), CGPoint(x: 1620, y: 800),
                CGPoint(x: 1520, y: 780), CGPoint(x: 1480, y: 700)
            ],
            [
                CGPoint(x: 700, y: 160), CGPoint(x: 780, y: 150),
                CGPoint(x: 820, y: 220), CGPoint(x: 760, y: 280),
                CGPoint(x: 680, y: 260)
            ]
        ]
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - SwiftUI wrapper

struct GlobeSceneView: UIViewRepresentable {
    @Binding var cameraDistance: Float
    @Binding var globeOpacity: Float
    @Binding var atmosphereOpacity: Float
    @Binding var ringOpacity: Float
    @Binding var spinSpeed: Float
    @Binding var scale: Float
    @Binding var morphProgress: Float

    func makeCoordinator() -> GlobeSceneCoordinator {
        GlobeSceneCoordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X
        view.rendersContinuously = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        c.setCameraDistance(cameraDistance)
        c.setGlobeOpacity(globeOpacity)
        c.setAtmosphereOpacity(atmosphereOpacity)
        c.setRingOpacity(ringOpacity)
        c.setSpinSpeed(spinSpeed)
        c.setScale(scale)
        c.setMorphProgress(morphProgress)
    }
}