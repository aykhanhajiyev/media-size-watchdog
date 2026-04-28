import Alamofire
import Foundation
import MediaSizeWatchdog

public final class AlamofireMediaAdapter: EventMonitor, MediaSizeAdapter, @unchecked Sendable {
    public let queue: DispatchQueue

    private weak var reporter: MediaSizeReporter?
    private let lock = NSLock()
    private var isRunning = false

    public init(
        reporter: MediaSizeReporter,
        queue: DispatchQueue = DispatchQueue(label: "MediaSizeWatchdog.AlamofireAdapter")
    ) {
        self.reporter = reporter
        self.queue = queue
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

    public func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        report(response: response)
    }

    public func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) where Value: Sendable {
        report(response: response)
    }

    private func report<Value>(response: DataResponse<Value, AFError>) {
        #if DEBUG
        guard lock.withLock({ isRunning }) else { return }
        guard let url = response.request?.url, let data = response.data else { return }

        reporter?.report(
            url: url,
            size: Int64(data.count),
            mimeType: response.response?.mimeType,
            source: .alamofire
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
