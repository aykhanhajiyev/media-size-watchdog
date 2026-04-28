import Foundation

public final class CustomNetworkAdapter: MediaSizeAdapter {
    private weak var reporter: MediaSizeReporter?
    private var isRunning = false
    private let lock = NSLock()

    public init(reporter: MediaSizeReporter) {
        self.reporter = reporter
    }

    public func start() {
        lock.withLock {
            isRunning = true
        }
    }

    public func stop() {
        lock.withLock {
            isRunning = false
        }
    }

    public func record(url: URL, size: Int64, mimeType: String?) {
        let shouldReport = lock.withLock { isRunning }
        guard shouldReport else { return }

        reporter?.report(
            url: url,
            size: size,
            mimeType: mimeType,
            source: .custom
        )
    }
}
