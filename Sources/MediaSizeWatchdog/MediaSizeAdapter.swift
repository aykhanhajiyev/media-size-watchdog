import Foundation

public protocol MediaSizeAdapter: AnyObject {
    func start()
    func stop()
}

public protocol MediaSizeReporter: AnyObject {
    func report(
        url: URL,
        size: Int64,
        mimeType: String?,
        source: MediaSource
    )
}
