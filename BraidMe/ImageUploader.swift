import Foundation
import UIKit

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
            case .missingKey: return "ImgBB API key is not set."
            case .encodingFailed: return "Could not prepare image for upload."
            case .networkError(let m): return "Upload failed: \(m)"
            case .invalidResponse: return "Image host returned an unexpected response."
            }
        }
    }

    static func upload(_ image: UIImage) async throws -> String {
        guard !imgbbAPIKey.isEmpty, imgbbAPIKey.count >= 20 else {
            throw UploadError.missingKey
        }

        let resized = image.resized(maxDimension: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            throw UploadError.encodingFailed
        }

        let base64 = data.base64EncodedString()
        var components = URLComponents(string: endpoint)!
        components.queryItems = [URLQueryItem(name: "key", value: imgbbAPIKey)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "image=\(base64.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? base64)"
        request.httpBody = body.data(using: .utf8)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UploadError.invalidResponse }
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

        let decoded = try JSONDecoder().decode(ImgBBResponse.self, from: responseData)
        guard decoded.success else { throw UploadError.invalidResponse }
        return decoded.data.display_url
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return self }
        let ratio = maxDimension / largest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}