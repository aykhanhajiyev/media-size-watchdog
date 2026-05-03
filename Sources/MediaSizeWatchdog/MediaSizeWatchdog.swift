import Foundation

public final class MediaSizeWatchdog {
    public static let shared = MediaSizeWatchdog()

    public private(set) var issueStore: MediaSizeIssueStore

    private let queue = DispatchQueue(label: "MediaSizeWatchdog.Core")
    private var config = MediaSizeWatchdogConfig()
    private var adapters: [MediaSizeAdapter] = []
    private var isRunning = false
    private var logger: any MediaSizeLogger

    public convenience init() {
        self.init(issueStore: MediaSizeIssueStore())
    }

    public init(
        issueStore: MediaSizeIssueStore = MediaSizeIssueStore(),
        logger: any MediaSizeLogger = DefaultMediaSizeLogger()
    ) {
        self.issueStore = issueStore
        self.logger = logger
    }

    public func start(
        config: MediaSizeWatchdogConfig = MediaSizeWatchdogConfig(),
        logger: (any MediaSizeLogger)? = nil,
        adapters: [MediaSizeAdapter]
    ) {
        let adaptersToStart = queue.sync {
            if isRunning {
                self.adapters.forEach { $0.stop() }
            }

            self.config = config
            if let logger {
                self.logger = logger
            }
            self.adapters = adapters
            self.isRunning = true
            return adapters
        }

        adaptersToStart.forEach { $0.start() }
    }

    public func stop() {
        let adaptersToStop = queue.sync {
            let currentAdapters = adapters
            adapters = []
            isRunning = false
            return currentAdapters
        }

        adaptersToStop.forEach { $0.stop() }
    }

    public var issues: [MediaSizeIssue] {
        issueStore.issues
    }
}

extension MediaSizeWatchdog: MediaSizeReporter {
    public func report(
        url: URL,
        size: Int64,
        mimeType: String?,
        source: MediaSource
    ) {
        let currentConfig = queue.sync { config }
        let mediaType = MediaTypeDetector.detect(url: url, mimeType: mimeType)

        guard let threshold = threshold(for: mediaType, config: currentConfig), size > threshold else {
            return
        }

        let issue = MediaSizeIssue(
            url: url,
            mediaType: mediaType,
            size: size,
            threshold: threshold,
            mimeType: mimeType,
            source: source
        )

        issueStore.append(issue)
        log(issue)
    }

    private func threshold(for mediaType: MediaType, config: MediaSizeWatchdogConfig) -> Int64? {
        switch mediaType {
        case .image:
            return config.imageThreshold
        case .video:
            return config.videoThreshold
        case .unknown:
            return nil
        }
    }

    private func log(_ issue: MediaSizeIssue) {
        let currentLogger = queue.sync { logger }
        currentLogger.log(
            """
            [MediaSizeWatchdog] Oversized \(issue.mediaType.rawValue) from \(issue.source.rawValue): \(issue.url.absoluteString) \
            size=\(MediaSizeFormatter.string(from: issue.size)) threshold=\(MediaSizeFormatter.string(from: issue.threshold)) \
            mimeType=\(issue.mimeType ?? "unknown")
            """
        )
    }
}
