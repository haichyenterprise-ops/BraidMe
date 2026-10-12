import SwiftUI
import MapKit
import UIKit

// =============================================================================
// MapCameraController — Orchestrates the "pull back to space" camera move
//
// Provides a single function: startTransition(from:) which animates the
// camera from a close-in view of a coordinate out to maximum zoom-out distance
// with a custom easing curve. Used by MainTabView for the globe transition.
// =============================================================================

@MainActor
final class MapCameraController: ObservableObject {

    /// True while the camera is performing the pull-back zoom.
    @Published private(set) var isTransitioning: Bool = false

    /// Fires when the pull-back completes.
    var onTransitionComplete: (() -> Void)?

    private weak var mapProxy: MapProxy?

    func attach(proxy: MapProxy) {
        self.mapProxy = proxy
    }

    /// Performs the pull-back: camera zooms out from the given coordinate to
    /// the maximum distance, with pitch flattening to 0 and heading to 0.
    ///
    /// - Parameters:
    ///   - coordinate: The coordinate to fly away from (the braider's position)
    ///   - duration: How long the zoom should take (default 1.2s)
    ///   - onComplete: Called when the animation finishes
    func pullBackToSpace(
        from coordinate: CLLocationCoordinate2D,
        duration: TimeInterval = 1.2,
        onComplete: @escaping () -> Void
    ) {
        guard !isTransitioning else { return }
        isTransitioning = true

        // Animate in steps so we get true custom easing — MapKit's built-in
        // animation is linear and doesn't feel like a rocket climb.
        let steps = 90
        let stepDuration = duration / Double(steps)

        // Keep local mutable values so we don't depend on the parent's state
        var currentDistance: Double = 1_200
        var currentPitch: Double = 28
        var currentHeading: Double = 0

        // Easing: fast at start, glacial at end
        // Maps t in [0,1] to eased t in [0,1] with a strong ease-out curve
        func easeOutQuint(_ t: Double) -> Double {
            return 1.0 - pow(1.0 - t, 5.0)
        }

        // Fire haptic rumble at the start
        let haptics = UIImpactFeedbackGenerator(style: .soft)
        haptics.prepare()

        Task { @MainActor in
            for step in 0..<steps {
                let linearT = Double(step) / Double(steps)
                let easedT = easeOutQuint(linearT)

                // Interpolate distance: start at 1.2km, end at 40,000km
                currentDistance = Self.lerp(1_200, 40_000_000, easedT)
                // Pitch flattens from 28° to 0°
                currentPitch = Self.lerp(28, 0, easedT)
                // Heading rotates gently to north
                currentHeading = Self.lerp(0, 0, easedT)

                if let proxy = mapProxy {
                    withAnimation(.linear(duration: stepDuration)) {
                        proxy.camera = .camera(
                            MapCamera(
                                centerCoordinate: coordinate,
                                distance: currentDistance,
                                heading: currentHeading,
                                pitch: currentPitch
                            )
                        )
                    }
                }

                // Soft haptic pulses during the first 40% of the animation
                if step % 8 == 0 && step < steps * 4 / 10 {
                    haptics.impactOccurred(intensity: 0.25)
                    haptics.prepare()
                }

                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }

            // Ensure we land exactly on the final value
            if let proxy = mapProxy {
                proxy.camera = .camera(
                    MapCamera(
                        centerCoordinate: coordinate,
                        distance: 40_000_000,
                        heading: 0,
                        pitch: 0
                    )
                )
            }

            isTransitioning = false
            onComplete()
        }
    }

    /// Resets the camera back to a "normal" state after the transition —
    /// used when the profile is dismissed and the map should be usable again.
    func resetCamera(
        to coordinate: CLLocationCoordinate2D,
        distance: Double,
        pitch: Double
    ) {
        if let proxy = mapProxy {
            withAnimation(.smooth(duration: 0.6)) {
                proxy.camera = .camera(
                    MapCamera(
                        centerCoordinate: coordinate,
                        distance: distance,
                        heading: 0,
                        pitch: pitch
                    )
                )
            }
        }
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }
}