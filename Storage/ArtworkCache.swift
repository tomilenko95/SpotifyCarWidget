import Foundation
import CryptoKit
import UIKit
import ImageIO

actor ArtworkCache {
    private let directory: URL
    init(root: URL) { directory = root.appendingPathComponent("Artwork", isDirectory: true) }
    nonisolated static func key(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func cache(_ url: URL) async throws -> String {
        guard url.scheme == "https", let host = url.host,
              host == "i.scdn.co" || host.hasSuffix(".scdn.co") else { throw APIError.invalidResponse }
        let key = Self.key(for: url)
        let file = directory.appendingPathComponent(key + ".jpg")
        if FileManager.default.fileExists(atPath: file.path) { return key }
        // Stream and cap compressed bytes before allocating or decoding an untrusted image.
        var request = URLRequest(url: url); request.timeoutInterval = 6
        #if WIDGET_EXTENSION
        request.timeoutInterval = 3
        let session = URLSessionTransport.widgetSession
        #else
        let session = URLSessionTransport.defaultSession
        #endif
        let (bytes, response) = try await session.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              response.expectedContentLength <= 4_000_000 else { throw APIError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 4_000_000 else { throw APIError.invalidResponse }
            data.append(byte)
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 480,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary), let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
        else { throw APIError.invalidResponse }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try jpeg.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try trim()
        return key
    }
    private func trim() throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
        let sorted = files.sorted {
            let first = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let second = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return first < second
        }
        var total = sorted.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        for (index, file) in sorted.enumerated() where total > 12_000_000 || sorted.count - index > 40 {
            total -= (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try FileManager.default.removeItem(at: file)
        }
    }
    func clear() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
    nonisolated static func image(key: String?, root: URL?) -> UIImage? {
        guard let key, key.count == 64, key.allSatisfy({ $0.isHexDigit }), let root else { return nil }
        return UIImage(contentsOfFile: root.appendingPathComponent("Artwork/\(key).jpg").path)
    }
}
