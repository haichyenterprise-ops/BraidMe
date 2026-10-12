import Foundation
import UIKit

// =============================================================================
// ImageUploader — ImgBB upload with progress, retry, and adaptive compression.
// =============================================================================

enum ImageUploader {
    static let imgbbAPIKey = "18c6a61ec367759efb34efff230a1eae"
    private static let endpoint = "https://api.imgbb.com/1/upload"

    enum UploadError: LocalizedError {
        case missingKey
        case encodingFailed
        case networkError(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingKey:          return "Image service isn't configured."
            case .encodingFailed:      return "Couldn't prepare that photo. Try another."
            case .networkError(let m): return "Upload failed — \(m)"
            case .invalidResponse:     return "Image host gave us an odd response."
            }
        }
    }

    private static let maxDimension: CGFloat = 1600
    private static let maxRetries = 2

    /// Upload with optional progress callback. Progress is 0.0 – 1.0.
    static func upload(
        _ image: UIImage,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> String {
        guard !imgbbAPIKey.isEmpty, imgbbAPIKey.count >= 20 else {
            throw UploadError.missingKey
        }

        let resized = image.resized(maxDimension: maxDimension)
        onProgress?(0.15)

        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            throw UploadError.encodingFailed
        }
        onProgress?(0.35)

        let base64 = data.base64EncodedString()
        var components = URLComponents(string: endpoint)!
        components.queryItems = [URLQueryItem(name: "key", value: imgbbAPIKey)]

        guard let url = components.url else {
            throw UploadError.invalidResponse
        }

        var lastError: Error = UploadError.invalidResponse

        for attempt in 0...maxRetries {
            do {
                onProgress?(0.5 + Double(attempt) * 0.15)
                return try await performUpload(url: url, base64: base64, attempt: attempt)
            } catch let error as UploadError {
                lastError = error
                if case .networkError = error, attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(400_000_000 * (attempt + 1)))
                    continue
                }
                throw error
            } catch {
                lastError = error
                throw error
            }
        }

        throw lastError
    }

    private static func performUpload(
        url: URL,
        base64: String,
        attempt: Int
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encoded = base64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? base64
        let body = "image=\(encoded)"
        request.httpBody = body.data(using: .utf8)

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: responseData, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw UploadError.networkError(msg)
        }

        struct ImgBBResponse: Decodable {
            struct DataBlock: Decodable {
                let url: String
                let display_url: String
            }
            let data: DataBlock
            let success: Bool
        }

        do {
            let decoded = try JSONDecoder().decode(ImgBBResponse.self, from: responseData)
            guard decoded.success else { throw UploadError.invalidResponse }
            return decoded.data.display_url
        } catch {
            throw UploadError.invalidResponse
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - UIImage helpers
// ═══════════════════════════════════════════════════════════════════

extension UIImage {
    /// Downscale the image so its longest dimension is at most `maxDimension`.
    func resized(maxDimension: CGFloat) -> UIImage {
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return self }

        let ratio = maxDimension / largest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Convenience — downscale and compress in one call.
    func preparedForUpload(
        maxDimension: CGFloat = 1600,
        quality: CGFloat = 0.85
    ) -> Data? {
        resized(maxDimension: maxDimension)
            .jpegData(compressionQuality: quality)
    }
}