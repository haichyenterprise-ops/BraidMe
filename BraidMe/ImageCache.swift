import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// =============================================================================
// ImageCache — Remote image loading with disk + memory caching, shimmer
// placeholders, failure memoization, and dominant-color extraction for
// ambient-tinted shadows.
// =============================================================================

final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let failed = NSCache<NSString, NSNumber>()
    private let palette = NSCache<NSString, UIColor>()
    private let diskURL: URL
    private let ioQueue = DispatchQueue(label: "BraidMe.ImageCache.io", qos: .background)

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskURL = caches.appendingPathComponent("BraidMeImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
        memory.countLimit = 200
        failed.countLimit = 100
        palette.countLimit = 200
    }

    // MARK: - Basic Cache

    func cachedImage(for key: String) -> UIImage? {
        if let img = memory.object(forKey: key as NSString) { return img }
        let file = diskURL.appendingPathComponent(hashed(key))
        guard let data = try? Data(contentsOf: file), let img = UIImage(data: data) else { return nil }
        memory.setObject(img, forKey: key as NSString)
        return img
    }

    func store(_ image: UIImage, for key: String) {
        memory.setObject(image, forKey: key as NSString)
        let file = diskURL.appendingPathComponent(hashed(key))
        ioQueue.async {
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: file, options: .atomic)
            }
        }
    }

    func hasFailed(_ key: String) -> Bool {
        failed.object(forKey: key as NSString) != nil
    }

    func markFailed(_ key: String) {
        failed.setObject(NSNumber(value: true), forKey: key as NSString)
    }

    // MARK: - Palette Extraction

    /// Extract a soft dominant color from an image, biased toward the upper third.
    /// Result is cached by URL. Returns nil if extraction fails.
    func dominantColor(for key: String, from image: UIImage) -> UIColor? {
        if let cached = palette.object(forKey: key as NSString) { return cached }
        guard let color = Self.extractDominant(from: image) else { return nil }
        palette.setObject(color, forKey: key as NSString)
        return color
    }

    func cachedDominantColor(for key: String) -> UIColor? {
        palette.object(forKey: key as NSString)
    }

    // MARK: - Extraction

    private static let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    /// Sample the upper-center third of the image, average the pixels, return a
    /// darkened, desaturated color suitable for shadow tinting.
    static func extractDominant(from image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }

        // Sample region: upper 40%, horizontal center 60%
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: imgW * 0.20,
            y: 0,
            width: imgW * 0.60,
            height: imgH * 0.40
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

        // Downscale to a 1×1 by averaging. Use CIAreaAverage for speed.
        let ciImage = CIImage(cgImage: cropped)
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent

        guard let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        Self.ciContext.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let r = CGFloat(pixel[0]) / 255.0
        let g = CGFloat(pixel[1]) / 255.0
        let b = CGFloat(pixel[2]) / 255.0

        // Desaturate 40% and darken to 85% — soft ambient shadow tone
        let gray = 0.30 * r + 0.59 * g + 0.11 * b
        let mixR = r * 0.60 + gray * 0.40
        let mixG = g * 0.60 + gray * 0.40
        let mixB = b * 0.60 + gray * 0.40

        let finalR = mixR * 0.85
        let finalG = mixG * 0.85
        let finalB = mixB * 0.85

        return UIColor(red: finalR, green: finalG, blue: finalB, alpha: 1.0)
    }

    // MARK: - Hashing

    private func hashed(_ key: String) -> String {
        var hash: UInt64 = 5381
        for byte in key.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(byte) }
        return String(hash, radix: 16)
    }
}

// =============================================================================
// MARK: - Remote Image
// =============================================================================

struct RemoteImage: View {
    let url: String
    var contentMode: ContentMode = .fill
    var fadeIn: Bool = true
    var onPaletteReady: ((UIColor) -> Void)? = nil

    @State private var image: UIImage?
    @State private var phase: LoadPhase = .idle

    private enum LoadPhase { case idle, loading, loaded, failed }

    var body: some View {
        ZStack {
            Color.appDivider
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(fadeIn ? .opacity : .identity)
            } else if phase == .failed {
                failedPlaceholder
            } else {
                shimmerBlock
            }
        }
        .task(id: url) { await load() }
    }

    private var shimmerBlock: some View {
        Rectangle()
            .fill(Color.appDivider)
            .overlay(MovingShimmer())
    }

    private var failedPlaceholder: some View {
        ZStack {
            Color.appDivider
            Image(systemName: "photo")
                .font(.bmUI(28, weight: .light))
                .foregroundStyle(Color.appSmoke)
        }
    }

    private func load() async {
        guard !url.isEmpty else { phase = .failed; return }

        if ImageCache.shared.hasFailed(url) {
            phase = .failed
            return
        }

        // Memory / disk cache hit
        if let cached = ImageCache.shared.cachedImage(for: url) {
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.32)) { self.image = cached }
                self.phase = .loaded
            }
            emitPaletteIfAvailable(cached)
            return
        }

        await MainActor.run { self.phase = .loading }
        guard let u = URL(string: url) else {
            await MainActor.run { self.phase = .failed }
            return
        }

        do {
            var request = URLRequest(url: u)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 15
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let img = UIImage(data: data) else {
                ImageCache.shared.markFailed(url)
                await MainActor.run { self.phase = .failed }
                return
            }
            ImageCache.shared.store(img, for: url)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.32)) { self.image = img }
                self.phase = .loaded
            }
            emitPaletteIfAvailable(img)
        } catch {
            ImageCache.shared.markFailed(url)
            await MainActor.run { self.phase = .failed }
        }
    }

    private func emitPaletteIfAvailable(_ img: UIImage) {
        guard let callback = onPaletteReady else { return }
        // Extract off-main to avoid frame drops
        Task.detached(priority: .utility) {
            if let cached = ImageCache.shared.cachedDominantColor(for: url) {
                await MainActor.run { callback(cached) }
                return
            }
            if let extracted = ImageCache.extractDominant(from: img) {
                _ = ImageCache.shared.dominantColor(for: url, from: img)
                await MainActor.run { callback(extracted) }
            }
        }
    }
}

// =============================================================================
// MARK: - Shimmer
// =============================================================================

private struct MovingShimmer: View {
    @State private var x: CGFloat = -1.2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, Color.appSurface.opacity(0.7), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.7)
            .offset(x: reduceMotion ? 0 : x * geo.size.width)
            .blendMode(.overlay)
            .onAppear {
                if !reduceMotion {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        x = 1.4
                    }
                }
            }
        }
    }
}

// =============================================================================
// MARK: - Legacy Avatar (kept for compatibility)
// =============================================================================

struct Avatar: View {
    let url: String
    var size: CGFloat = 44
    var ringColor: Color? = nil
    var ringWidth: CGFloat = 2

    var body: some View {
        ZStack {
            if let ringColor {
                Circle()
                    .stroke(ringColor, lineWidth: ringWidth)
                    .frame(width: size + ringWidth * 2, height: size + ringWidth * 2)
            }
            RemoteImage(url: url)
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
    }
}

// =============================================================================
// MARK: - Palette Tint Environment
// =============================================================================

/// Environment value that carries the current dominant color, letting child
/// views tint their shadows with the ambient image tone.
private struct AmbientPaletteKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    var ambientPalette: Color? {
        get { self[AmbientPaletteKey.self] }
        set { self[AmbientPaletteKey.self] = newValue }
    }
}

extension View {
    /// Applies an ambient-tinted shadow whose color comes from the palette.
    /// Falls back to a neutral ink shadow when no palette is available.
    func ambientShadow(_ palette: Color?, radius: CGFloat = 24, y: CGFloat = 12) -> some View {
        let tint = palette ?? Color.black.opacity(0.6)
        return self
            .shadow(color: tint.opacity(0.12), radius: radius * 0.4, y: y * 0.4)
            .shadow(color: tint.opacity(0.06), radius: radius, y: y)
    }
}