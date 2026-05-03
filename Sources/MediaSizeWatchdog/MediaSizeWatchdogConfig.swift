import Foundation

public struct MediaSizeWatchdogConfig: Sendable {
    public var imageThreshold: Int64
    public var videoThreshold: Int64

    public init(
        imageThreshold: Int64 = 500 * 1024,
        videoThreshold: Int64 = 5 * 1024 * 1024
    ) {
        self.imageThreshold = imageThreshold
        self.videoThreshold = videoThreshold
    }
}
