import SwiftUI

struct RemoteImage: View {
    let url: String
    var contentMode: ContentMode = .fill
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                AppTheme.mist
                if isLoading {
                    ProgressView().tint(AppTheme.slate)
                }
            }
        }
        .task(id: url) { await load() }
    }
    
    private func load() async {
        guard let u = URL(string: url), image == nil else { return }
        isLoading = true
        do {
            let (data, _) = try await URLSession.shared.data(from: u)
            if let img = UIImage(data: data) {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.image = img
                    }
                }
            }
        } catch {
            // silent fail; keep placeholder
        }
        await MainActor.run { self.isLoading = false }
    }
}