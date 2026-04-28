import Foundation
import MediaSizeWatchdog
import SDWebImage

public final class SDWebImageMediaAdapter: MediaSizeAdapter {
    private weak var reporter: MediaSizeReporter?
    private let downloader: SDWebImageDownloader
    private let lock = NSLock()
    private var isRunning = false
    private var previousDecryptor: SDWebImageDownloaderDecryptorProtocol?

    public init(
        reporter: MediaSizeReporter,
        downloader: SDWebImageDownloader = .shared
    ) {
        self.reporter = reporter
        self.downloader = downloader
    }

    public func start() {
        #if DEBUG
        lock.withLock {
            guard !isRunning else { return }
            isRunning = true
            self.previousDecryptor = downloader.decryptor
        }

        let wrappedDecryptor = self.previousDecryptor
        downloader.decryptor = SDWebImageDownloaderDecryptor { [weak self] data, response in
            guard let self else {
                return wrappedDecryptor?.decryptedData(with: data, response: response) ?? data
            }

            self.report(data: data, response: response)
            return wrappedDecryptor?.decryptedData(with: data, response: response) ?? data
        }
        #endif
    }

    public func stop() {
        #if DEBUG
        let decryptor = lock.withLock {
            guard isRunning else { return previousDecryptor }
            isRunning = false
            let decryptor = previousDecryptor
            previousDecryptor = nil
            return decryptor
        }

        downloader.decryptor = decryptor
        #endif
    }

    private func report(data: Data, response: URLResponse?) {
        #if DEBUG
        guard lock.withLock({ isRunning }) else { return }
        guard let url = response?.url else { return }

        reporter?.report(
            url: url,
            size: Int64(data.count),
            mimeType: response?.mimeType,
            source: .sdWebImage
        )
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
