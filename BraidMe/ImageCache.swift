import SwiftUI

struct RemoteImage: View {
    let url: String
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        ZStack {
            AppTheme.mist
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if isLoading {
                ShimmerBlock()
            } else if failed {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.stone)
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let u = URL(string: url), image == nil else { return }
        isLoading = true
        failed = false
        do {
            let (data, _) = try await URLSession.shared.data(from: u)
            if let img = UIImage(data: data) {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.35)) { self.image = img }
                }
            } else { failed = true }
        } catch { failed = true }
        await MainActor.run { self.isLoading = false }
    }
}

struct ShimmerBlock: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        Rectangle()
            .fill(AppTheme.mist)
            .overlay(
                LinearGradient(
                    colors: [.clear, AppTheme.hairline.opacity(0.6), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .offset(x: phase * 300)
                .blendMode(.overlay)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
    }
}