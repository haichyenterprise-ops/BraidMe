import SwiftUI
import UIKit

// MARK: - Memory + disk cache

final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let diskURL: URL
    private let ioQueue = DispatchQueue(label: "BraidMe.ImageCache.io", qos: .background)

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskURL = caches.appendingPathComponent("BraidMeImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
        memory.countLimit = 120
    }

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

    private func hashed(_ key: String) -> String {
        var hash: UInt64 = 5381
        for byte in key.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(byte) }
        return String(hash, radix: 16)
    }
}

// MARK: - RemoteImage

struct RemoteImage: View {
    let url: String
    var contentMode: ContentMode = .fill
    var fadeIn: Bool = true

    @State private var image: UIImage?
    @State private var phase: LoadPhase = .idle

    private enum LoadPhase { case idle, loading, loaded, failed }

    var body: some View {
        ZStack {
            AppTheme.mist

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

    // MARK: - Placeholders

    private var shimmerBlock: some View {
        Rectangle()
            .fill(AppTheme.mist)
            .overlay(
                MovingShimmer()
            )
    }

    private var failedPlaceholder: some View {
        ZStack {
            AppTheme.mist
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(AppTheme.ash)
        }
    }

    // MARK: - Load

    private func load() async {
        guard !url.isEmpty else { phase = .failed; return }
        if let cached = ImageCache.shared.cachedImage(for: url) {
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.28)) { self.image = cached }
                self.phase = .loaded
            }
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
                await MainActor.run { self.phase = .failed }
                return
            }
            ImageCache.shared.store(img, for: url)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.28)) { self.image = img }
                self.phase = .loaded
            }
        } catch {
            await MainActor.run { self.phase = .failed }
        }
    }
}

// MARK: - Shimmer sweep

private struct MovingShimmer: View {
    @State private var x: CGFloat = -1.2
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, AppTheme.hairline.opacity(0.7), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.7)
            .offset(x: x * geo.size.width)
            .blendMode(.overlay)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    x = 1.4
                }
            }
        }
    }
}

// MARK: - Avatar with ring

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