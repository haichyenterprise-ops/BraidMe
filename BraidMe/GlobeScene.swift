import SwiftUI
import SceneKit
import UIKit

// =============================================================================
// GlobeScene — Real 3D rotating Earth in SceneKit.
// Procedural gold-on-obsidian texture. No image assets required.
// =============================================================================

final class GlobeSceneCoordinator: NSObject {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let globeNode = SCNNode()
    let outerRingNode = SCNNode()
    let atmosphereNode = SCNNode()
    let continentNode = SCNNode()

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
        camera.zFar = 100
        camera.fieldOfView = 40
        camera.wantsHDR = true
        camera.bloomIntensity = 0.8
        camera.bloomThreshold = 0.4
        camera.bloomBlurRadius = 12
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 4.2)
        scene.rootNode.addChildNode(cameraNode)

        // ─── Ambient ───
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(red: 0.10, green: 0.08, blue: 0.05, alpha: 1)
        ambient.intensity = 200
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // ─── Key light (top-left) ───
        let key = SCNLight()
        key.type = .directional
        key.color = UIColor(red: 1.0, green: 0.88, blue: 0.55, alpha: 1)
        key.intensity = 900
        key.castsShadow = false
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.9, -0.6, 0)
        scene.rootNode.addChildNode(keyNode)

        // ─── Rim light ───
        let rim = SCNLight()
        rim.type = .omni
        rim.color = UIColor(red: 0.85, green: 0.65, blue: 0.25, alpha: 1)
        rim.intensity = 400
        rim.attenuationStartDistance = 3
        rim.attenuationEndDistance = 12
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.position = SCNVector3(2.5, -2, 2)
        scene.rootNode.addChildNode(rimNode)

        // ─── Build the globe ───
        buildGlobe()
        buildAtmosphere()
        buildOrbitingRings()
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Globe

    private func buildGlobe() {
        // ── Base sphere: obsidian ──
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 128

        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = UIColor(red: 0.06, green: 0.05, blue: 0.07, alpha: 1)
        baseMaterial.metalness.contents = 0.4
        baseMaterial.roughness.contents = 0.35
        baseMaterial.lightingModel = .physicallyBased
        sphere.materials = [baseMaterial]

        globeNode.geometry = sphere

        // ── Continents overlay ──
        let continentSphere = SCNSphere(radius: 1.003)
        continentSphere.segmentCount = 128

        let continentMaterial = SCNMaterial()
        continentMaterial.diffuse.contents = Self.generateEarthTexture()
        continentMaterial.diffuse.wrapS = .repeat
        continentMaterial.diffuse.wrapT = .clamp
        continentMaterial.diffuse.mipFilter = .linear
        continentMaterial.transparencyMode = .aOne
        continentMaterial.isDoubleSided = false
        continentMaterial.lightingModel = .constant
        continentMaterial.blendMode = .alpha
        continentSphere.firstMaterial = continentMaterial

        continentNode.geometry = continentSphere

        // ── Graticule layer ──
        let gridSphere = SCNSphere(radius: 1.005)
        gridSphere.segmentCount = 64
        let gridMaterial = SCNMaterial()
        gridMaterial.diffuse.contents = Self.generateGraticuleTexture()
        gridMaterial.transparencyMode = .aOne
        gridMaterial.lightingModel = .constant
        gridMaterial.wrapS = .repeat
        gridMaterial.blendMode = .alpha
        gridSphere.firstMaterial = gridMaterial
        let gridNode = SCNNode(geometry: gridSphere)

        globeNode.addChildNode(continentNode)
        globeNode.addChildNode(gridNode)

        // Start invisible — SwiftUI will drive opacity
        globeNode.opacity = 0
        scene.rootNode.addChildNode(globeNode)
    }

    private func buildAtmosphere() {
        let atmosphere = SCNSphere(radius: 1.15)
        atmosphere.segmentCount = 64

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.clear
        material.emission.contents = UIImage.glowHalo()
        material.transparencyMode = .aOne
        material.isDoubleSided = true
        material.lightingModel = .constant
        material.blendMode = .add
        material.writesToDepthBuffer = false
        atmosphere.firstMaterial = material

        atmosphereNode.geometry = atmosphere
        atmosphereNode.opacity = 0
        scene.rootNode.addChildNode(atmosphereNode)
    }

    private func buildOrbitingRings() {
        for i in 0..<2 {
            let torus = SCNTorus(ringRadius: 1.35 + CGFloat(i) * 0.10,
                                 pipeRadius: 0.004)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.45, alpha: 1)
            material.emission.contents = UIColor(red: 1.0, green: 0.80, blue: 0.35, alpha: 1)
            material.emission.intensity = 1.6
            material.lightingModel = .constant
            material.transparencyMode = .aOne
            torus.materials = [material]

            let ringNode = SCNNode(geometry: torus)
            ringNode.eulerAngles = SCNVector3(
                .pi / 2 + CGFloat(i) * 0.3,
                0,
                CGFloat(i) * 0.6
            )
            outerRingNode.addChildNode(ringNode)
        }
        outerRingNode.opacity = 0
        scene.rootNode.addChildNode(outerRingNode)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Texture generation

    static func generateEarthTexture() -> UIImage {
        let size = CGSize(width: 2048, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext

            cg.setFillColor(UIColor.clear.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            let continents: [[CGPoint]] = Self.continentPaths()

            let goldColors = [
                UIColor(red: 1.00, green: 0.88, blue: 0.50, alpha: 1.0).cgColor,
                UIColor(red: 0.85, green: 0.66, blue: 0.24, alpha: 1.0).cgColor,
                UIColor(red: 0.55, green: 0.40, blue: 0.12, alpha: 1.0).cgColor
            ] as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: goldColors,
                locations: [0, 0.5, 1]
            )!

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

                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )

                // Stipple detail
                for _ in 0..<40 {
                    let px = CGFloat.random(in: first.x - 80 ... first.x + 80)
                    let py = CGFloat.random(in: first.y - 80 ... first.y + 80)
                    cg.setFillColor(UIColor(red: 1, green: 0.92, blue: 0.62, alpha: 0.25).cgColor)
                    cg.fillEllipse(in: CGRect(x: px, y: py, width: 3, height: 3))
                }

                cg.restoreGState()

                // Edge highlight
                cg.saveGState()
                cg.addPath(path)
                cg.setStrokeColor(UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.6).cgColor)
                cg.setLineWidth(2)
                cg.strokePath()
                cg.restoreGState()
            }
        }
    }

    static func generateGraticuleTexture() -> UIImage {
        let size = CGSize(width: 2048, height: 1024)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setStrokeColor(UIColor(red: 0.90, green: 0.72, blue: 0.32, alpha: 0.35).cgColor)
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

    private static func continentPaths() -> [[CGPoint]] {
        return [
            // North America
            [
                CGPoint(x: 280, y: 220),
                CGPoint(x: 420, y: 200),
                CGPoint(x: 520, y: 280),
                CGPoint(x: 500, y: 380),
                CGPoint(x: 420, y: 460),
                CGPoint(x: 340, y: 500),
                CGPoint(x: 280, y: 440),
                CGPoint(x: 240, y: 340),
                CGPoint(x: 260, y: 260)
            ],
            // South America
            [
                CGPoint(x: 500, y: 520),
                CGPoint(x: 560, y: 540),
                CGPoint(x: 590, y: 640),
                CGPoint(x: 570, y: 760),
                CGPoint(x: 520, y: 840),
                CGPoint(x: 480, y: 780),
                CGPoint(x: 470, y: 660),
                CGPoint(x: 480, y: 570)
            ],
            // Europe
            [
                CGPoint(x: 940, y: 240),
                CGPoint(x: 1020, y: 240),
                CGPoint(x: 1080, y: 300),
                CGPoint(x: 1060, y: 380),
                CGPoint(x: 980, y: 400),
                CGPoint(x: 920, y: 340)
            ],
            // Africa
            [
                CGPoint(x: 980, y: 440),
                CGPoint(x: 1080, y: 440),
                CGPoint(x: 1140, y: 540),
                CGPoint(x: 1120, y: 680),
                CGPoint(x: 1060, y: 800),
                CGPoint(x: 1000, y: 780),
                CGPoint(x: 960, y: 660),
                CGPoint(x: 950, y: 540)
            ],
            // Asia
            [
                CGPoint(x: 1120, y: 220),
                CGPoint(x: 1300, y: 200),
                CGPoint(x: 1480, y: 240),
                CGPoint(x: 1640, y: 320),
                CGPoint(x: 1680, y: 420),
                CGPoint(x: 1580, y: 480),
                CGPoint(x: 1460, y: 460),
                CGPoint(x: 1340, y: 460),
                CGPoint(x: 1240, y: 400),
                CGPoint(x: 1180, y: 320)
            ],
            // Australia
            [
                CGPoint(x: 1520, y: 640),
                CGPoint(x: 1640, y: 660),
                CGPoint(x: 1680, y: 740),
                CGPoint(x: 1620, y: 800),
                CGPoint(x: 1520, y: 780),
                CGPoint(x: 1480, y: 700)
            ],
            // Greenland
            [
                CGPoint(x: 700, y: 160),
                CGPoint(x: 780, y: 150),
                CGPoint(x: 820, y: 220),
                CGPoint(x: 760, y: 280),
                CGPoint(x: 680, y: 260)
            ]
        ]
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - SwiftUI-driven animators

    func setCameraDistance(_ distance: Float) {
        cameraNode.position = SCNVector3(0, 0, distance)
    }

    /// Only sets the parent node opacity. Children inherit.
    func setGlobeOpacity(_ value: Float) {
        globeNode.opacity = CGFloat(value)
    }

    func setAtmosphereOpacity(_ value: Float) {
        atmosphereNode.opacity = CGFloat(value)
    }

    func setRingOpacity(_ value: Float) {
        outerRingNode.opacity = CGFloat(value)
    }

    func setRotation(_ angle: Float) {
        globeNode.eulerAngles = SCNVector3(0.15, angle, 0.05)
    }

    func setRingsRotation(_ angle: Float) {
        outerRingNode.eulerAngles = SCNVector3(0, angle, 0)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - UIImage helpers

private extension UIImage {
    static func glowHalo() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 1.0, green: 0.85, blue: 0.45, alpha: 0.9).cgColor,
                UIColor(red: 0.85, green: 0.65, blue: 0.25, alpha: 0.3).cgColor,
                UIColor(red: 0.55, green: 0.40, blue: 0.15, alpha: 0.0).cgColor
            ] as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0.4, 0.7, 1.0]
            )!
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
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - SwiftUI wrapper

struct GlobeSceneView: UIViewRepresentable {
    @Binding var rotation: Float
    @Binding var cameraDistance: Float
    @Binding var globeOpacity: Float
    @Binding var atmosphereOpacity: Float
    @Binding var ringOpacity: Float
    @Binding var ringRotation: Float

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
        view.rendersContinuously = false
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        c.setCameraDistance(cameraDistance)
        c.setGlobeOpacity(globeOpacity)
        c.setAtmosphereOpacity(atmosphereOpacity)
        c.setRingOpacity(ringOpacity)
        c.setRotation(rotation)
        c.setRingsRotation(ringRotation)
    }
}