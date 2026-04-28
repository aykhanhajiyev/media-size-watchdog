import Foundation

public final class CustomNetworkAdapter: MediaSizeAdapter {
    private weak var reporter: MediaSizeReporter?
    private var isRunning = false
    private let lock = NSLock()

    public init(reporter: MediaSizeReporter) {
        self.reporter = reporter
    }

    public func start() {
        #if DEBUG
        lock.withLock {
            isRunning = true
        }
        #endif
    }

    public func stop() {
        #if DEBUG
        lock.withLock {
            isRunning = false
        }
        #endif
    }

    public func record(url: URL, size: Int64, mimeType: String?) {
        #if DEBUG
        let shouldReport = lock.withLock { isRunning }
        guard shouldReport else { return }

        reporter?.report(
            url: url,
            size: size,
            mimeType: mimeType,
            source: .custom
        )
        #endif
    }
}
