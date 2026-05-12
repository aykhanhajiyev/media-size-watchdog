# MediaSizeWatchdog

`MediaSizeWatchdog` is a small Swift package that reports oversized image and video network responses. It is useful in debug builds, QA builds, or internal tooling where you want to catch unexpectedly large media before it reaches production.

The package does not upload data or modify responses. It records matching oversized media in memory and logs a readable warning through a configurable logger.

## Requirements

- Swift 5.9+
- iOS 13.0+
- macOS 10.15+

## Installation

Add the package to your project with Swift Package Manager:

```swift
.package(url: "https://github.com/<your-org>/MediaSizeWatchDog-spm.git", from: "2.0.0")
```

Then add `MediaSizeWatchdog` to the target that should monitor media responses.

## Quick Start

```swift
import MediaSizeWatchdog

let watchdog = MediaSizeWatchdog.shared

watchdog.start(
    config: MediaSizeWatchdogConfig(
        imageThreshold: 500 * 1024,
        videoThreshold: 5 * 1024 * 1024
    ),
    adapters: [
        URLSessionMediaAdapter(reporter: watchdog)
    ]
)
```

When the watchdog sees an image or video response above the configured threshold, it stores a `MediaSizeIssue` and logs a message like:

```text
[MediaSizeWatchdog] Oversized image from urlSession: https://example.com/photo.jpg size=812 KB threshold=500 KB mimeType=image/jpeg
```

## Configuration

`MediaSizeWatchdogConfig` accepts byte thresholds:

```swift
let config = MediaSizeWatchdogConfig(
    imageThreshold: 700 * 1024,
    videoThreshold: 8 * 1024 * 1024
)
```

Defaults:

- Images: `500 * 1024` bytes
- Videos: `5 * 1024 * 1024` bytes

Only detected image and video responses are reported. Unknown media types are ignored.

## URLSession Adapter

For sessions that use `URLSessionConfiguration.default`, starting `URLSessionMediaAdapter` registers an internal `URLProtocol`:

```swift
MediaSizeWatchdog.shared.start(
    adapters: [
        URLSessionMediaAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
```

For custom `URLSessionConfiguration` instances, instrument the configuration before creating the session:

```swift
let configuration = URLSessionMediaAdapter.instrument(URLSessionConfiguration.default)
let session = URLSession(configuration: configuration)
```

## Custom Network Adapter

Use `CustomNetworkAdapter` when your app already knows the final response size:

```swift
import MediaSizeWatchdog

let customAdapter = CustomNetworkAdapter(reporter: MediaSizeWatchdog.shared)

MediaSizeWatchdog.shared.start(
    adapters: [customAdapter]
)

customAdapter.record(
    url: URL(string: "https://example.com/banner.png")!,
    size: Int64(data.count),
    mimeType: response.mimeType
)
```

`record(url:size:mimeType:)` only reports while the adapter is running.

## Custom Logging

Provide a logger by conforming to `MediaSizeLogger`:

```swift
import MediaSizeWatchdog

final class AppMediaLogger: MediaSizeLogger {
    func log(_ message: String) {
        // Forward to OSLog, your analytics console, or a debug overlay.
        print(message)
    }
}

MediaSizeWatchdog.shared.start(
    logger: AppMediaLogger(),
    adapters: [
        URLSessionMediaAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
```

If no logger is provided, `DefaultMediaSizeLogger` prints messages with `print`.

## Reading Issues

Issues are kept in memory:

```swift
let issues = MediaSizeWatchdog.shared.issues
```

Each `MediaSizeIssue` includes:

- `url`
- `mediaType`
- `size`
- `threshold`
- `mimeType`
- `source`
- `date`

The default `MediaSizeIssueStore` deduplicates reports by URL. To clear stored issues:

```swift
MediaSizeWatchdog.shared.issueStore.removeAll()
```

## Stopping

```swift
MediaSizeWatchdog.shared.stop()
```

Calling `start` again replaces the current configuration and adapters.

## Media Detection

Detection uses the MIME type first and then falls back to the URL path extension.

Supported image extensions include `jpg`, `jpeg`, `png`, `gif`, `webp`, `heic`, `heif`, `bmp`, `tiff`, `tif`, `avif`, and `svg`.

Supported video extensions include `mp4`, `mov`, `m4v`, `webm`, `avi`, `mkv`, `mpeg`, `mpg`, `3gp`, and `3gpp`.

## Optional Library Adapters

The package intentionally does not depend on Alamofire, SDWebImage, Kingfisher, Nuke, or other networking/image libraries. If your app uses one of those libraries, add the matching adapter inside your app target, where both `MediaSizeWatchdog` and the third-party library are available.

### Alamofire

Create `AlamofireMediaAdapter.swift` in your app target:

```swift
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

    func request<Value>(
        _ request: DataRequest,
        didParseResponse response: DataResponse<Value, AFError>
    ) where Value: Sendable {
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
```

Attach it to your `Session` as an `EventMonitor`:

```swift
import Alamofire
import MediaSizeWatchdog

let alamofireAdapter = AlamofireMediaAdapter(reporter: MediaSizeWatchdog.shared)

MediaSizeWatchdog.shared.start(
    adapters: [alamofireAdapter]
)

let session = Session(eventMonitors: [alamofireAdapter])
```

### SDWebImage

Create `SDWebImageMediaAdapter.swift` in your app target:

```swift
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
```

Start it with the watchdog:

```swift
import MediaSizeWatchdog
import SDWebImage

MediaSizeWatchdog.shared.start(
    adapters: [
        SDWebImageMediaAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
```

### Kingfisher

Create `KingfisherMediaAdapter.swift` in your app target:

```swift
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
```

Start it with the watchdog:

```swift
import Kingfisher
import MediaSizeWatchdog

MediaSizeWatchdog.shared.start(
    adapters: [
        KingfisherMediaAdapter(reporter: MediaSizeWatchdog.shared)
    ]
)
```

### Other Libraries

For Nuke or any custom networking/image pipeline, create an app-side adapter that conforms to `MediaSizeAdapter` and calls:

```swift
reporter.report(
    url: url,
    size: size,
    mimeType: mimeType,
    source: .custom
)
```

Use the existing `CustomNetworkAdapter` as the simplest reference implementation.

## Verification

Run the test suite with:

```bash
swift test
```
