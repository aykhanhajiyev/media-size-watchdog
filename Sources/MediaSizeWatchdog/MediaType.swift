import Foundation

public enum MediaType: String, Sendable {
    case image
    case video
    case unknown
}

public enum MediaTypeDetector {
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tiff", "tif", "avif", "svg"
    ]

    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "webm", "avi", "mkv", "mpeg", "mpg", "3gp", "3gpp"
    ]

    public static func detect(url: URL, mimeType: String?) -> MediaType {
        if let mimeType {
            let normalizedMimeType = mimeType
                .split(separator: ";", maxSplits: 1)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            if normalizedMimeType?.hasPrefix("image/") == true {
                return .image
            }

            if normalizedMimeType?.hasPrefix("video/") == true {
                return .video
            }
        }

        let pathExtension = url.pathExtension.lowercased()
        if imageExtensions.contains(pathExtension) {
            return .image
        }

        if videoExtensions.contains(pathExtension) {
            return .video
        }

        return .unknown
    }
}
