import Foundation

public struct MediaSizeIssue: Equatable, Sendable {
    public let url: URL
    public let mediaType: MediaType
    public let size: Int64
    public let threshold: Int64
    public let mimeType: String?
    public let source: MediaSource
    public let date: Date

    public init(
        url: URL,
        mediaType: MediaType,
        size: Int64,
        threshold: Int64,
        mimeType: String?,
        source: MediaSource,
        date: Date = Date()
    ) {
        self.url = url
        self.mediaType = mediaType
        self.size = size
        self.threshold = threshold
        self.mimeType = mimeType
        self.source = source
        self.date = date
    }
}
