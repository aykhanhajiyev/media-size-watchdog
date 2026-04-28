import Foundation

public final class URLSessionMediaAdapter: MediaSizeAdapter {
    private weak var reporter: MediaSizeReporter?

    public init(reporter: MediaSizeReporter) {
        self.reporter = reporter
    }

    public func start() {
        URLSessionMediaURLProtocol.setReporter(reporter)
        URLProtocol.registerClass(URLSessionMediaURLProtocol.self)
    }

    public func stop() {
        URLProtocol.unregisterClass(URLSessionMediaURLProtocol.self)
        URLSessionMediaURLProtocol.setReporter(nil)
    }

    public static func instrument(_ configuration: URLSessionConfiguration) -> URLSessionConfiguration {
        let existingProtocolClasses = configuration.protocolClasses ?? []
        if !existingProtocolClasses.contains(where: { $0 == URLSessionMediaURLProtocol.self }) {
            configuration.protocolClasses = [URLSessionMediaURLProtocol.self] + existingProtocolClasses
        }
        return configuration
    }
}

final class URLSessionMediaURLProtocol: URLProtocol, URLSessionDataDelegate {
    private static let handledKey = "MediaSizeWatchdog.URLProtocolHandled"
    private static let reporterLock = NSLock()
    private static weak var reporter: MediaSizeReporter?

    private var dataTask: URLSessionDataTask?
    private var responseURL: URL?
    private var mimeType: String?
    private var receivedSize: Int64 = 0

    static func setReporter(_ reporter: MediaSizeReporter?) {
        reporterLock.withLock {
            self.reporter = reporter
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else {
            return false
        }

        guard let scheme = request.url?.scheme?.lowercased() else {
            return false
        }

        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = []

        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )

        dataTask = session.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        responseURL = response.url
        mimeType = response.mimeType
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedSize += Int64(data.count)
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            session.invalidateAndCancel()
        }

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        client?.urlProtocolDidFinishLoading(self)

        guard let url = responseURL ?? task.currentRequest?.url else {
            return
        }

        let reporter = Self.reporterLock.withLock { Self.reporter }
        reporter?.report(
            url: url,
            size: receivedSize,
            mimeType: mimeType,
            source: .urlSession
        )
    }
}
