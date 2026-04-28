import Foundation
import Kingfisher
import MediaSizeWatchdog

public final class KingfisherMediaAdapter: NSObject, MediaSizeAdapter, ImageDownloaderDelegate {
    private weak var reporter: MediaSizeReporter?
    private let downloader: ImageDownloader
    private let lock = NSLock()
    private var isRunning = false
    private weak var previousDelegate: ImageDownloaderDelegate?
    private var mimeTypesByURL: [URL: String] = [:]

    public init(
        reporter: MediaSizeReporter,
        downloader: ImageDownloader = .default
    ) {
        self.reporter = reporter
        self.downloader = downloader
    }

    public func start() {
        #if DEBUG
        lock.withLock {
            guard !isRunning else { return }
            isRunning = true
            previousDelegate = downloader.delegate
            downloader.delegate = self
        }
        #endif
    }

    public func stop() {
        #if DEBUG
        lock.withLock {
            guard isRunning else { return }
            isRunning = false
            downloader.delegate = previousDelegate
            previousDelegate = nil
            mimeTypesByURL.removeAll()
        }
        #endif
    }

    public func imageDownloader(
        _ downloader: ImageDownloader,
        didFinishDownloadingImageForURL url: URL,
        with response: URLResponse?,
        error: Error?
    ) {
        #if DEBUG
        if let mimeType = response?.mimeType {
            lock.withLock {
                mimeTypesByURL[url] = mimeType
            }
        }

        previousDelegate?.imageDownloader(
            downloader,
            didFinishDownloadingImageForURL: url,
            with: response,
            error: error
        )
        #endif
    }

    public func imageDownloader(_ downloader: ImageDownloader, didDownload data: Data, for url: URL) -> Data? {
        #if DEBUG
        let mimeType = lock.withLock { mimeTypesByURL[url] }

        if lock.withLock({ isRunning }) {
            reporter?.report(
                url: url,
                size: Int64(data.count),
                mimeType: mimeType,
                source: .kingfisher
            )
        }

        return previousDelegate?.imageDownloader(downloader, didDownload: data, for: url) ?? data
        #else
        return data
        #endif
    }

    public func imageDownloader(
        _ downloader: ImageDownloader,
        didDownload image: KFCrossPlatformImage,
        for url: URL,
        with response: URLResponse?
    ) {
        #if DEBUG
        previousDelegate?.imageDownloader(
            downloader,
            didDownload: image,
            for: url,
            with: response
        )
        #endif
    }

    public func imageDownloader(
        _ downloader: ImageDownloader,
        willDownloadImageForURL url: URL,
        with request: URLRequest?
    ) {
        #if DEBUG
        previousDelegate?.imageDownloader(
            downloader,
            willDownloadImageForURL: url,
            with: request
        )
        #endif
    }

    public func isValidStatusCode(_ code: Int, for downloader: ImageDownloader) -> Bool {
        #if DEBUG
        return previousDelegate?.isValidStatusCode(code, for: downloader) ?? (200..<400).contains(code)
        #else
        return (200..<400).contains(code)
        #endif
    }
}

private extension NSLock {
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
