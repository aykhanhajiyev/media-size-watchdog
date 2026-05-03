# MediaSizeWatchdog

`MediaSizeWatchdog` is a debug-only Swift package for detecting oversized image and video responses during iOS development.

## Usage

```swift
#if DEBUG
import MediaSizeWatchdog

MediaSizeWatchdog.shared.start(
    config: .init(
        imageThreshold: 700 * 1024,
        videoThreshold: 8 * 1024 * 1024
    ),
    logger: AppMediaLogger(),
    adapters: [
        URLSessionMediaAdapter(reporter: MediaSizeWatchdog.shared),
        CustomNetworkAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
#endif
```

Provide your own logger by conforming to `MediaSizeLogger`:

```swift
import MediaSizeWatchdog

final class AppMediaLogger: MediaSizeLogger {
    func log(_ message: String) {
        // Forward to your app logging system.
        print("MediaWatchdog:", message)
    }
}
```

## Optional Library Adapters

`MediaSizeWatchdog` intentionally does not depend on Alamofire, SDWebImage, or Kingfisher. If your app uses one of those libraries, add the matching adapter implementation inside your app target, where both `MediaSizeWatchdog` and the third-party library are visible.

### Alamofire

Create `AlamofireMediaAdapter.swift` in your app target:

```swift
#if DEBUG
import Alamofire
import Foundation
import MediaSizeWatchdog

final class AlamofireMediaAdapter: EventMonitor, MediaSizeAdapter, @unchecked Sendable {
    let queue = DispatchQueue(label: "MediaSizeWatchdog.AlamofireAdapter")

    private weak var reporter: MediaSizeReporter?
    private let lock = NSLock()
    private var isRunning = false

    init(reporter: MediaSizeReporter) {
        self.reporter = reporter
    }

    func start() {
        lock.withLock {
            isRunning = true
        }
    }

    func stop() {
        lock.withLock {
            isRunning = false
        }
    }

    func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        report(response: response)
    }

    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) where Value: Sendable {
        report(response: response)
    }

    private func report<Value>(response: DataResponse<Value, AFError>) {
        guard lock.withLock({ isRunning }) else { return }
        guard let url = response.request?.url, let data = response.data else { return }

        reporter?.report(
            url: url,
            size: Int64(data.count),
            mimeType: response.response?.mimeType,
            source: .alamofire
        )
    }
}

private extension NSLock {
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
#endif
```

Attach it to the `Session` as an `EventMonitor`:

```swift
#if DEBUG
import Alamofire
import MediaSizeWatchdog

let alamofireAdapter = AlamofireMediaAdapter(reporter: MediaSizeWatchdog.shared)

MediaSizeWatchdog.shared.start(
    adapters: [alamofireAdapter]
)

let session = Session(eventMonitors: [alamofireAdapter])
#endif
```

### SDWebImage

Create `SDWebImageMediaAdapter.swift` in your app target:

```swift
#if DEBUG
import Foundation
import MediaSizeWatchdog
import SDWebImage

final class SDWebImageMediaAdapter: MediaSizeAdapter {
    private weak var reporter: MediaSizeReporter?
    private let downloader: SDWebImageDownloader
    private let lock = NSLock()
    private var isRunning = false
    private var previousDecryptor: SDWebImageDownloaderDecryptorProtocol?

    init(
        reporter: MediaSizeReporter,
        downloader: SDWebImageDownloader = .shared
    ) {
        self.reporter = reporter
        self.downloader = downloader
    }

    func start() {
        lock.withLock {
            guard !isRunning else { return }
            isRunning = true
            previousDecryptor = downloader.decryptor
        }

        let wrappedDecryptor = previousDecryptor
        downloader.decryptor = SDWebImageDownloaderDecryptor { [weak self] data, response in
            guard let self else {
                return wrappedDecryptor?.decryptedData(with: data, response: response) ?? data
            }

            self.report(data: data, response: response)
            return wrappedDecryptor?.decryptedData(with: data, response: response) ?? data
        }
    }

    func stop() {
        let decryptor = lock.withLock {
            guard isRunning else { return previousDecryptor }
            isRunning = false
            let decryptor = previousDecryptor
            previousDecryptor = nil
            return decryptor
        }

        downloader.decryptor = decryptor
    }

    private func report(data: Data, response: URLResponse?) {
        guard lock.withLock({ isRunning }) else { return }
        guard let url = response?.url else { return }

        reporter?.report(
            url: url,
            size: Int64(data.count),
            mimeType: response?.mimeType,
            source: .sdWebImage
        )
    }
}

private extension NSLock {
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
#endif
```

Start it with the watchdog:

```swift
#if DEBUG
import MediaSizeWatchdog
import SDWebImage

MediaSizeWatchdog.shared.start(
    adapters: [
        SDWebImageMediaAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
#endif
```

### Kingfisher

Create `KingfisherMediaAdapter.swift` in your app target:

```swift
#if DEBUG
import Foundation
import Kingfisher
import MediaSizeWatchdog

final class KingfisherMediaAdapter: NSObject, MediaSizeAdapter, ImageDownloaderDelegate {
    private weak var reporter: MediaSizeReporter?
    private let downloader: ImageDownloader
    private let lock = NSLock()
    private var isRunning = false
    private weak var previousDelegate: ImageDownloaderDelegate?
    private var mimeTypesByURL: [URL: String] = [:]

    init(
        reporter: MediaSizeReporter,
        downloader: ImageDownloader = .default
    ) {
        self.reporter = reporter
        self.downloader = downloader
    }

    func start() {
        lock.withLock {
            guard !isRunning else { return }
            isRunning = true
            previousDelegate = downloader.delegate
            downloader.delegate = self
        }
    }

    func stop() {
        lock.withLock {
            guard isRunning else { return }
            isRunning = false
            downloader.delegate = previousDelegate
            previousDelegate = nil
            mimeTypesByURL.removeAll()
        }
    }

    func imageDownloader(
        _ downloader: ImageDownloader,
        didFinishDownloadingImageForURL url: URL,
        with response: URLResponse?,
        error: Error?
    ) {
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
    }

    func imageDownloader(_ downloader: ImageDownloader, didDownload data: Data, for url: URL) -> Data? {
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
    }

    func imageDownloader(
        _ downloader: ImageDownloader,
        didDownload image: KFCrossPlatformImage,
        for url: URL,
        with response: URLResponse?
    ) {
        previousDelegate?.imageDownloader(
            downloader,
            didDownload: image,
            for: url,
            with: response
        )
    }

    func imageDownloader(
        _ downloader: ImageDownloader,
        willDownloadImageForURL url: URL,
        with request: URLRequest?
    ) {
        previousDelegate?.imageDownloader(
            downloader,
            willDownloadImageForURL: url,
            with: request
        )
    }

    func isValidStatusCode(_ code: Int, for downloader: ImageDownloader) -> Bool {
        previousDelegate?.isValidStatusCode(code, for: downloader) ?? (200..<400).contains(code)
    }
}

private extension NSLock {
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        lock()
        defer { unlock() }
        return try body()
    }
}
#endif
```

Start it with the watchdog:

```swift
#if DEBUG
import Kingfisher
import MediaSizeWatchdog

MediaSizeWatchdog.shared.start(
    adapters: [
        KingfisherMediaAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
#endif
```

For custom `URLSession` instances, instrument the configuration before creating the session:

```swift
#if DEBUG
let configuration = URLSessionMediaAdapter.instrument(URLSessionConfiguration.default)
let session = URLSession(configuration: configuration)
#endif
```

For custom routers or networking layers, keep a `CustomNetworkAdapter` instance and call `record(url:size:mimeType:)` when a response completes.

## Release Builds

Keep integration code inside `#if DEBUG` in your app. The package itself does not depend on the package target receiving a `DEBUG` compilation flag, which makes it work reliably in Tuist/Xcode projects where external packages may have different build settings.
