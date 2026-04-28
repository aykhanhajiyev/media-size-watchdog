import Foundation

public final class MediaSizeIssueStore {
    private let queue = DispatchQueue(label: "MediaSizeWatchdog.IssueStore", attributes: .concurrent)
    private var storedIssues: [MediaSizeIssue] = []
    private var knownURLs: Set<URL> = []
    private let deduplicatesByURL: Bool

    public init(deduplicatesByURL: Bool = true) {
        self.deduplicatesByURL = deduplicatesByURL
    }

    public var issues: [MediaSizeIssue] {
        queue.sync { storedIssues }
    }

    public func append(_ issue: MediaSizeIssue) {
        queue.sync(flags: .barrier) {
            if deduplicatesByURL {
                guard !knownURLs.contains(issue.url) else { return }
                knownURLs.insert(issue.url)
            }

            storedIssues.append(issue)
        }
    }

    public func removeAll() {
        queue.sync(flags: .barrier) {
            storedIssues.removeAll()
            knownURLs.removeAll()
        }
    }
}
