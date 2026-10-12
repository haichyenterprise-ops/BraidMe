import SwiftUI
import UIKit

// =============================================================================
// ImageCache — remote image loading with memory + disk caching,
// thumbnail generation for pins, and prefetch API.
// =============================================================================

final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let thumbnails = NSCache<NSString, UIImage>()
    private let failed = NSCache<NSString, NSNumber>()
    private let diskURL: URL
    private let ioQueue = DispatchQueue(label: "BraidMe.ImageCache.io", qos: .background)

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskURL = caches.appendingPathComponent("BraidMeImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
        memory.countLimit = 300
        thumbnails.countLimit = 500
        failed.countLimit = 200
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Basic cache

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

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Thumbnails (for pins and small avatars)

    /// Return a small thumbnail (up to 128px) of the image at the given key.
    /// Generated once and cached separately from the full image.
    func thumbnail(for key: String, size: CGFloat = 128) -> UIImage? {
        let thumbKey = "\(key)_thumb_\(Int(size))"
        if let thumb = thumbnails.object(forKey: thumbKey as NSString) {
            return thumb
        }
        guard let original = cachedImage(for: key) else { return nil }
        let thumb = makeThumbnail(original, size: size)
        thumbnails.setObject(thumb, forKey: thumbKey as NSString)
        return thumb
    }

    /// Synchronously generate a thumbnail from a UIImage.
    func makeThumbnail(_ image: UIImage, size: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > size else { return image }
        let ratio = size / largest
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Prefetch

    /// Prefetch a list of URLs into the cache without displaying them.
    func prefetch(_ urls: [String]) {
        for url in urls {
            guard !url.isEmpty else { continue }
            if cachedImage(for: url) != nil { continue }
            guard !hasFailed(url) else { continue }
            guard let u = URL(string: url) else { continue }
            ioQueue.async { [weak self] in
                var request = URLRequest(url: u)
                request.cachePolicy = .returnCacheDataElseLoad
                request.timeoutInterval = 15
                URLSession.shared.dataTask(with: request) { data, _, _ in
                    guard let data, let img = UIImage(data: data) else { return }
                    self?.store(img, for: url)
                }.resume()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Hashing

    private func hashed(_ key: String) -> String {
        var hash: UInt64 = 5381
        for byte in key.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(byte) }
        return String(hash, radix: 16)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Remote Image
// ═══════════════════════════════════════════════════════════════════

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
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.appSmoke)
        }
    }

    private func load() async {
        guard !url.isEmpty else { phase = .failed; return }

        if ImageCache.shared.hasFailed(url) {
            phase = .failed
            return
        }

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
        Task.detached(priority: .utility) {
            if let color = ImageCache.extractDominant(from: img) {
                await MainActor.run { callback(color) }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Dominant color extraction
// ═══════════════════════════════════════════════════════════════════

import CoreImage
import CoreImage.CIFilterBuiltins

extension ImageCache {
    private static let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    /// Sample the upper-center third of the image, average the pixels,
    /// return a darkened, desaturated color for shadow tinting.
    static func extractDominant(from image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }

        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        let cropRect = CGRect(
            x: imgW * 0.20,
            y: 0,
            width: imgW * 0.60,
            height: imgH * 0.40
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }

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

        let gray = 0.30 * r + 0.59 * g + 0.11 * b
        let mixR = r * 0.60 + gray * 0.40
        let mixG = g * 0.60 + gray * 0.40
        let mixB = b * 0.60 + gray * 0.40

        return UIColor(red: mixR * 0.85, green: mixG * 0.85, blue: mixB * 0.85, alpha: 1.0)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Shimmer
// ═══════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Avatar (legacy)
// ═══════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Ambient palette environment
// ═══════════════════════════════════════════════════════════════════

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
    func ambientShadow(_ palette: Color?, radius: CGFloat = 24, y: CGFloat = 12) -> some View {
        let tint = palette ?? Color.black.opacity(0.6)
        return self
            .shadow(color: tint.opacity(0.12), radius: radius * 0.4, y: y * 0.4)
            .shadow(color: tint.opacity(0.06), radius: radius, y: y)
    }
}